#!/bin/bash
# Script de Post-Installation Debian 12/13 et Déploiement d'Apache Guacamole (via Docker)
# Pile : Docker, PostgreSQL, Guacd, Tomcat (Guacamole Web) + UFW + Réseau Statique (AVEC PATCH DNS)

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
echo "   🚀 DÉPLOIEMENT AUTOMATISÉ : DEBIAN 12/13 + GUACAMOLE"
echo "=========================================================="

# ---------------------------------------------------------
# ÉTAPE 1 : QUESTIONS INTERACTIVES
# ---------------------------------------------------------
echo -e "\n--- 🛠️  CONFIGURATION DU SYSTÈME ---"

read -p "👉 Nom de la machine (Hostname) [ex: srv-guacamole] : " HOSTNAME_CHOICE
HOSTNAME_CHOICE=${HOSTNAME_CHOICE:-srv-guacamole}

DETECTED_IFACE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP '(?<=dev )[^ ]+')
read -p "👉 Interface réseau détectée : '$DETECTED_IFACE'. Entrée pour valider ou saisissez (ex: eth0) : " IFACE_CHOICE
IFACE_CHOICE=${IFACE_CHOICE:-$DETECTED_IFACE}

read -p "👉 Adresse IP statique (ex: 192.168.1.80) : " IP_ADDRESS
read -p "👉 Masque de sous-réseau (ex: 255.255.255.0) : " NETMASK
read -p "👉 Passerelle par défaut (Gateway, ex: 192.168.1.254) : " GATEWAY
read -p "👉 Serveur DNS (ex: 8.8.8.8) : " DNS_SERVER

echo -e "\n✅ L'installation 100% automatisée commence...\n"
sleep 2

# ---------------------------------------------------------
# 🛡️ SÉCURITÉ 1 : TEST DE CONNEXION AVANT DE COMMENCER
# ---------------------------------------------------------
echo "🔍 Vérification de la connexion Internet et du DNS..."
if ! ping -c 2 deb.debian.org &> /dev/null; then
    echo "❌ ERREUR CRITIQUE : Le serveur n'a pas accès à Internet ou le DNS ne répond pas."
    exit 1
fi
echo "✅ Connexion Internet OK !"

# ---------------------------------------------------------
# ÉTAPE 2 : CONFIGURATION SYSTÈME & RÉSEAU
# ---------------------------------------------------------
echo "⚙️  Application du nom d'hôte ($HOSTNAME_CHOICE)..."
hostnamectl set-hostname "$HOSTNAME_CHOICE"
sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME_CHOICE/g" /etc/hosts

echo "🕒 Configuration du fuseau horaire (Europe/Paris)..."
timedatectl set-timezone Europe/Paris

echo "📦 Mise à jour du système et installation des outils de base..."
apt update && apt upgrade -y
apt install -y ufw resolvconf curl wget jq ca-certificates gnupg

# ==============================================================================
# 🛡️ PATCH ANTI-COUPURE DNS
# ==============================================================================
echo "🔧 Application du patch DNS pour éviter la coupure..."
echo "nameserver $DNS_SERVER" > /etc/resolv.conf
if [ -d "/etc/resolvconf/resolv.conf.d" ]; then
    echo "nameserver $DNS_SERVER" > /etc/resolvconf/resolv.conf.d/head
    resolvconf -u || true
fi
if ! ping -c 2 deb.debian.org &> /dev/null; then
    echo "❌ ERREUR : Le serveur n'arrive plus à résoudre les noms. Vérifiez votre DNS."
    exit 1
fi
echo "✅ Connexion DNS maintenue avec succès !"
# ==============================================================================

echo "🛡️  Installation et configuration du pare-feu (UFW)..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   # SSH
ufw allow 8080/tcp # Port Web de Guacamole
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

. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $VERSION_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ---------------------------------------------------------
# ÉTAPE 4 : DÉPLOIEMENT DE GUACAMOLE
# ---------------------------------------------------------
echo "🥑 Préparation de l'environnement Guacamole..."
mkdir -p /opt/guacamole/init

# 🛠️ CORRECTION DÉFINITIVE : Génération robuste + Fallback de sécurité
DB_USER="guac_user"
DB_NAME="guacamole_db"
# L'option LC_ALL=C empêche la commande 'tr' de planter sur les caractères spéciaux de /dev/urandom
DB_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16 || true)

# Filet de sécurité anti-plantage : si le mot de passe est vide, on en force un.
if [ -z "$DB_PASS" ]; then
    DB_PASS="GuacamoleSecurePass2026!"
fi
echo "🔑 Mot de passe BDD interne configuré."

echo "⏳ Génération automatique du schéma de la base de données..."
docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgresql > /opt/guacamole/init/initdb.sql

echo "📝 Création du fichier Docker Compose..."
cat <<EOF > /opt/guacamole/docker-compose.yml
services:
  guacd:
    image: guacamole/guacd:latest
    container_name: guacd
    restart: unless-stopped

  postgres:
    image: postgres:15
    container_name: guacamole_db
    environment:
      # Postgres conserve l'ancienne syntaxe sans le QL
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: "${DB_PASS}"
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - ./init:/docker-entrypoint-initdb.d
      - guacamole_db_data:/var/lib/postgresql/data
    restart: unless-stopped

  guacamole:
    image: guacamole/guacamole:latest
    container_name: guacamole_web
    environment:
      GUACD_HOSTNAME: guacd
      # 🛠️ CORRECTION MISE À JOUR : Ajout du "QL" obligatoire depuis la nouvelle version
      POSTGRESQL_HOSTNAME: postgres
      POSTGRESQL_DATABASE: ${DB_NAME}
      POSTGRESQL_USER: ${DB_USER}
      POSTGRESQL_PASSWORD: "${DB_PASS}"
    ports:
      - "8080:8080"
    depends_on:
      - guacd
      - postgres
    restart: unless-stopped

volumes:
  guacamole_db_data:
EOF

echo "🚀 Lancement des conteneurs Guacamole..."
cd /opt/guacamole

# 🛠️ IDEMPOTENCE : Purge automatique de toute ancienne base de données corrompue avant de lancer
docker compose down -v 2>/dev/null || true

docker compose up -d

echo "⏳ Attente de l'initialisation de la base de données (15s)..."
sleep 15
docker restart guacamole_web

echo "=========================================================="
echo " 🎉 INSTALLATION DE GUACAMOLE TERMINÉE !"
echo "=========================================================="
echo "👉 URL d'accès : http://$IP_ADDRESS:8080/guacamole"
echo "👉 Identifiant par défaut : guacadmin"
echo "👉 Mot de passe par défaut : guacadmin"
echo "⚠️ Connectez-vous et modifiez ce mot de passe immédiatement !"
echo ""
read -p "Voulez-vous redémarrer le serveur maintenant pour appliquer l'IP statique ? (o/n) " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" == "o" || "$REBOOT_CHOICE" == "O" ]]; then
    echo "Redémarrage en cours... Connectez-vous ensuite sur la nouvelle IP."
    sudo reboot
else
    echo "N'oubliez pas de redémarrer le serveur plus tard."
fi
