# 🚀 Déploiement Automatisé : Zabbix 7.0 LTS sur Debian 12/13

## 📝 Description
Ce script Bash permet d'automatiser entièrement la préparation d'une machine virtuelle Debian 12/13 "fraîche" et le déploiement de la solution de supervision **Zabbix** (version 7.0 LTS). Il configure le système de base, sécurise le réseau et installe la pile technique (Apache, MariaDB, Serveur Zabbix, Frontend, et Agent local).

## ✨ Fonctionnalités
* **Auto-élévation des droits :** Demande automatiquement les droits `sudo` si lancé par un utilisateur standard.
* **Configuration Système :** Personnalisation du nom d'hôte (hostname) et du fuseau horaire (Europe/Paris).
* **Configuration Réseau :** Mise en place interactive d'une adresse IP statique (IP, Masque, Passerelle, DNS).
* **🌐 Patch DNS Anti-Coupure :** Maintient la résolution de nom active lors du rechargement des interfaces réseau pour garantir le téléchargement depuis les dépôts officiels Zabbix.
* **Sécurité (UFW) :** Installation et configuration du pare-feu `ufw` avec ouverture stricte des ports requis :
  * `22/tcp` (SSH)
  * `80/tcp` (Interface Web)
  * `10050/tcp` (Zabbix Agent)
  * `10051/tcp` (Zabbix Server - Trappers)
* **Base de données :** Installation de MariaDB, création interactive de la base et importation automatique du schéma SQL lourd fourni par Zabbix.
* **Zabbix 7.0 LTS :** Ajout des dépôts officiels, installation du serveur, de l'interface Apache et de l'agent local (pour que Zabbix se supervise lui-même). L'injection du mot de passe dans les fichiers de configuration est automatisée.

## 🛠️ Prérequis
1. Une machine virtuelle avec **Debian 12/13** fraîchement installée.
2. Un accès internet sur la machine.
3. Un utilisateur avec les droits d'administration (`sudo`).

## 🚀 Utilisation

Pour déployer Zabbix, nous vous recommandons d'utiliser le menu interactif global de ce dépôt. Sur votre machine vierge, lancez simplement la commande suivante :

```bash
sudo apt update -y && sudo apt install -y curl && curl -sO [https://raw.githubusercontent.com/valentinprades/scripts-deploiement-debian/main/menu.sh](https://raw.githubusercontent.com/valentinprades/scripts-deploiement-debian/main/menu.sh) && bash menu.sh
```

Laissez-vous guider par les questions interactives à l'écran.

## 🚀 Après l'installation
Une fois le script terminé, il vous sera proposé de redémarrer le serveur pour appliquer la nouvelle adresse IP statique.

Connectez-vous ensuite à l'interface web via : http://VOTRE_IP_STATIQUE/zabbix

Terminez la configuration via l'assistant web de Zabbix en utilisant les identifiants de base de données que vous avez définis lors de l'exécution du script 
(Identifiant par défaut : Admin, Mot de passe : zabbix).
