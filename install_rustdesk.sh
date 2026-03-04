#!/bin/bash
# Script de Post-Installation Debian 12/13 et Déploiement RustDesk Server
# Pile : hbbs, hbbr + UFW + Réseau Statique (AVEC PATCH DNS)

# 🛑 SÉCURITÉ 2 : Arrête le script immédiatement à la moindre erreur
set -e

# ---------------------------------------------------------
# ✨ AUTO-ÉLÉVATION DES PRIVILÈGES (SUDO) CORRIGÉE
# ---------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
  echo "⚠️  Ce script doit modifier des fichiers système."
  echo "🔄 Demande des droits d'administration en cours..."
  exec sudo bash "$0" "$@"
  exit $?
fi

echo "=========================================================="
echo "   🚀 DÉPLOIEMENT AUTOMATISÉ : DEBIAN 12/13 + RUSTDESK"
echo "=========================================================="

# ---------------------------------------------------------
# ÉTAPE 1 : QUESTIONS INTERACTIVES (Réseau & Système)
# ---------------------------------------------------------
echo -e "\n--- 🛠️  CONFIGURATION DU SYSTÈME ---"

read -p "👉 Nom de la machine (Hostname) [ex: srv-rustdesk] : " HOSTNAME_CHOICE
HOSTNAME_CHOICE=${HOSTNAME_CHOICE:-srv-rustdesk}

DETECTED_IFACE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP '(?<=dev )[^ ]+')
read -p "👉 Interface réseau détectée : '$DETECTED_IFACE'. Entrée pour valider ou saisissez (ex: eth0) : " IFACE_CHOICE
IFACE_CHOICE=${IFACE_CHOICE:-$DETECTED_IFACE}

read -p "👉 Adresse IP statique (ex: 192.168.1.70) : " IP_ADDRESS
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
    echo "👉 Le script s'arrête ici pour éviter de corrompre l'installation."
    echo "👉 Vérifiez votre configuration réseau et relancez le script."
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

echo "📦 Installation des prérequis systèmes..."
apt update && apt install -y ufw resolvconf unzip wget curl jq

# ==============================================================================
# 🛡️ PATCH ANTI-COUPURE DNS
# ==============================================================================
echo "🔧 Application du patch DNS pour éviter la coupure..."
echo "nameserver $DNS_SERVER" > /etc/resolv.conf
if [ -d "/etc/resolvconf/resolv.conf.d" ]; then
    echo "nameserver $DNS_SERVER" > /etc/resolvconf/resolv.conf.d/head
    resolvconf -u || true
fi
# On vérifie immédiatement si le patch a fonctionné avant de contacter GitHub
if ! ping -c 2 api.github.com &> /dev/null; then
    echo "❌ ERREUR : Le serveur n'arrive pas à joindre GitHub. Vérifiez votre DNS."
    exit 1
fi
echo "✅ Connexion DNS maintenue avec succès !"
# ==============================================================================

echo "🛡️  Installation et configuration du pare-feu (UFW)..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp        # SSH
ufw allow 21115:21119/tcp # RustDesk TCP
ufw allow 21116/udp       # RustDesk UDP
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
# ÉTAPE 3 : INSTALLATION DE RUSTDESK (hbbs & hbbr)
# ---------------------------------------------------------
echo "📥 Téléchargement de RustDesk Server..."
LATEST_URL=$(curl -s https://api.github.com/repos/rustdesk/rustdesk-server/releases/latest | grep browser_download_url | grep 'linux-amd64.zip' | cut -d '"' -f 4)
wget -q -O /tmp/rustdesk.zip "$LATEST_URL"

echo "📂 Décompression et mise en place..."
mkdir -p /opt/rustdesk /tmp/rustdesk_unzip
unzip -q /tmp/rustdesk.zip -d /tmp/rustdesk_unzip
find /tmp/rustdesk_unzip -type f \( -name "hbbs" -o -name "hbbr" \) -exec mv {} /opt/rustdesk/ \;
chmod +x /opt/rustdesk/hbbs /opt/rustdesk/hbbr
rm -rf /tmp/rustdesk.zip /tmp/rustdesk_unzip

echo "⚙️  Création des services Systemd..."

cat <<EOF > /etc/systemd/system/hbbs.service
[Unit]
Description=RustDesk ID Server (hbbs)
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/rustdesk
ExecStart=/opt/rustdesk/hbbs -r $IP_ADDRESS
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /etc/systemd/system/hbbr.service
[Unit]
Description=RustDesk Relay Server (hbbr)
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/rustdesk
ExecStart=/opt/rustdesk/hbbr
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "🔄 Démarrage des services et génération des clés de chiffrement..."
systemctl daemon-reload
systemctl enable hbbs hbbr
systemctl start hbbs hbbr

sleep 5

echo "=========================================================="
echo " 🎉 INSTALLATION DE RUSTDESK TERMINÉE !"
echo "=========================================================="
echo "👉 Serveur RustDesk (IP) : $IP_ADDRESS"

if [ -f "/opt/rustdesk/id_ed25519.pub" ]; then
    PUB_KEY=$(cat /opt/rustdesk/id_ed25519.pub)
    echo -e "👉 \033[1;32mCLÉ PUBLIQUE (Key) : $PUB_KEY\033[0m"
else
    echo "⚠️ La clé n'a pas pu être lue immédiatement. Vous pourrez la retrouver"
    echo "plus tard en tapant : cat /opt/rustdesk/id_ed25519.pub"
fi
echo "=========================================================="
echo ""
read -p "Voulez-vous redémarrer le serveur maintenant pour appliquer l'IP statique ? (o/n) " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" == "o" || "$REBOOT_CHOICE" == "O" ]]; then
    echo "Redémarrage en cours... Connectez-vous ensuite sur la nouvelle IP."
    sudo reboot
else
    echo "N'oubliez pas de redémarrer le serveur plus tard."
fi
