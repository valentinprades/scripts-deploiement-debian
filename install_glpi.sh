#!/bin/bash
# Script Universel de Déploiement : Debian 12/13 + GLPI
# Pile : Apache2, MariaDB, PHP + UFW + Réseau Statique (AVEC PATCH DNS)

# 🛑 SÉCURITÉ : Arrête le script immédiatement à la moindre erreur
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
echo "   🚀 DÉPLOIEMENT AUTOMATISÉ : DEBIAN 12/13 + GLPI"
echo "=========================================================="

# ---------------------------------------------------------
# ÉTAPE 1 : QUESTIONS INTERACTIVES (Réseau & Système)
# ---------------------------------------------------------
echo -e "\n--- 🛠️  CONFIGURATION DU SYSTÈME ---"

read -p "👉 Nom de la machine (Hostname) [ex: srv-glpi] : " HOSTNAME_CHOICE
HOSTNAME_CHOICE=${HOSTNAME_CHOICE:-srv-glpi}

DETECTED_IFACE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP '(?<=dev )[^ ]+')
read -p "👉 Interface réseau détectée : '$DETECTED_IFACE'. Appuyez sur Entrée pour valider ou saisissez (ex: eth0) : " IFACE_CHOICE
IFACE_CHOICE=${IFACE_CHOICE:-$DETECTED_IFACE}

read -p "👉 Adresse IP statique (ex: 192.168.1.60) : " IP_ADDRESS
read -p "👉 Masque de sous-réseau (ex: 255.255.255.0) : " NETMASK
read -p "👉 Passerelle par défaut (Gateway) : " GATEWAY
read -p "👉 Serveur DNS (ex: 8.8.8.8) : " DNS_SERVER

echo -e "\n--- 🔐 CONFIGURATION BASE DE DONNÉES GLPI ---"
DB_NAME="glpidb"
DB_USER="glpiuser"
read -s -p "👉 Créez un mot de passe pour l'utilisateur MariaDB de GLPI : " DB_PASS
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
# 🛡️ SÉCURITÉ 1 : TEST DE CONNEXION INITIAL
# ---------------------------------------------------------
echo "🔍 Vérification de la connexion Internet et du DNS..."
if ! ping -c 2 deb.debian.org &> /dev/null; then
    echo "❌ ERREUR CRITIQUE : Le serveur n'a pas accès à Internet ou le DNS ne répond pas."
    exit 1
fi
echo "✅ Connexion Internet OK !"

# ---------------------------------------------------------
# ÉTAPE 2 : CONFIGURATION DE BASE ET PATCH DNS
# ---------------------------------------------------------
echo "⚙️  Application du nom d'hôte ($HOSTNAME_CHOICE)..."
hostnamectl set-hostname "$HOSTNAME_CHOICE"
sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME_CHOICE/g" /etc/hosts

echo "🕒 Configuration du fuseau horaire (Europe/Paris)..."
timedatectl set-timezone Europe/Paris

echo "📦 Mise à jour de base et installation des utilitaires..."
apt update && apt upgrade -y
apt install -y ufw resolvconf wget curl jq unzip

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
    echo "❌ ERREUR : Le DNS ($DNS_SERVER) ne répond pas. Veuillez vérifier cette adresse."
    exit 1
fi
echo "✅ Connexion DNS maintenue avec succès !"
# ==============================================================================

# ---------------------------------------------------------
# ÉTAPE 3 : PARE-FEU ET RÉSEAU STATIQUE
# ---------------------------------------------------------
echo "🛡️  Configuration du pare-feu (UFW)..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp  # SSH
ufw allow 80/tcp  # HTTP
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
# ÉTAPE 4 : INSTALLATION DE LA PILE WEB ET GLPI
# ---------------------------------------------------------
echo "🛠️  Installation d'Apache, MariaDB et PHP (Paquets universels)..."
apt install -y apache2 mariadb-server \
php php-mysql php-xml php-common php-json \
php-gd php-mbstring php-curl php-zip php-bz2 \
php-intl php-ldap php-apcu php-bcmath

echo "🗄️  Configuration de MariaDB..."
systemctl start mariadb
systemctl enable mariadb
mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

echo "📥 Téléchargement de la dernière version de GLPI..."
LATEST_URL=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | grep browser_download_url | grep -v "sha256" | cut -d '"' -f 4)
wget -q -O /tmp/glpi-latest.tgz "$LATEST_URL"

echo "📂 Décompression dans /var/www/glpi..."
tar -xzf /tmp/glpi-latest.tgz -C /var/www/
rm /tmp/glpi-latest.tgz

echo "🔒 Configuration des permissions Web..."
chown -R www-data:www-data /var/www/glpi
find /var/www/glpi -type d -exec chmod 755 {} \;
find /var/www/glpi -type f -exec chmod 644 {} \;

echo "🌐 Configuration du VirtualHost Apache..."
cat <<EOF > /etc/apache2/sites-available/glpi.conf
<VirtualHost *:80>
    ServerName $IP_ADDRESS
    DocumentRoot /var/www/glpi/public

    <Directory /var/www/glpi/public>
        Require all granted
        RewriteEngine On
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
</VirtualHost>
EOF

a2enmod rewrite
a2dissite 000-default.conf
a2ensite glpi.conf
systemctl restart apache2

echo "=========================================================="
echo " 🎉 INSTALLATION TERMINÉE !"
echo "=========================================================="
echo "👉 Future URL GLPI : http://$IP_ADDRESS"
echo "👉 Utilisateur BDD : $DB_USER"
echo "👉 Serveur SQL (MariaDB ou MySQL) : localhost"
echo "👉 Utilisateur SQL : glpiuser"
echo "👉 Mot de passe SQL : (Mot de passe saisi au début du script)."
echo "👉 Final login : Login : glpi Mot de passe : glpi"
read -p "Voulez-vous redémarrer le serveur maintenant pour appliquer l'IP statique ? (o/n) " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" == "o" || "$REBOOT_CHOICE" == "O" ]]; then
    echo "Redémarrage en cours... Connectez-vous ensuite avec votre nouvelle IP : $IP_ADDRESS"
    sudo reboot
else
    echo "N'oubliez pas de redémarrer le serveur plus tard."
fi
