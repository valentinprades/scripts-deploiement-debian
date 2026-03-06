#!/bin/bash
# Script de Post-Installation Debian 12/13 et Déploiement d'Uptime Kuma (Monitoring Web)
# Pile : Docker, Node.js/SQLite interne + UFW + Réseau Statique (AVEC PATCH DNS)

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
echo "   🚀 DÉPLOIEMENT AUTOMATISÉ : DEBIAN 12/13 + UPTIME KUMA"
echo "=========================================================="

# ---------------------------------------------------------
# ÉTAPE 1 : QUESTIONS INTERACTIVES RÉSEAU
# ---------------------------------------------------------
echo -e "\n--- 🛠️  CONFIGURATION DU SYSTÈME ---"
read -p "👉 Nom de la machine (Hostname) [ex: srv-kuma] : " HOSTNAME_CHOICE
HOSTNAME_CHOICE=${HOSTNAME_CHOICE:-srv-kuma}

DETECTED_IFACE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP '(?<=dev )[^ ]+')
read -p "👉 Interface réseau détectée : '$DETECTED_IFACE'. Entrée pour valider ou saisissez (ex: eth0) : " IFACE_CHOICE
IFACE_CHOICE=${IFACE_CHOICE:-$DETECTED_IFACE}

read -p "👉 Adresse IP statique (ex: 192.168.1.110) : " IP_ADDRESS
read -p "👉 Masque de sous-réseau (ex: 255.255.255.0) : " NETMASK
read -p "👉 Passerelle par défaut (Gateway, ex: 192.168.1.254) : " GATEWAY
read -p "👉 Serveur DNS (ex: 8.8.8.8) : " DNS_SERVER

# ---------------------------------------------------------
# ÉTAPE 2 : QUESTIONS INTERACTIVES UPTIME KUMA
# ---------------------------------------------------------
echo -e "\n--- ⚙️  CONFIGURATION D'UPTIME KUMA ---"

read -p "👉 Port de l'interface Web [Défaut: 3001] : " WEB_PORT
WEB_PORT=${WEB_PORT:-3001}

echo "👉 Voulez-vous autoriser Uptime Kuma à lire le statut de vos conteneurs Docker locaux ?"
echo "   (Cela permet de créer des alertes si un conteneur s'arrête sur cette machine)"
read -p "   Autoriser l'accès au socket Docker ? (o/n) : " DOCKER_SOCKET_CHOICE

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
ufw allow $WEB_PORT/tcp   # Port Web dynamique
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
# ÉTAPE 4 : DÉPLOIEMENT D'UPTIME KUMA
# ---------------------------------------------------------
echo "📈 Préparation de l'environnement Uptime Kuma..."
mkdir -p /opt/uptime-kuma/data
cd /opt/uptime-kuma

echo "📝 Génération du fichier docker-compose.yml..."
cat <<EOF > docker-compose.yml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "$WEB_PORT:3001"
    volumes:
      - ./data:/app/data
EOF

# Injection conditionnelle du socket Docker
if [[ "$DOCKER_SOCKET_CHOICE" == "o" || "$DOCKER_SOCKET_CHOICE" == "O" || "$DOCKER_SOCKET_CHOICE" == "y" || "$DOCKER_SOCKET_CHOICE" == "Y" ]]; then
    echo "      - /var/run/docker.sock:/var/run/docker.sock:ro" >> docker-compose.yml
    echo "🔒 Accès au socket Docker activé pour la supervision locale."
fi

echo "🚀 Démarrage du conteneur..."
# Idempotence : on nettoie les anciens conteneurs sans toucher aux données locales
docker compose down 2>/dev/null || true
docker compose up -d

echo "=========================================================="
echo " 🎉 INSTALLATION D'UPTIME KUMA TERMINÉE !"
echo "=========================================================="
echo "👉 URL de l'interface : http://$IP_ADDRESS:$WEB_PORT"
echo "👉 Vos données sont sauvegardées localement dans : /opt/uptime-kuma/data/"
echo ""
echo "⚠️ Lors de votre première connexion, il vous sera demandé de créer"
echo "   le compte administrateur principal."
echo ""
read -p "Voulez-vous redémarrer le serveur maintenant pour appliquer l'IP statique ? (o/n) " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" == "o" || "$REBOOT_CHOICE" == "O" ]]; then
    sudo reboot
fi
