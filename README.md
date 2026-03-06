# 🛠️ Scripts de Déploiement Automatisé - Debian 12 & 13

Bienvenue sur mon dépôt d'infrastructure ! 
Ce projet rassemble une collection de scripts Bash interactifs conçus pour automatiser et standardiser le déploiement de services informatiques essentiels en entreprise (ITSM, Supervision, Serveur Web, Automatisation, Gestion Docker). 

Tous les scripts (sauf mention contraire) sont universels et **100% compatibles avec Debian 12 (Bookworm) et Debian 13 (Trixie)**.

## 🛡️ L'ADN de ces scripts (Le Tronc Commun)
Chaque script de ce dépôt a été pensé pour des environnements de production et intègre un socle de configuration standardisé ultra-robuste :
* **Sécurité `set -e` :** Arrêt immédiat du script en cas d'erreur critique pour éviter toute corruption du système.
* **Auto-élévation :** Vérification et demande automatique des droits d'administration (`sudo`).
* **Configuration Interactive :** Le script interroge l'administrateur pour configurer proprement le nom d'hôte (Hostname) et l'adressage IP statique.
* **Pare-feu natif :** Installation et configuration stricte d'UFW (Uncomplicated Firewall) en n'ouvrant que les ports strictement nécessaires au service déployé.
* **🌐 Patch DNS Anti-Coupure :** Intégration d'un correctif réseau exclusif empêchant la perte de résolution DNS lors de l'installation de `resolvconf` et l'application de l'IP statique.

---

## 📦 Catalogue des Services & Prérequis Matériels

Voici la liste des outils d'infrastructure que vous pouvez déployer de manière autonome, avec mes recommandations de dimensionnement pour vos Machines Virtuelles :

### 1. 🎫 GLPI (`install_glpi.sh`)
Solution open-source de gestion de parc informatique (ITAM) et centre d'assistance (Helpdesk). Sa consommation dépend surtout du nombre de techniciens qui utilisent le Helpdesk en même temps et du nombre de pièces jointes.
* **vCPU (Cœurs) :** 2 vCores.
* **RAM :** 4 Go (suffisant pour le cache d'Apache et MariaDB).
* **Stockage :** 30 à 50 Go. Prévoyez un peu plus si vos utilisateurs joignent beaucoup de captures d'écran ou de PDF.
* **🔥 Le point critique :** La RAM lors des fortes charges simultanées.

### 2. 👁️ Zabbix 7.0 LTS (`install_zabbix.sh`)
Plateforme de supervision globale. Zabbix interroge les machines en permanence et écrit des milliers de petites données (métriques) dans la base de données à chaque minute.
* **vCPU (Cœurs) :** 4 vCores (pour traiter les déclencheurs/triggers sans latence).
* **RAM :** 6 à 8 Go minimum. (Zabbix stocke énormément de données en cache RAM pour éviter de saturer le disque).
* **Stockage :** 80 à 100 Go. 
* **🔥 Le point critique :** La vitesse du disque (I/O). Il faut impérativement utiliser du stockage SSD ou NVMe. Si vous utilisez des disques mécaniques (HDD), MariaDB va saturer et Zabbix affichera de fausses alertes de lenteur.

### 3. 🖥️ RustDesk (`install_rustdesk.sh`)
Serveur de relais pour la prise en main à distance (Alternative auto-hébergée à TeamViewer). Il ne traite pas les données, il fait transiter les paquets entre l'utilisateur et le technicien.
* **vCPU (Cœurs) :** 1 à 2 vCores maximum.
* **RAM :** 1 à 2 Go (1 Go suffit amplement).
* **Stockage :** 15 à 20 Go (juste assez pour faire tourner l'OS, pas de base de données lourde).
* **🔥 Le point critique :** La bande passante réseau (débit internet descendant et montant).

### 4. 🤖 n8n (`install_n8n.sh`)
Plateforme d'automatisation de flux de travail (Workflow Automation) pour interconnecter vos API et services. 
* **Pile technique :** Docker Engine, n8n, PostgreSQL 16 (sécurisé) et Nginx (Reverse Proxy).
* **Prérequis :** Nécessite obligatoirement un nom de domaine (FQDN) pointant vers la machine pour la gestion des Webhooks.

### 5. 🌐 Serveur Web & Webmin (`install_apache_webmin.sh`)
Socle idéal pour monter un serveur web classique couplé à une interface d'administration graphique complète (Webmin). 
* **vCPU (Cœurs) :** 1 à 2 vCores.
* **RAM :** 1 à 2 Go.
* **Stockage :** 15 à 20 Go suffisent pour le système de base.
* **🔥 Le point critique :** L'accès à Webmin se fait en HTTPS sur le port `10000`. Acceptez l'avertissement SSL de votre navigateur lors de la première connexion.

### 6. 🐳 Portainer & Lazydocker (`install_portainer_lazydocker.sh`)
Outils de gestion d'environnements Docker. Portainer offre une interface Web complète, et Lazydocker propose une interface terminal ultra-rapide (TUI).
* **Prérequis :** Avoir déjà installé Docker sur la machine cible (Ce script ne configure pas le réseau statique, il se greffe sur l'existant).

### 7. 🛩️ Cockpit Interface d'Administration (install_cockpit.sh)
Déploie Cockpit, une interface web moderne et légère pour l'administration système centralisée, la gestion du stockage (storaged) et la surveillance en temps réel de votre serveur Debian.

### 8. 🔄 Oxidized Sauvegarde d'Équipements Réseau (install_oxidized.sh)
Déploie Oxidized (via Docker ou Natif Ruby) avec versioning Git automatique pour sauvegarder à intervalle régulier les configurations de tous vos équipements réseau (Switchs, Routeurs, Firewall). Port GUI et source de données modifiables à l'installation.

### 9. 📊 Beszel Monitoring Léger (install_beszel.sh)
Déploie l'écosystème Beszel (choix interactif entre le Serveur Hub ou l'Agent Client) via Docker. Une solution de supervision de serveurs et de conteneurs ultra-moderne, épurée et très peu gourmande en ressources.

### 10. 🥑 Guacamole Passerelle Bureau à Distance Apache (install_guacamole.sh)
Déploie l'écosystème complet Guacamole (Guacd, PostgreSQL, Tomcat Web) via Docker Compose. Permet l'accès RDP/SSH/VNC directement depuis un navigateur. Script ultra-robuste avec génération automatique de mots de passe aléatoires et compatibilité avec les dernières normes de l'application (v1.6+).

### 11. 📈 Uptime Kuma Veilleur de Statut (install_uptime-kuma.sh)
Déploie Uptime Kuma via Docker Compose. Un tableau de bord de supervision ultra-réactif qui vérifie l'accessibilité de vos services (Ping, HTTP, TCP) à intervalle régulier et vous notifie en cas de panne (Telegram, Discord, etc.). Port GUI et accès au socket Docker modifiables interactivement.

---

## 🚀 Comment utiliser ces scripts (Méthode One-Liner)

Pour déployer l'un de ces services sur une machine virtuelle vierge (Debian 12 ou 13), connectez-vous en SSH et exécutez la commande suivante. 

```bash
sudo apt update -y && sudo apt install -y curl && curl -sO https://raw.githubusercontent.com/valentinprades/scripts-deploiement-debian/main/menu.sh && bash menu.sh
```

## ⚙️ Maintenabilité : Comment ajouter un nouveau script au menu ?

Ce dépôt utilise un menu interactif dynamique (`menu.sh`). Pour faire évoluer ce catalogue et y ajouter un nouvel outil, merci de respecter la procédure (SOP) suivante :
1. **Le Script :** Ajouter le script à la racine avec l'extension `.sh` (ex: `install_outil.sh`).
2. **La Doc :** Ajouter la documentation dans le dossier `documentation/` sous le nom exact `README_install_outil.md`.
3. **Le Déclencheur :** Déclarer l'outil dans ce README sous le format strict : `### X. Titre (install_outil.sh)`.

Auteur : Valentin Prades | Licence : MIT
