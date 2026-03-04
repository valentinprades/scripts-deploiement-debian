#!/bin/bash
# Script d'installation automatisée de Portainer CE et Lazydocker
# Prérequis : Serveur avec Docker déjà installé

# 🛑 SÉCURITÉ : Arrête le script immédiatement à la moindre erreur
set -e

# ==============================================================================
# 1. AUTO-ÉLÉVATION DES PRIVILÈGES (SUDO)
# ==============================================================================
if [ "$EUID" -ne 0 ]; then
  echo "🔒 Privilèges administrateur requis. Tentative d'escalade avec sudo..."
  exec sudo bash "$0" "$@"
  exit $?
fi

echo "=========================================================="
echo "   🚀 DÉPLOIEMENT AUTOMATISÉ : PORTAINER & LAZYDOCKER"
echo "=========================================================="

# ==============================================================================
# 2. VÉRIFICATIONS (Internet & Docker)
# ==============================================================================
echo "🌐 Vérification de la connexion Internet..."
if ! ping -c 2 deb.debian.org &> /dev/null; then
  echo "❌ Erreur : Aucune connexion Internet détectée."
  exit 1
fi

echo "🐳 Vérification de la présence de Docker..."
if ! command -v docker &> /dev/null; then
  echo "❌ Erreur : Docker n'est pas installé sur cette machine."
  echo "👉 Veuillez d'abord installer Docker."
  exit 1
fi
echo "✅ Docker est bien présent."

# ==============================================================================
# 3. CONFIGURATION DES PERMISSIONS DOCKER
# ==============================================================================
echo "👤 Configuration des permissions..."
if [ -n "$SUDO_USER" ]; then
  usermod -aG docker "$SUDO_USER"
  echo "✅ L'utilisateur '$SUDO_USER' a été ajouté au groupe 'docker'."
fi

# ==============================================================================
# 4. PARE-FEU (UFW)
# ==============================================================================
echo "🛡️  Vérification et ouverture des ports dans le pare-feu (UFW)..."
if command -v ufw &> /dev/null; then
  ufw allow 8000/tcp # Portainer Edge Agent
  ufw allow 9443/tcp # Portainer Web UI (HTTPS)
  echo "✅ Ports 8000 et 9443 autorisés."
else
  echo "⚠️ UFW n'est pas installé, passage de l'étape pare-feu."
fi

# ==============================================================================
# 5. INSTALLATION DE PORTAINER CE
# ==============================================================================
echo "📦 Déploiement du conteneur Portainer..."
docker volume create portainer_data &> /dev/null || true

# On supprime un éventuel ancien conteneur Portainer pour éviter les conflits
docker rm -f portainer &> /dev/null || true

docker run -d \
  -p 8000:8000 \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

echo "✅ Portainer est installé et en cours d'exécution !"

# ==============================================================================
# 6. INSTALLATION DE LAZYDOCKER (Méthode optimisée)
# ==============================================================================
echo "💻 Installation de Lazydocker..."
# L'utilisation de DIR=/usr/local/bin force l'installation directement au bon endroit pour tous les utilisateurs
curl -s https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | DIR=/usr/local/bin bash

echo "✅ Lazydocker a été installé avec succès dans /usr/local/bin !"

# ==============================================================================
# 7. RÉCAPITULATIF ET LIENS D'ACCÈS
# ==============================================================================
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "=========================================================="
echo "🎉 INSTALLATION TERMINÉE AVEC SUCCÈS !"
echo "=========================================================="
echo "👉 Portainer (Interface Web) : https://${SERVER_IP}:9443"
echo "👉 Lazydocker (Terminal)     : Tapez 'lazydocker' dans ce terminal."

if [ -n "$SUDO_USER" ]; then
  echo ""
  echo "⚠️  IMPORTANT pour Lazydocker :"
  echo "Pour que vos droits s'appliquent sans redémarrer le serveur, tapez ceci :"
  echo "👉  newgrp docker"
fi
