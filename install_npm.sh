#!/bin/bash
# Script de Post-Installation Debian 12/13 et Déploiement de Nginx Proxy Manager (NPM)
# Pile : Docker, NPM (SQLite ou MariaDB) + UFW + Réseau Statique (AVEC PATCH DNS)

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
echo "   🚀 DÉPLOIEMENT AUTOMATISÉ : DEBIAN 12/13 + NGINX PROXY MANAGER"
echo "=========================================================="

# ---------------------------------------------------------
# ÉTAPE 1 : QUESTIONS INTERACTIVES RÉSEAU
# ---------------------------------------------------------
echo -e "\n--- 🛠️  CONFIGURATION DU SYSTÈME ---"
read -p "👉 Nom de la machine (Hostname) [ex: srv-proxy] : " HOSTNAME_CHOICE
HOSTNAME_CHOICE=${HOSTNAME_CHOICE:-srv-proxy}

DETECTED_IFACE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP '(?<=dev )[^ ]+')
read -p "👉 Interface réseau détectée : '$DETECTED_IFACE'. Entrée pour valider ou saisissez (ex: eth0) : " IFACE_CHOICE
IFACE_CHOICE=${IFACE_CHOICE:-$DETECTED_IFACE}

read -p "👉 Adresse IP statique (ex: 192.168.1.100) : " IP_ADDRESS
read -p "👉 Masque de sous-réseau (ex: 255.255.255.0) : " NETMASK
read -p "👉 Passerelle par défaut (Gateway, ex: 192.168.1.254) : " GATEWAY
read -p "👉 Serveur DNS (ex: 8.8.8.8) : " DNS_SERVER

# ---------------------------------------------------------
# ÉTAPE 2 : QUESTIONS INTERACTIVES NPM
# ---------------------------------------------------------
echo -e "\n--- ⚙️  CONFIGURATION DE NGINX PROXY MANAGER ---"

echo "👉 Choix du moteur de base de données :"
echo "   1) SQLite (Recommandé, ultra-léger, 1 seul conteneur, backups faciles)"
echo "   2) MariaDB (Pour les très gros déploiements, 2 conteneurs)"
read -p "   Votre choix [Défaut: 1] : " DB_CHOICE
DB_CHOICE=${DB_CHOICE:-1}

read -p "👉 Port de l'interface d'administration Web [Défaut: 81] : " ADMIN_PORT
ADMIN_PORT=${ADMIN_PORT:-81}

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
apt install -y ufw resolvconf curl wget jq ca-certificates gnupg

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
ufw allow 80/tcp          # HTTP (Obligatoire pour NPM & Let's Encrypt)
ufw allow 443/tcp         # HTTPS (Obligatoire pour NPM)
ufw allow $ADMIN_PORT/tcp # Port d'administration dynamique
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
# ÉTAPE 3 : INSTALLATION DE DOCKER (OFFICIEL)
# ---------------------------------------------------------
echo "🐳 Installation du moteur Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $VERSION_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# ---------------------------------------------------------
# ÉTAPE 4 : DÉPLOIEMENT DE NGINX PROXY MANAGER
# ---------------------------------------------------------
echo "📈 Préparation de l'environnement NPM..."
mkdir -p /opt/npm/data
mkdir -p /opt/npm/letsencrypt
cd /opt/npm

echo "📝 Génération du fichier docker-compose.yml..."

if [ "$DB_CHOICE" == "2" ]; then
    # Génération robuste de mot de passe pour MariaDB
    DB_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16 || true)
    if [ -z "$DB_PASS" ]; then DB_PASS="NpmSecurePass2026!"; fi
    
    cat <<EOF > docker-compose.yml
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: npm_app
    restart: unless-stopped
    ports:
      - '80:80'
      - '$ADMIN_PORT:81'
      - '443:443'
    environment:
      DB_MYSQL_HOST: "db"
      DB_MYSQL_PORT: 3306
      DB_MYSQL_USER: "npm_user"
      DB_MYSQL_PASSWORD: "${DB_PASS}"
      DB_MYSQL_NAME: "npm_db"
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    depends_on:
      - db

  db:
    image: 'mariadb:10.11'
    container_name: npm_db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: "${DB_PASS}_root"
      MYSQL_DATABASE: 'npm_db'
      MYSQL_USER: 'npm_user'
      MYSQL_PASSWORD: '${DB_PASS}'
    volumes:
      - ./mysql:/var/lib/mysql
EOF
    echo "🔑 Base de données MariaDB configurée avec un mot de passe aléatoire."
else
    # Configuration par défaut (SQLite)
    cat <<EOF > docker-compose.yml
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: npm_app
    restart: unless-stopped
    ports:
      - '80:80'
      - '$ADMIN_PORT:81'
      - '443:443'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
EOF
    echo "🪶 Base de données SQLite (Native) sélectionnée."
fi

echo "🚀 Démarrage des conteneurs..."
# Idempotence : on nettoie l'ancien réseau/conteneur si relance
docker compose down -v 2>/dev/null || true
docker compose up -d

echo "=========================================================="
echo " 🎉 INSTALLATION DE NGINX PROXY MANAGER TERMINÉE !"
echo "=========================================================="
echo "👉 URL d'administration : http://$IP_ADDRESS:$ADMIN_PORT"
echo "👉 Vos données SSL sont sécurisées dans : /opt/npm/"
echo ""
echo "⚠️ IDENTIFIANTS PAR DÉFAUT (À changer immédiatement) :"
echo "   Email    : admin@example.com"
echo "   Password : changeme"
echo ""
read -p "Voulez-vous redémarrer le serveur maintenant pour appliquer l'IP statique ? (o/n) " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" == "o" || "$REBOOT_CHOICE" == "O" ]]; then
    sudo reboot
fi
