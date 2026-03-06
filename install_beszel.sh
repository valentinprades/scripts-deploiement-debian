#!/bin/bash
# Script de Post-Installation Debian 12/13 et Déploiement de Beszel (Monitoring)
# Pile : Docker, Hub/Agent + UFW + Réseau Statique (AVEC PATCH DNS)

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
echo "   🚀 DÉPLOIEMENT AUTOMATISÉ : DEBIAN 12/13 + BESZEL"
echo "=========================================================="

# ---------------------------------------------------------
# ÉTAPE 1 : QUESTIONS INTERACTIVES RÉSEAU
# ---------------------------------------------------------
echo -e "\n--- 🛠️  CONFIGURATION DU SYSTÈME ---"
read -p "👉 Nom de la machine (Hostname) [ex: srv-beszel] : " HOSTNAME_CHOICE
HOSTNAME_CHOICE=${HOSTNAME_CHOICE:-srv-beszel}

DETECTED_IFACE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP '(?<=dev )[^ ]+')
read -p "👉 Interface réseau détectée : '$DETECTED_IFACE'. Entrée pour valider ou saisissez (ex: eth0) : " IFACE_CHOICE
IFACE_CHOICE=${IFACE_CHOICE:-$DETECTED_IFACE}

read -p "👉 Adresse IP statique (ex: 192.168.1.100) : " IP_ADDRESS
read -p "👉 Masque de sous-réseau (ex: 255.255.255.0) : " NETMASK
read -p "👉 Passerelle par défaut (Gateway, ex: 192.168.1.254) : " GATEWAY
read -p "👉 Serveur DNS (ex: 8.8.8.8) : " DNS_SERVER

# ---------------------------------------------------------
# ÉTAPE 2 : QUESTIONS INTERACTIVES BESZEL
# ---------------------------------------------------------
echo -e "\n--- ⚙️  CONFIGURATION DE BESZEL ---"
echo "Que souhaitez-vous installer sur cette machine ?"
echo "   1) Le Hub (Serveur central avec interface Web - À FAIRE EN PREMIER)"
echo "   2) L'Agent (Client à superviser - Nécessite la clé publique du Hub)"
read -p "Votre choix (1 ou 2) : " BESZEL_CHOICE

if [ "$BESZEL_CHOICE" == "1" ]; then
    read -p "👉 Port de l'interface Web du Hub [Défaut: 8090] : " WEB_PORT
    WEB_PORT=${WEB_PORT:-8090}
elif [ "$BESZEL_CHOICE" == "2" ]; then
    read -p "👉 Port d'écoute de l'Agent [Défaut: 45876] : " AGENT_PORT
    AGENT_PORT=${AGENT_PORT:-45876}
    read -p "👉 Clé Publique (générée par votre Hub) : " AGENT_KEY
    if [ -z "$AGENT_KEY" ]; then
        echo "❌ ERREUR : La clé publique est obligatoire pour l'Agent. Installez d'abord le Hub pour la générer."
        exit 1
    fi
else
    echo "❌ Choix invalide."
    exit 1
fi

echo -e "\n✅ L'installation automatisée commence...\n"
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
apt install -y ufw resolvconf curl wget jq gnupg ca-certificates

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
ufw allow 22/tcp # SSH

if [ "$BESZEL_CHOICE" == "1" ]; then
    ufw allow $WEB_PORT/tcp # Port Web du Hub
else
    ufw allow $AGENT_PORT/tcp # Port d'écoute de l'Agent
fi
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
# ÉTAPE 3 : INSTALLATION DE DOCKER
# ---------------------------------------------------------
echo "🐳 Installation du moteur Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Séparation de la longue ligne pour éviter la casse lors du copier-coller
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $VERSION_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# ---------------------------------------------------------
# ÉTAPE 4 : DÉPLOIEMENT DE BESZEL (HUB OU AGENT)
# ---------------------------------------------------------
mkdir -p /opt/beszel
cd /opt/beszel

if [ "$BESZEL_CHOICE" == "1" ]; then
    echo "📊 Configuration du Hub Beszel..."
    mkdir -p beszel_data
    cat <<EOF > docker-compose.yml
services:
  beszel:
    image: henrygd/beszel:latest
    container_name: beszel-hub
    restart: unless-stopped
    ports:
      - "$WEB_PORT:8090"
    volumes:
      - ./beszel_data:/beszel_data
EOF
    echo "🚀 Démarrage du Hub..."
    docker compose up -d

    echo "=========================================================="
    echo " 🎉 INSTALLATION DU HUB BESZEL TERMINÉE !"
    echo "=========================================================="
    echo "👉 URL de l'interface : http://$IP_ADDRESS:$WEB_PORT"
    echo "👉 Étape suivante : Créez votre compte administrateur sur l'interface,"
    echo "   cliquez sur 'Add System', copiez la clé publique fournie, et utilisez"
    echo "   ce même script sur vos autres serveurs pour installer l'Agent."

else
    echo "🕵️ Configuration de l'Agent Beszel..."
    cat <<EOF > docker-compose.yml
services:
  beszel-agent:
    image: henrygd/beszel-agent:latest
    container_name: beszel-agent
    restart: unless-stopped
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      PORT: $AGENT_PORT
      KEY: "$AGENT_KEY"
EOF
    echo "🚀 Démarrage de l'Agent..."
    docker compose up -d

    echo "=========================================================="
    echo " 🎉 INSTALLATION DE L'AGENT BESZEL TERMINÉE !"
    echo "=========================================================="
    echo "👉 L'agent écoute sur le port : $AGENT_PORT"
    echo "👉 Retournez sur l'interface de votre Hub pour vérifier que ce serveur"
    echo "   remonte bien ses métriques."
fi

echo ""
read -p "Voulez-vous redémarrer le serveur maintenant pour appliquer l'IP statique ? (o/n) " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" == "o" || "$REBOOT_CHOICE" == "O" ]]; then
    sudo reboot
fi
