#!/bin/bash
# Script de Post-Installation Debian 12/13 et Déploiement d'Oxidized (Sauvegarde Réseau)
# Pile : Docker/Ruby, Git, UFW + Réseau Statique (AVEC PATCH DNS)

# 🛑 SÉCURITÉ 2 : Arrête le script immédiatement à la moindre erreur
set -e

# ---------------------------------------------------------
# ✨ AUTO-ÉLÉVATION DES PRIVILÈGES (SUDO)
# ---------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
  echo "⚠️  Ce script doit modifier des fichiers système."
  echo "🔄 Demande des droits d'administration en cours..."
  exec sudo bash "$0" "$@"
  exit $?
fi

echo "=========================================================="
echo "   🚀 DÉPLOIEMENT AUTOMATISÉ : DEBIAN 12/13 + OXIDIZED"
echo "=========================================================="

# ---------------------------------------------------------
# ÉTAPE 1 : QUESTIONS INTERACTIVES RÉSEAU
# ---------------------------------------------------------
echo -e "\n--- 🛠️  CONFIGURATION DU SYSTÈME ---"
read -p "👉 Nom de la machine (Hostname) [ex: srv-oxidized] : " HOSTNAME_CHOICE
HOSTNAME_CHOICE=${HOSTNAME_CHOICE:-srv-oxidized}

DETECTED_IFACE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP '(?<=dev )[^ ]+')
read -p "👉 Interface réseau détectée : '$DETECTED_IFACE'. Entrée pour valider ou saisissez (ex: eth0) : " IFACE_CHOICE
IFACE_CHOICE=${IFACE_CHOICE:-$DETECTED_IFACE}

read -p "👉 Adresse IP statique (ex: 192.168.1.90) : " IP_ADDRESS
read -p "👉 Masque de sous-réseau (ex: 255.255.255.0) : " NETMASK
read -p "👉 Passerelle par défaut (Gateway, ex: 192.168.1.254) : " GATEWAY
read -p "👉 Serveur DNS (ex: 8.8.8.8) : " DNS_SERVER

# ---------------------------------------------------------
# ÉTAPE 2 : QUESTIONS INTERACTIVES OXIDIZED
# ---------------------------------------------------------
echo -e "\n--- ⚙️  CONFIGURATION OXIDIZED ---"

echo "👉 Méthode d'installation :"
echo "   1) Docker (Recommandé, propre et facile à mettre à jour)"
echo "   2) Natif / Ruby (Installation directe sur l'OS, compilation requise)"
read -p "   Votre choix (1 ou 2) : " INSTALL_METHOD

read -p "👉 Port de l'interface Web GUI [Défaut: 8888] : " WEB_PORT
WEB_PORT=${WEB_PORT:-8888}

echo "👉 Source de vos équipements (Switchs, Routeurs) :"
echo "   1) Fichier texte local (router.db)"
echo "   2) API HTTP distante (ex: Zabbix, LibreNMS)"
read -p "   Votre choix (1 ou 2) : " SOURCE_CHOICE

echo -e "\n✅ L'installation 100% automatisée commence...\n"
sleep 2

# ---------------------------------------------------------
# 🛡️ SÉCURITÉ & RÉSEAU DE BASE (AVEC PATCH DNS)
# ---------------------------------------------------------
echo "🔍 Vérification de la connexion Internet et du DNS..."
if ! ping -c 2 deb.debian.org &> /dev/null; then
    echo "❌ ERREUR CRITIQUE : Pas d'accès Internet."
    exit 1
fi

hostnamectl set-hostname "$HOSTNAME_CHOICE"
sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME_CHOICE/g" /etc/hosts
timedatectl set-timezone Europe/Paris

echo "📦 Mise à jour du système et installation des outils de base..."
apt update && apt upgrade -y
# 🛠️ Présence de gnupg et ca-certificates pour l'installation Docker
apt install -y ufw resolvconf curl wget jq git gnupg ca-certificates

echo "🔧 Application du patch DNS pour éviter la coupure..."
echo "nameserver $DNS_SERVER" > /etc/resolv.conf
if [ -d "/etc/resolvconf/resolv.conf.d" ]; then
    echo "nameserver $DNS_SERVER" > /etc/resolvconf/resolv.conf.d/head
    resolvconf -u || true
fi
if ! ping -c 2 deb.debian.org &> /dev/null; then
    echo "❌ ERREUR : Résolution DNS perdue après patch."
    exit 1
fi

echo "🛡️  Configuration du pare-feu (UFW)..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp          # SSH
ufw allow $WEB_PORT/tcp   # Port Web GUI Oxidized choisi par l'utilisateur
ufw --force enable

echo "🌐 Préparation de la configuration réseau statique..."
cp /etc/network/interfaces /etc/network/interfaces.backup
cat <<EOF > /etc/network/interfaces
source /etc/network/interfaces.d/*
auto lo
iface lo inet loopback
allow-hotplug $IFACE_CHOICE
iface $IFACE_CHOICE inet static
    address $IP_ADDRESS
    netmask $NETMASK
    gateway $GATEWAY
    dns-nameservers $DNS_SERVER
EOF

# ---------------------------------------------------------
# ÉTAPE 3 : INSTALLATION D'OXIDIZED (DOCKER OU NATIF)
# ---------------------------------------------------------
mkdir -p /etc/oxidized
OXI_CONF="/etc/oxidized/config"
OXI_GIT="/etc/oxidized/network_configs.git"

# 🛠️ Définition des chemins internes selon la méthode (Résout le crash du dossier introuvable)
if [ "$INSTALL_METHOD" == "1" ]; then
    INT_DIR="/home/oxidized/.config/oxidized"
else
    INT_DIR="/etc/oxidized"
fi

# --- MÉTHODE 1 : DOCKER ---
if [ "$INSTALL_METHOD" == "1" ]; then
    echo "🐳 Installation du moteur Docker..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    echo "📝 Création du docker-compose.yml..."
    cat <<EOF > /etc/oxidized/docker-compose.yml
services:
  oxidized:
    image: oxidized/oxidized:latest
    container_name: oxidized
    restart: unless-stopped
    ports:
      - "$WEB_PORT:$WEB_PORT"
    volumes:
      - /etc/oxidized:/home/oxidized/.config/oxidized
EOF

# --- MÉTHODE 2 : NATIF (RUBY) ---
else
    echo "💎 Installation des dépendances Ruby Natives (Compilation)..."
    echo "⏳ Cette étape peut prendre quelques minutes..."
    apt install -y ruby ruby-dev libsqlite3-dev libssl-dev pkg-config cmake libssh2-1-dev libicu-dev zlib1g-dev gcc g++ make
    gem install oxidized oxidized-script oxidized-web --no-document
    
    echo "⚙️ Création du service systemd..."
    cat <<EOF > /etc/systemd/system/oxidized.service
[Unit]
Description=Oxidized - Network Device Configuration Backup
After=network-online.target

[Service]
ExecStart=/usr/local/bin/oxidized
Environment="OXIDIZED_HOME=/etc/oxidized"
User=root
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable oxidized
fi

# ---------------------------------------------------------
# ÉTAPE 4 : GÉNÉRATION DE LA CONFIGURATION YAML & GIT
# ---------------------------------------------------------
echo "📁 Initialisation du dépôt Git local..."
git init --bare $OXI_GIT

echo "📝 Création du fichier de configuration Oxidized dynamique..."
cat <<EOF > $OXI_CONF
---
resolve_dns: true
interval: 3600
use_syslog: false
debug: false
threads: 30
timeout: 20
retries: 3
prompt: !ruby/regexp /^([\w.@-]+[#>]\s?)$/
rest: 0.0.0.0:$WEB_PORT
vars: {}
groups: {}
models: {}
pid: "$INT_DIR/pid"
input:
  default: ssh, telnet
  debug: false
  ssh:
    secure: false
output:
  default: git
  git:
    user: Oxidized
    email: oxidized@localhost
    repo: "$INT_DIR/network_configs.git"
EOF

# Injection de la source (Fichier ou API)
if [ "$SOURCE_CHOICE" == "1" ]; then
    touch /etc/oxidized/router.db
    cat <<EOF >> $OXI_CONF
source:
  default: csv
  csv:
    file: "$INT_DIR/router.db"
    delimiter: !ruby/regexp /:/
    map:
      name: 0
      model: 1
      username: 2
      password: 3
EOF
    echo "Exemple d'équipement créé dans router.db"
    # 🛠️ CORRECTION : Utilisation de 127.0.0.1 au lieu d'un nom DNS bidon pour éviter le crash
    echo "127.0.0.1:cisco:admin:mon_mot_de_passe" > /etc/oxidized/router.db
else
    cat <<EOF >> $OXI_CONF
source:
  default: http
  http:
    url: "http://<IP_VOTRE_API>/api/devices"
    map:
      name: hostname
      model: os
EOF
fi

# Lancement final
if [ "$INSTALL_METHOD" == "1" ]; then
    # 🛠️ Attribution des droits pour l'utilisateur Docker (uid 30000)
    chown -R 30000:30000 /etc/oxidized
    echo "🚀 Démarrage du conteneur Oxidized..."
    cd /etc/oxidized && docker compose up -d
else
    echo "🚀 Démarrage du service natif Oxidized..."
    systemctl start oxidized
fi

echo "=========================================================="
echo " 🎉 INSTALLATION D'OXIDIZED TERMINÉE !"
echo "=========================================================="
echo "👉 URL de l'interface Web : http://$IP_ADDRESS:$WEB_PORT"
echo "👉 Les fichiers de configuration se trouvent dans : /etc/oxidized/"
if [ "$SOURCE_CHOICE" == "1" ]; then
    echo "⚠️ N'oubliez pas d'ajouter vos équipements dans le fichier /etc/oxidized/router.db"
else
    echo "⚠️ N'oubliez pas de configurer l'URL de votre API dans /etc/oxidized/config"
fi
echo ""
read -p "Voulez-vous redémarrer le serveur maintenant pour appliquer l'IP statique ? (o/n) " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" == "o" || "$REBOOT_CHOICE" == "O" ]]; then
    sudo reboot
fi
