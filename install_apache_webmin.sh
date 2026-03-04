#!/bin/bash
# Script de Post-Installation Debian 12/13 et Déploiement Apache2 + Webmin
# Pile : Apache2, Webmin + UFW + Réseau Statique (AVEC PATCH DNS)

set -e # 🛑 Arrêt en cas d'erreur

if [ "$EUID" -ne 0 ]; then
  echo "⚠️  Ce script doit modifier des fichiers système."
  echo "🔄 Demande des droits d'administration en cours..."
  exec sudo bash "$0" "$@"
  exit $?
fi

echo "=========================================================="
echo "   🚀 DÉPLOIEMENT AUTOMATISÉ : APACHE 2 + WEBMIN"
echo "=========================================================="

echo -e "\n--- 🛠️  CONFIGURATION DU SYSTÈME ---"
read -p "👉 Nom de la machine (Hostname) [ex: srv-web] : " HOSTNAME_CHOICE
HOSTNAME_CHOICE=${HOSTNAME_CHOICE:-srv-web}

DETECTED_IFACE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP '(?<=dev )[^ ]+')
read -p "👉 Interface réseau détectée : '$DETECTED_IFACE'. Entrée pour valider : " IFACE_CHOICE
IFACE_CHOICE=${IFACE_CHOICE:-$DETECTED_IFACE}

read -p "👉 Adresse IP statique (ex: 192.168.1.50) : " IP_ADDRESS
read -p "👉 Masque de sous-réseau (ex: 255.255.255.0) : " NETMASK
read -p "👉 Passerelle par défaut (Gateway) : " GATEWAY
read -p "👉 Serveur DNS (ex: 8.8.8.8) : " DNS_SERVER

echo -e "\n✅ L'installation commence...\n"
sleep 2

echo "⚙️  Application du nom d'hôte ($HOSTNAME_CHOICE)..."
hostnamectl set-hostname "$HOSTNAME_CHOICE"
sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME_CHOICE/g" /etc/hosts

echo "📦 Mise à jour de base et installation des prérequis..."
apt update && apt upgrade -y
# On installe resolvconf ici
apt install -y ufw resolvconf curl wget gnupg2 apt-transport-https

# ==============================================================================
# 🛡️ LE FAMEUX PATCH ANTI-COUPURE DNS
# ==============================================================================
echo "🔧 Application du patch DNS pour éviter la coupure..."
echo "nameserver $DNS_SERVER" > /etc/resolv.conf
if [ -d "/etc/resolvconf/resolv.conf.d" ]; then
    echo "nameserver $DNS_SERVER" > /etc/resolvconf/resolv.conf.d/head
    resolvconf -u || true
fi
# On re-teste la connexion immédiatement après le patch
if ! ping -c 2 deb.debian.org &> /dev/null; then
    echo "❌ ERREUR : Le DNS ($DNS_SERVER) ne répond pas. Veuillez vérifier cette adresse."
    exit 1
fi
echo "✅ Connexion DNS maintenue avec succès !"
# ==============================================================================

echo "🛡️  Configuration du pare-feu (UFW)..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp     # SSH
ufw allow 80/tcp     # HTTP (Apache)
ufw allow 443/tcp    # HTTPS (Apache SSL)
ufw allow 10000/tcp  # Webmin
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

echo "🌐 Installation du serveur web Apache 2..."
apt install -y apache2
systemctl enable apache2
systemctl start apache2

echo "🛠️  Installation de Webmin (Interface d'administration)..."
# Méthode officielle moderne d'installation de Webmin via leur script de dépôt
curl -o setup-repos.sh https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh
sh setup-repos.sh -f
apt update
apt install -y webmin --install-recommends
rm setup-repos.sh

echo "=========================================================="
echo " 🎉 INSTALLATION D'APACHE & WEBMIN TERMINÉE !"
echo "=========================================================="
echo "👉 Page par défaut Apache : http://$IP_ADDRESS"
echo "👉 Interface Webmin : https://$IP_ADDRESS:10000"
echo "⚠️  Note : Votre navigateur affichera une alerte SSL pour Webmin, c'est normal."
echo "👉 Connectez-vous à Webmin avec les identifiants 'root' ou votre utilisateur sudo actuel."
echo ""
read -p "Voulez-vous redémarrer le serveur maintenant pour appliquer l'IP statique ? (o/n) " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" == "o" || "$REBOOT_CHOICE" == "O" ]]; then
    sudo reboot
fi
