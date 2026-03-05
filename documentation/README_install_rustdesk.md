# 🐳 Installation Automatisée : Portainer & Lazydocker

Ce script Bash permet d'installer et de configurer rapidement les deux meilleurs outils de gestion pour votre environnement Docker : **Portainer** (Interface Web) et **Lazydocker** (Interface Terminal). 

Il a été pensé pour être robuste, sécurisé et idéal pour un environnement Homelab (comme une VM ou un conteneur LXC sous Proxmox).

## ✨ Fonctionnalités

* **Escalade Sudo automatique :** Si vous oubliez de lancer le script en tant qu'administrateur, il relancera la commande automatiquement avec `sudo`.
* **Tests de prérequis :** Vérifie la connexion Internet et la présence de Docker avant de lancer la moindre installation.
* **Déploiement de Portainer CE :** Crée un volume persistant (`portainer_data`) pour ne pas perdre vos configurations lors des mises à jour, et déploie le conteneur sur les ports par défaut.
* **Installation de Lazydocker :** Télécharge la dernière version officielle et la rend accessible à tous les utilisateurs du système.
* **Affichage dynamique :** Détecte l'adresse IP locale de votre serveur pour générer un lien cliquable vers l'interface Web à la fin de l'installation.

## 📋 Prérequis

Avant d'exécuter ce script, assurez-vous que :
1. Vous êtes sur une machine Linux (Debian, Ubuntu, etc.).
2. **Docker est déjà installé** et fonctionnel sur votre machine.
3. Votre utilisateur possède les droits `sudo`.

## 🚀 Utilisation

Pour déployer Portainer et Lazydocker, utilisez le menu interactif global de ce dépôt. Sur votre machine, lancez simplement la commande suivante :

```bash
sudo apt update -y && sudo apt install -y curl && curl -sO [https://raw.githubusercontent.com/valentinprades/scripts-deploiement-debian/main/menu.sh](https://raw.githubusercontent.com/valentinprades/scripts-deploiement-debian/main/menu.sh) && bash menu.sh
```

Laissez-vous guider par les questions interactives à l'écran.

## 🚀 Après l'installation
Une fois le script terminé, il vous sera proposé de redémarrer le serveur pour appliquer la nouvelle adresse IP statique.

Important : Notez bien la clé publique (Key) qui s'affichera en vert à la fin du script.

Téléchargez le client RustDesk sur vos PC/Mac.

Allez dans les paramètres réseau du client RustDesk ("ID/Serveur de relais").

Renseignez l'IP statique de votre serveur dans la case "Serveur ID", et collez la clé publique dans la case "Key". 
Les connexions sont désormais privées et transitent par votre propre VM !
