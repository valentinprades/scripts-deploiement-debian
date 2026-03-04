#!/bin/bash
# Script de Post-Installation Debian 12/13 et Déploiement Zabbix 7.0 LTS
# Pile : Apache2, MariaDB + UFW + Réseau Statique (AVEC PATCH DNS)

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
echo "   🚀 DÉPLOIEMENT AUTOMATISÉ : DEBIAN 12/13 + ZABBIX 7.0 LTS"
echo "=========================================================="

# ---------------------------------------------------------
# ÉTAPE 1 : QUESTIONS INTERACTIVES (Réseau & Système)
# ---------------------------------------------------------
echo -e "\n--- 🛠️  CONFIGURATION DU SYSTÈME ---"

read -p "👉 Nom de la machine (Hostname) [ex: srv-zabbix] : " HOSTNAME_CHOICE
HOSTNAME_CHOICE=${HOSTNAME_CHOICE:-srv-zabbix}

DETECTED_IFACE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP '(?<=dev )[^ ]+')
read -p "👉 Interface réseau détectée : '$DETECTED_IFACE'. Entrée pour valider ou saisissez (ex: eth0) : " IFACE_CHOICE
IFACE_CHOICE=${IFACE_CHOICE:-$DETECTED_IFACE}

read -p "👉 Adresse IP statique (ex: 192.168.1.60) : " IP_ADDRESS
read -p "👉 Masque de sous-réseau (ex: 255.255.255.0) : " NETMASK
read -p "👉 Passerelle par défaut (Gateway, ex: 192.168.1.254) : " GATEWAY
read -p "👉 Serveur DNS (ex: 8.8.8.8) : " DNS_SERVER

echo -e "\n--- 🔐 CONFIGURATION BASE DE DONNÉES ZABBIX ---"
DB_NAME="zabbix"
DB_USER="zabbix"
read -s -p "👉 Créez un mot de passe pour l'utilisateur MariaDB de Zabbix : " DB_PASS
echo ""
read -s -p "👉 Confirmez le mot de passe : " DB_PASS_CONFIRM
echo ""

if [ "$DB_PASS" != "$DB_PASS_CONFIRM" ]; then
    echo "❌ Les mots de passe ne correspondent pas. Relancez le script."
    exit 1
fi

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

echo "📦 Mise à jour de base et installation des prérequis..."
apt update && apt upgrade -y
apt install -y ufw resolvconf wget curl jq

# ==============================================================================
# 🛡️ PATCH ANTI-COUPURE DNS
# ==============================================================================
echo "🔧 Application du patch DNS pour éviter la coupure..."
echo "nameserver $DNS_SERVER" > /etc/resolv.conf
if [ -d "/etc/resolvconf/resolv.conf.d" ]; then
    echo "nameserver $DNS_SERVER" > /etc/resolvconf/resolv.conf.d/head
    resolvconf -u || true
fi
# On vérifie immédiatement si le patch a fonctionné avant de contacter les dépôts Zabbix
if ! ping -c 2 repo.zabbix.com &> /dev/null; then
    echo "❌ ERREUR : Le serveur n'arrive pas à joindre les dépôts Zabbix. Vérifiez votre DNS."
    exit 1
fi
echo "✅ Connexion DNS maintenue avec succès !"
# ==============================================================================

echo "🛡️  Configuration du pare-feu (UFW)..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp     # SSH
ufw allow 80/tcp     # HTTP (Interface Web Zabbix)
ufw allow 10050/tcp  # Zabbix Agent
ufw allow 10051/tcp  # Zabbix Server (pour recevoir les données des agents actifs)
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
# ÉTAPE 3 : INSTALLATION MARIADB ET ZABBIX
# ---------------------------------------------------------
echo "🗄️  Installation de MariaDB..."
apt install -y mariadb-server
systemctl start mariadb
systemctl enable mariadb

echo "🔐 Création de la base de données Zabbix..."
mysql -e "create database ${DB_NAME} character set utf8mb4 collate utf8mb4_bin;"
mysql -e "create user '${DB_USER}'@'localhost' identified by '${DB_PASS}';"
mysql -e "grant all privileges on ${DB_NAME}.* to '${DB_USER}'@'localhost';"
mysql -e "set global log_bin_trust_function_creators = 1;"
mysql -e "flush privileges;"

echo "📥 Ajout des dépôts officiels Zabbix 7.0 LTS..."
# Récupération automatique de la version de Debian (12 ou 13)
DEB_VERSION=$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2)
wget -q -O /tmp/zabbix-release.deb "https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-2+debian${DEB_VERSION}_all.deb"
dpkg -i /tmp/zabbix-release.deb
apt update

echo "🛠️  Installation des paquets Zabbix (Serveur, Frontend Apache, Agent)..."
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

echo "📂 Importation du schéma de base de données Zabbix (cela peut prendre 1 à 2 minutes)..."
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u${DB_USER} -p"${DB_PASS}" ${DB_NAME}

echo "🔒 Sécurisation de MariaDB post-importation..."
mysql -e "set global log_bin_trust_function_creators = 0;"

echo "⚙️  Configuration du mot de passe DB dans Zabbix Server..."
sed -i "s/# DBPassword=/DBPassword=${DB_PASS}/g" /etc/zabbix/zabbix_server.conf

echo "🔄 Redémarrage et activation des services..."
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2

echo "=========================================================="
echo " 🎉 INSTALLATION DE ZABBIX TERMINÉE !"
echo "=========================================================="
echo "👉 Future URL Zabbix : http://$IP_ADDRESS/zabbix"
echo "👉 Utilisateur par défaut de l'interface web : Admin"
echo "👉 Mot de passe par défaut de l'interface web : zabbix"
echo ""
read -p "Voulez-vous redémarrer le serveur maintenant pour appliquer l'IP statique ? (o/n) " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" == "o" || "$REBOOT_CHOICE" == "O" ]]; then
    echo "Redémarrage en cours... Connectez-vous ensuite sur la nouvelle IP."
    sudo reboot
else
    echo "N'oubliez pas de redémarrer le serveur plus tard."
fi
