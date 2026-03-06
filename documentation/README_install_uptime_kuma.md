# 📈 Déploiement Automatisé : Uptime Kuma sur Debian 12/13

## 📝 Description
Ce script Bash déploie **Uptime Kuma**, un outil de supervision open-source ultra-léger et moderne. Conçu comme une alternative auto-hébergée à "UptimeRobot" ou "Pingdom", il teste en permanence la disponibilité de vos services réseau (Sites web HTTP/S, serveurs DNS, ports TCP, ping basique). 

Dès qu'un service tombe en panne, il est capable de vous alerter via plus de 90 canaux (Telegram, Discord, Slack, Email, Webhooks...).

## ✨ Fonctionnalités
* **Déploiement Dockerisé :** Un seul conteneur regroupant l'application Node.js et sa base de données SQLite.
* **Persistance des données :** L'historique des pings et la configuration sont sauvegardés en toute sécurité dans un dossier local (`/opt/uptime-kuma/data`), facilitant grandement les sauvegardes.
* **Ports Dynamiques :** Le port d'accès Web est modifiable de manière interactive lors du lancement du script (Par défaut: `3001`).
* **Supervision Docker Locale (Optionnelle) :** Le script vous permet de lier le socket Docker de la machine hôte au conteneur. Cela permet à Uptime Kuma de surveiller directement l'état de vos autres conteneurs.
* **Sécurisation Automatique :** Le pare-feu `ufw` s'adapte automatiquement au port choisi.
* **🌐 Patch DNS Anti-Coupure :** Résolution garantie lors des modifications réseau de la machine.

## 🚀 Utilisation

Lancez le script via le menu interactif global de ce dépôt :

\`\`\`bash
sudo apt update -y && sudo apt install -y curl && curl -sO https://raw.githubusercontent.com/VOTRE_PSEUDO/VOTRE_DEPOT/main/menu.sh && bash menu.sh
\`\`\`
*(Choisissez "Installer un service" puis "Uptime Kuma").*

## 🏁 Après l'installation
1. Connectez-vous à `http://VOTRE_IP_STATIQUE:PORT_CHOISI`
2. Lors de votre toute première visite, l'application vous demandera de créer votre compte administrateur (identifiant et mot de passe).
3. Cliquez sur "Ajouter une sonde" (Add New Monitor) pour commencer à surveiller votre premier service (par exemple, le port 8080 de votre VM Guacamole !).
