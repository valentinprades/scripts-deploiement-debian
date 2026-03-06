# 🥑 Déploiement Automatisé : Apache Guacamole sur Debian 12/13

## 📝 Description
Ce script Bash permet de déployer **Apache Guacamole**, une passerelle de bureau à distance "clientless". Il vous permet d'accéder à vos serveurs et machines (via RDP, SSH, VNC, Telnet) directement depuis n'importe quel navigateur web, sans aucun plugin ni client lourd à installer.

L'architecture déployée est une "usine à gaz" parfaitement orchestrée via Docker, comprenant :
1. **Guacd :** Le démon natif qui gère la traduction des protocoles (RDP/SSH vers HTML5).
2. **PostgreSQL 15 :** La base de données relationnelle pour stocker vos utilisateurs, connexions et historiques.
3. **Guacamole Web (Tomcat) :** L'application Java qui fournit l'interface web sécurisée.

## ✨ Fonctionnalités
* **Déploiement 100% Dockerisé :** Les trois composants sont interconnectés dans un réseau privé Docker sécurisé.
* **Sécurité Autonome :** Génération automatique d'un mot de passe complexe et aléatoire pour la base de données interne (sans aucune action requise de votre part).
* **Compatibilité Moderne :** Intègre les dernières normes de variables d'environnement (compatibilité garantie avec Guacamole 1.6+).
* **Idempotence (Auto-Réparation) :** Le script est capable de nettoyer une ancienne installation corrompue et de recréer une base de données saine automatiquement.
* **Sécurisation Réseau :** Configuration interactive de l'IP statique et ouverture stricte du port `8080` via le pare-feu `ufw`.
* **🌐 Patch DNS Anti-Coupure :** Résolution garantie lors des modifications des interfaces réseau.

## 🚀 Utilisation

Lancez le script via le menu interactif global de ce dépôt :

\`\`\`bash
sudo apt update -y && sudo apt install -y curl && curl -sO https://raw.githubusercontent.com/valentinprades/scripts-deploiement-debian/main/menu.sh && bash menu.sh
\`\`\`
*(Choisissez "Installer un service" puis "Apache Guacamole").*

## 🏁 Après l'installation
Une fois le déploiement terminé (comptez environ 15 à 30 secondes pour l'initialisation de la base de données) :
1. Accédez à l'interface via : `http://VOTRE_IP_STATIQUE:8080/guacamole`
2. Connectez-vous avec les identifiants administrateur par défaut :
   * **Utilisateur :** `guacadmin`
   * **Mot de passe :** `guacadmin`
3. ⚠️ **Action requise immédiatement :** Allez dans les paramètres en haut à droite, créez un nouvel administrateur avec un mot de passe fort, déconnectez-vous, puis supprimez le compte `guacadmin` par défaut !
