# 📊 Déploiement Automatisé : Beszel (Monitoring) sur Debian 12/13

## 📝 Description
Ce script Bash permet de déployer **Beszel**, une solution de supervision (monitoring) moderne, ultra-légère et intuitive. Conçu comme une alternative épurée aux usines à gaz traditionnelles, Beszel offre des métriques en temps réel, un historique complet, des alertes, et une intégration native pour surveiller l'état de vos conteneurs Docker.

L'architecture est scindée en deux :
1. **Le Hub :** Le serveur central qui stocke les données (via PocketBase) et affiche l'interface web.
2. **L'Agent :** Un service microscopique à installer sur chaque machine à surveiller.

## ✨ Fonctionnalités
* **Installation Modulaire :** Le script vous demande de manière interactive si vous souhaitez installer le Hub (pour la tour de contrôle) ou l'Agent (pour un serveur à surveiller).
* **Déploiement Dockerisé :** Les deux composants sont encapsulés proprement via Docker Compose. L'Agent dispose d'un accès en lecture seule au socket Docker pour remonter les statistiques de vos autres conteneurs.
* **Ports Dynamiques :** Choix interactif du port d'accès Web (pour le Hub) ou du port d'écoute (pour l'Agent).
* **Sécurisation Automatique :** Le pare-feu `ufw` s'adapte automatiquement à votre choix (ouverture du port Web ou du port Agent). La communication Agent/Hub est chiffrée via une clé SSH Ed25519.
* **🌐 Patch DNS Anti-Coupure :** Résolution garantie lors des modifications réseau pour ne jamais bloquer l'installation.

## 🚀 Utilisation

Lancez le script via le menu interactif global de ce dépôt :

\`\`\`bash
sudo apt update -y && sudo apt install -y curl && curl -sO https://raw.githubusercontent.com/valentinprades/scripts-deploiement-debian/main/menu.sh && bash menu.sh
\`\`\`
*(Choisissez "Installer un service" puis "Beszel").*

## 🏁 Après l'installation

**Étape 1 : Le Hub (Serveur Central)**
1. Connectez-vous à `http://VOTRE_IP_STATIQUE:PORT_CHOISI`
2. Créez votre compte administrateur.
3. Cliquez sur "Add System" pour ajouter un serveur à surveiller. Copiez la clé publique générée par le Hub.

**Étape 2 : L'Agent (Sur vos autres serveurs)**
1. Lancez à nouveau ce script sur la machine que vous souhaitez surveiller.
2. Choisissez l'option "2) Agent".
3. Collez la clé publique récupérée à l'étape précédente. L'agent remontera instantanément les données vers le Hub.
