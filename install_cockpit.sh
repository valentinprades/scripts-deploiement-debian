#!/bin/bash
# Script de Post-Installation Debian 12/13 et Déploiement de Cockpit
# Pile : Cockpit (Interface Web d'administration) + UFW + Réseau Statique (AVEC PATCH DNS)

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
echo "   🚀 DÉPLOIEMENT AUTOMATISÉ : DEBIAN 12/13 + COCKPIT"
echo "=========================================================="

# ---------------------------------------------------------
# ÉTAPE 1 : QUESTIONS INTERACTIVES
# ---------------------------------------------------------
echo -e "\n--- 🛠️  CONFIGURATION DU SYSTÈME ---"

read -p "👉 Nom de la machine (Hostname) [ex: srv-cockpit] : " HOSTNAME_CHOICE
HOSTNAME_CHOICE=${HOSTNAME_CHOICE:-srv-cockpit}

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

echo "📦 Mise à jour du système et installation des prérequis..."
apt update && apt upgrade -y
apt install -y ufw resolvconf curl wget jq

# ==============================================================================
# 🛡️ PATCH ANTI-COUPURE DNS
# ==============================================================================
echo "🔧 Application du patch DNS pour éviter la coupure..."
echo "nameserver $DNS_SERVER" > /etc/resolv.conf
if [ -d "/etc/resolvconf/resolv.conf.d" ]; then
    echo "nameserver $DNS_SERVER" > /etc/resolvconf/resolv.conf.d/head
    resolvconf -u || true
fi
# On vérifie immédiatement si le patch a fonctionné avant de continuer
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
ufw allow 9090/tcp # Port Web d'administration Cockpit
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
# ÉTAPE 3 : INSTALLATION DE COCKPIT
# ---------------------------------------------------------
echo "📥 Installation de Cockpit depuis les dépôts officiels Debian..."
# Installation de Cockpit + cockpit-storaged pour une excellente gestion des disques
apt install -y cockpit cockpit-storaged

echo "🚀 Activation du service Cockpit..."
systemctl enable --now cockpit.socket

echo "=========================================================="
echo " 🎉 INSTALLATION DE COCKPIT TERMINÉE !"
echo "=========================================================="
echo "👉 URL d'administration : https://$IP_ADDRESS:9090"
echo "👉 Identifiants : Utilisez votre compte utilisateur Linux (et son mot de passe)"
echo "⚠️ Note : Votre navigateur affichera un avertissement de sécurité (certificat auto-signé), c'est normal."
echo ""
read -p "Voulez-vous redémarrer le serveur maintenant pour appliquer l'IP statique ? (o/n) " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" == "o" || "$REBOOT_CHOICE" == "O" ]]; then
    echo "Redémarrage en cours... Connectez-vous ensuite sur la nouvelle IP."
    sudo reboot
else
    echo "N'oubliez pas de redémarrer le serveur plus tard."
fi
