# 🚀 Déploiement Automatisé : n8n (via Docker) sur Debian 12 & 13

## 📝 Description
Ce script Bash automatise la préparation d'une machine virtuelle Debian (12 ou 13) et y déploie **n8n**, un puissant outil d'automatisation de flux de travail (workflows) open-source. Pour garantir une stabilité et une portabilité maximales, l'installation s'appuie sur **Docker et Docker Compose** afin de faire tourner l'application n8n et sa base de données PostgreSQL dans des conteneurs isolés et persistants.

## ✨ Fonctionnalités
* **Résilience Anti-Erreur :** Arrêt automatique en cas de problème (`set -e`) et vérification de la connexion Internet avant toute action.
* **Auto-élévation des droits :** Demande automatiquement les privilèges `sudo` si lancé par un utilisateur standard via l'interpréteur bash.
* **Configuration Système :** Personnalisation du nom d'hôte (hostname) et du fuseau horaire (Europe/Paris).
* **Configuration Réseau :** Mise en place interactive d'une adresse IP statique (IP, Masque, Passerelle, DNS).
* **🌐 Patch DNS Anti-Coupure :** Maintient la résolution de nom active lors du rechargement des interfaces réseau pour garantir le téléchargement de Docker et des images n8n.
* **Sécurité (UFW) :** Configuration du pare-feu pour n'autoriser que le SSH (port `22/tcp`) et l'accès web à l'interface n8n (port `5678/tcp`).
* **Moteur Docker :** Installation automatique de Docker et du plugin Docker Compose v2.
* **Déploiement Conteneurisé :** Création à la volée du fichier `docker-compose.yml` liant un conteneur n8n à un conteneur PostgreSQL robuste, avec création des volumes nécessaires pour ne jamais perdre vos données (workflows, identifiants, base de données).

## 🛠️ Prérequis
1. Une machine virtuelle avec **Debian 12 ou 13** fraîchement installée.
2. Un accès internet sur la machine.
3. Un utilisateur avec les droits d'administration (`sudo`).
4. **Configuration recommandée :** 2 à 4 vCPU, 4 à 8 Go de RAM, et 40 Go de stockage SSD.
5. **FQDN (Recommandé) :** Avoir un nom de domaine pointant vers la machine si vous comptez utiliser des Webhooks externes.

## 🚀 Utilisation

Pour déployer n8n, nous vous recommandons d'utiliser le menu interactif global de ce dépôt. Sur votre machine vierge, lancez simplement la commande suivante :

```bash
sudo apt update -y && sudo apt install -y curl && curl -sO [https://raw.githubusercontent.com/valentinprades/scripts-deploiement-debian/main/menu.sh](https://raw.githubusercontent.com/valentinprades/scripts-deploiement-debian/main/menu.sh) && bash menu.sh
```

Laissez-vous guider par les questions interactives à l'écran.

## 🚀 Après l'installation (Procédure de mise en place)
Une fois le script terminé, il vous sera proposé de redémarrer le serveur pour appliquer la nouvelle adresse IP statique.

1. L'initialisation

Ouvrez votre navigateur web et rendez-vous sur : http://VOTRE_IP_STATIQUE:5678

2. Création du compte Propriétaire

Au tout premier lancement, l'interface de n8n vous demandera de créer le compte Administrateur (Owner).
Remplissez simplement les champs avec votre adresse e-mail et un mot de passe fort pour sécuriser définitivement l'accès à votre instance.

3. Votre premier Workflow

Cliquez sur le bouton "Add workflow" (Ajouter un flux de travail) dans le menu de gauche.
L'interface se présente comme une toile vierge. Cliquez sur le gros bouton "+" ou double-cliquez n'importe où pour ajouter votre premier nœud (Node).
L'astuce : Commencez toujours par un nœud de type "Trigger" (Déclencheur), comme par exemple un "Schedule Trigger" (pour lancer une action à heure fixe) ou un "Webhook" (pour écouter les alertes venant de votre serveur Zabbix).
Reliez ensuite ce nœud à une "Action" (par exemple, le nœud "HTTP Request" pour envoyer un message sur Discord/Teams, ou le nœud "GLPI" pour créer un ticket automatiquement).
