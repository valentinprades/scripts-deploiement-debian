# 🚀 Déploiement Automatisé : GLPI sur Debian 12/13

## 📝 Description
Ce script Bash permet d'automatiser entièrement la préparation d'une machine virtuelle Debian 12/13 "fraîche" et le déploiement de la solution de gestion de parc informatique **GLPI** (dernière version stable). Il configure le système, sécurise le réseau et installe la pile technique nécessaire (Apache, MariaDB, PHP 8.2).

## ✨ Fonctionnalités
* **Auto-élévation des droits :** Demande automatiquement les droits `sudo` si lancé par un utilisateur standard.
* **Configuration Système :** Personnalisation du nom d'hôte (hostname) et du fuseau horaire (Europe/Paris).
* **Configuration Réseau :** Mise en place interactive d'une adresse IP statique (IP, Masque, Passerelle, DNS).
* **🌐 Patch DNS Anti-Coupure :** Maintient la résolution de nom active lors du rechargement des interfaces réseau pour garantir le téléchargement de l'archive GLPI.
* **Sécurité :** Installation et configuration du pare-feu `ufw` (blocage par défaut, ouverture de SSH et HTTP).
* **Pile Web (LAMP) :** Installation automatique d'Apache2, MariaDB et des modules PHP 8.2 requis par GLPI.
* **Base de données :** Création interactive et sécurisée de la base de données et de l'utilisateur dédié à GLPI.
* **GLPI :** Téléchargement dynamique de la dernière release depuis GitHub, extraction et configuration automatique des VirtualHosts et des permissions (ciblage du dossier `/public` pour des raisons de sécurité).

## 🛠️ Prérequis
1. Une machine virtuelle avec **Debian 12/13** fraîchement installée.
2. Un accès internet sur la machine (pour télécharger les paquets et l'archive GLPI).
3. Un utilisateur avec les droits d'administration (`sudo`).

## 🚀 Utilisation

Pour déployer GLPI, nous vous recommandons d'utiliser le menu interactif global de ce dépôt. Sur votre machine vierge, lancez simplement la commande suivante :

```bash
sudo apt update -y && sudo apt install -y curl && curl -sO [https://raw.githubusercontent.com/valentinprades/scripts-deploiement-debian/main/menu.sh](https://raw.githubusercontent.com/valentinprades/scripts-deploiement-debian/main/menu.sh) && bash menu.sh
```

## 🚀 Après l'installation
Une fois le script terminé, il vous sera proposé de redémarrer le serveur pour appliquer la nouvelle adresse IP statique.

Connectez-vous ensuite à l'interface web via : http://VOTRE_IP_STATIQUE

Terminez la configuration via l'assistant web de GLPI en utilisant les identifiants de base de données que vous avez définis lors de l'exécution du script.

Serveur SQL (MariaDB ou MySQL) : localhost
(Puisque la base de données est installée sur la même machine virtuelle que le serveur web).

Utilisateur SQL : glpiuser
(C'est le nom d'utilisateur que nous avons "écrit en dur" dans le script).

Mot de passe SQL : (Tapez ici le mot de passe que vous avez vous-même inventé et saisi lors de la question interactive au tout début du script).

Final login :

Login : glpi
Mot de passe : glpi
