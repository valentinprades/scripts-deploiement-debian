#!/bin/bash
# Script de Post-Installation Debian 12/13 et Déploiement n8n
# Pile : Docker (Officiel), Docker Compose V2, PostgreSQL, n8n + NGINX (HTTPS)

set -e # 🛑 Arrêt immédiat en cas d'erreur

# --- AUTO-ÉLÉVATION DES PRIVILÈGES (SUDO) ---
if [ "$EUID" -ne 0 ]; then
  echo "⚠️  Ce script doit modifier des fichiers système."
  echo "🔄 Demande des droits d'administration en cours..."
  exec sudo bash "$0" "$@"
  exit $?
fi

echo "=========================================================="
echo "   🚀 DÉPLOIEMENT AUTOMATISÉ : N8N + HTTPS (REVERSE PROXY)"
echo "=========================================================="

# --- ÉTAPE 1 : QUESTIONS INTERACTIVES ---
echo -e "\n--- 🛠️  CONFIGURATION DU SYSTÈME ---"
read -p "👉 Nom de la machine (Hostname) [ex: srv-n8n] : " HOSTNAME_CHOICE
HOSTNAME_CHOICE=${HOSTNAME_CHOICE:-srv-n8n}

DETECTED_IFACE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP '(?<=dev )[^ ]+')
read -p "👉 Interface réseau détectée : '$DETECTED_IFACE'. Entrée pour valider ou saisissez (ex: eth0) : " IFACE_CHOICE
IFACE_CHOICE=${IFACE_CHOICE:-$DETECTED_IFACE}

read -p "👉 Adresse IP statique (ex: 192.168.1.90) : " IP_ADDRESS
read -p "👉 Masque de sous-réseau (ex: 255.255.255.0) : " NETMASK
read -p "👉 Passerelle par défaut (Gateway, ex: 192.168.1.254) : " GATEWAY
read -p "👉 Serveur DNS (ex: 8.8.8.8) : " DNS_SERVER

echo -e "\n--- 🔐 CONFIGURATION DE LA BASE DE DONNÉES N8N ---"
DB_USER="n8n_db_user"
read -s -p "👉 Créez un mot de passe pour la base PostgreSQL interne de n8n : " DB_PASS
echo ""

echo -e "\n--- 🌐 CONFIGURATION WEB ET SÉCURITÉ (HTTPS) ---"
read -p "👉 Avez-vous un nom de domaine (FQDN) pour ce serveur ? (ex: n8n.domaine.com) [Laissez vide pour utiliser l'IP] : " FQDN

if [ -n "$FQDN" ]; then
    read -p "👉 Voulez-vous générer un certificat valide Let's Encrypt pour $FQDN ? (o/n) : " USE_LE
    if [[ "$USE_LE" =~ ^[Oo]$ ]]; then
        read -p "👉 Adresse email pour Let's Encrypt : " LE_EMAIL
    fi
else
    echo "ℹ️ Aucun domaine renseigné. Un certificat auto-signé sera généré pour l'adresse IP ($IP_ADDRESS)."
    FQDN=$IP_ADDRESS
    USE_LE="n"
fi

echo -e "\n✅ L'installation commence...\n"
sleep 2

# --- 🛡️ SÉCURITÉ : TEST DE CONNEXION ---
echo "🔍 Vérification de la connexion Internet et du DNS..."
if ! ping -c 2 deb.debian.org &> /dev/null; then
    echo "❌ ERREUR CRITIQUE : Le serveur n'a pas accès à Internet."
    exit 1
fi

# --- ÉTAPE 2 : CONFIGURATION SYSTÈME & RÉSEAU ---
echo "⚙️  Application du nom d'hôte ($HOSTNAME_CHOICE)..."
hostnamectl set-hostname "$HOSTNAME_CHOICE"
sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME_CHOICE/g" /etc/hosts

echo "🕒 Configuration du fuseau horaire (Europe/Paris)..."
timedatectl set-timezone Europe/Paris

echo "🛡️  Installation et configuration du pare-feu (UFW)..."
apt update && apt upgrade -y
# L'installation de resolvconf est groupée avec les autres prérequis
apt install -y ufw resolvconf curl wget jq nginx openssl
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP (Pour le proxy et Let's Encrypt)
ufw allow 443/tcp   # HTTPS (Pour l'accès web sécurisé)
ufw --force enable

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
if ! ping -c 2 download.docker.com &> /dev/null; then
    echo "❌ ERREUR : Le serveur n'arrive toujours pas à joindre Docker. Vérifiez votre DNS."
    exit 1
fi
echo "✅ Connexion DNS maintenue avec succès !"
# ==============================================================================

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

# --- ÉTAPE 3 : INSTALLATION DE DOCKER & N8N ---
echo "🐳 Installation de Docker Engine officiel..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable docker
systemctl start docker

echo "📂 Création du fichier de déploiement n8n..."
mkdir -p /opt/n8n
cd /opt/n8n
cat <<EOF > docker-compose.yml
version: '3.8'

volumes:
  db_storage:
  n8n_storage:

services:
  postgres:
    image: postgres:16
    restart: always
    environment:
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASS}
      - POSTGRES_DB=n8n
    volumes:
      - db_storage:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -h localhost -U ${DB_USER} -d n8n']
      interval: 5s
      timeout: 5s
      retries: 10

  n8n:
    image: docker.n8n.io/n8nio/n8n
    restart: always
    ports:
      - "127.0.0.1:5678:5678" # 🔒 Sécurité: n8n ne répond qu'à Nginx en local
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_USER=${DB_USER}
      - DB_POSTGRESDB_PASSWORD=${DB_PASS}
      - N8N_BASIC_AUTH_ACTIVE=false
      - WEBHOOK_URL=https://${FQDN}/
    volumes:
      - n8n_storage:/home/node/.n8n
    depends_on:
      postgres:
        condition: service_healthy
EOF

docker compose up -d

# --- ÉTAPE 4 : CONFIGURATION NGINX & HTTPS ---
echo "🔒 Configuration du Proxy Inverse (Nginx)..."

if [[ "$USE_LE" =~ ^[Oo]$ ]]; then
    # Préparation pour Let's Encrypt
    cat <<EOF > /etc/nginx/sites-available/n8n.conf
server {
    listen 80;
    server_name $FQDN;

    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_set_header Connection '';
        proxy_http_version 1.1;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_cache off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/n8n.conf /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx

    echo "🌐 Lancement de Certbot (Let's Encrypt)..."
    apt install -y certbot python3-certbot-nginx
    certbot --nginx -d "$FQDN" --non-interactive --agree-tos -m "$LE_EMAIL" --redirect
else
    # Configuration Certificat Auto-Signé
    echo "🔑 Génération du certificat auto-signé..."
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/ssl/private/n8n-selfsigned.key \
    -out /etc/ssl/certs/n8n-selfsigned.crt \
    -subj "/CN=$FQDN"

    cat <<EOF > /etc/nginx/sites-available/n8n.conf
server {
    listen 80;
    server_name $FQDN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $FQDN;

    ssl_certificate /etc/ssl/certs/n8n-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/n8n-selfsigned.key;

    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_set_header Connection '';
        proxy_http_version 1.1;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_cache off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/n8n.conf /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx
fi

echo "=========================================================="
echo " 🎉 INSTALLATION DE N8N SÉCURISÉE TERMINÉE !"
echo "=========================================================="
echo "👉 Future URL (Sécurisée) : https://$FQDN"
echo "⚠️ Si vous avez utilisé un certificat auto-signé, votre navigateur"
echo "   affichera un avertissement la première fois. Acceptez le risque."
echo ""
read -p "Voulez-vous redémarrer le serveur maintenant pour appliquer l'IP statique ? (o/n) " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" == "o" || "$REBOOT_CHOICE" == "O" ]]; then
    sudo reboot
fi
