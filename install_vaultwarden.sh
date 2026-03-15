#!/bin/bash
# Script de Post-Installation Debian 12/13 et Déploiement de Vaultwarden (Gestionnaire de Mots de Passe)
# Pile : Docker, SQLite native + UFW + Réseau Statique (AVEC PATCH DNS)

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
echo "   🚀 DÉPLOIEMENT AUTOMATISÉ : DEBIAN 12/13 + VAULTWARDEN"
echo "=========================================================="

# ---------------------------------------------------------
# ÉTAPE 1 : QUESTIONS INTERACTIVES RÉSEAU
# ---------------------------------------------------------
echo -e "\n--- 🛠️  CONFIGURATION DU SYSTÈME ---"
read -p "👉 Nom de la machine (Hostname) [ex: srv-vault] : " HOSTNAME_CHOICE
HOSTNAME_CHOICE=${HOSTNAME_CHOICE:-srv-vault}

DETECTED_IFACE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP '(?<=dev )[^ ]+')
read -p "👉 Interface réseau détectée : '$DETECTED_IFACE'. Entrée pour valider ou saisissez (ex: eth0) : " IFACE_CHOICE
IFACE_CHOICE=${IFACE_CHOICE:-$DETECTED_IFACE}

read -p "👉 Adresse IP statique (ex: 192.168.1.120) : " IP_ADDRESS
read -p "👉 Masque de sous-réseau (ex: 255.255.255.0) : " NETMASK
read -p "👉 Passerelle par défaut (Gateway, ex: 192.168.1.254) : " GATEWAY
read -p "👉 Serveur DNS (ex: 8.8.8.8) : " DNS_SERVER

# ---------------------------------------------------------
# ÉTAPE 2 : QUESTIONS INTERACTIVES VAULTWARDEN
# ---------------------------------------------------------
echo -e "\n--- ⚙️  CONFIGURATION DU COFFRE-FORT VAULTWARDEN ---"

read -p "👉 Port d'écoute de l'application [Défaut: 8000] : " VW_PORT
VW_PORT=${VW_PORT:-8000}

echo "👉 Le panneau d'administration nécessite un 'Admin Token' ultra-sécurisé."
echo "   1) Générer un Token aléatoire de 64 caractères (Recommandé)"
echo "   2) Saisir mon propre mot de passe administrateur"
read -p "   Votre choix [Défaut: 1] : " TOKEN_CHOICE
TOKEN_CHOICE=${TOKEN_CHOICE:-1}

if [ "$TOKEN_CHOICE" == "2" ]; then
    read -s -p "   🔑 Saisissez votre mot de passe (il ne s'affichera pas) : " VW_ADMIN_TOKEN
    echo ""
else
    # Génération d'un token aléatoire robuste
    VW_ADMIN_TOKEN=$(LC_ALL=C tr -dc 'A-Za-z0-9_!@#%^&*' </dev/urandom | head -c 64 || true)
    if [ -z "$VW_ADMIN_TOKEN" ]; then VW_ADMIN_TOKEN="FallbackAdminToken_ChangeMe_2026!"; fi
    echo "   ✅ Token généré aléatoirement. Il vous sera affiché à la fin de l'installation."
fi

echo -e "\n--- 🛑 INFORMATIONS DE SÉCURITÉ ---"
echo "⚠️  Création de compte (Signups) : Par mesure de sécurité, la création libre"
echo "   de compte sera DÉSACTIVÉE. Vous devrez vous connecter au panneau d'administration"
echo "   (/admin) avec votre Token pour inviter vos utilisateurs."
echo ""
echo "💡 RAPPEL HTTPS : Les extensions Bitwarden refuseront de fonctionner sans HTTPS."
echo "   N'oubliez pas d'utiliser Nginx Proxy Manager (NPM) pour créer un proxy inversé"
echo "   vers ce serveur (ex: https://vault.mondomaine.fr -> http://$IP_ADDRESS:$VW_PORT)"
echo "-----------------------------------"
read -p "Appuyez sur Entrée pour commencer l'installation..."

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

echo "🛡️  Configuration du pare-feu (UFW)..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp       # SSH
ufw allow $VW_PORT/tcp # Port Vaultwarden
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
# ÉTAPE 4 : DÉPLOIEMENT DE VAULTWARDEN
# ---------------------------------------------------------
echo "🔒 Préparation du coffre-fort Vaultwarden..."
mkdir -p /opt/vaultwarden/data
cd /opt/vaultwarden

echo "📝 Génération du fichier docker-compose.yml..."
cat <<EOF > docker-compose.yml
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    environment:
      - SIGNUPS_ALLOWED=false
      - ADMIN_TOKEN=${VW_ADMIN_TOKEN}
      - WEBSOCKET_ENABLED=true
    ports:
      - "$VW_PORT:80"
    volumes:
      - ./data:/data
EOF

echo "🚀 Démarrage du conteneur Vaultwarden..."
# Idempotence : on nettoie l'ancien réseau/conteneur si relance
docker compose down 2>/dev/null || true
docker compose up -d

echo "=========================================================="
echo " 🎉 INSTALLATION DE VAULTWARDEN TERMINÉE !"
echo "=========================================================="
echo "👉 Accès Local (Attention, refusé par les apps Bitwarden sans HTTPS) :"
echo "   http://$IP_ADDRESS:$VW_PORT"
echo ""
echo "👉 Panneau d'administration (Pour créer votre compte) :"
echo "   http://$IP_ADDRESS:$VW_PORT/admin"
echo ""
if [ "$TOKEN_CHOICE" == "1" ]; then
    echo "⚠️  VOTRE ADMIN TOKEN GÉNÉRÉ (Sauvegardez-le immédiatement !) :"
    echo "   $VW_ADMIN_TOKEN"
    echo ""
fi
echo "🛠️  PROCHAINE ÉTAPE OBLIGATOIRE :"
echo "   Allez sur votre Nginx Proxy Manager (NPM), créez un 'Proxy Host'"
echo "   pointant vers $IP_ADDRESS sur le port $VW_PORT, et activez un certificat SSL."
echo "=========================================================="
echo ""
read -p "Voulez-vous redémarrer le serveur maintenant pour appliquer l'IP statique ? (o/n) " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" == "o" || "$REBOOT_CHOICE" == "O" ]]; then
    sudo reboot
fi
