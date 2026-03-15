# 🌐 Déploiement Automatisé : Nginx Proxy Manager (NPM)

## 📝 Description
Ce script Bash déploie **Nginx Proxy Manager**, un Reverse Proxy doté d'une interface web magnifique et intuitive. Son rôle est d'écouter les requêtes entrantes sur votre réseau et de les rediriger vers vos différents services (Guacamole, Uptime Kuma, etc.) en fonction du nom de domaine tapé par l'utilisateur. 

C'est l'outil indispensable pour générer et renouveler automatiquement vos certificats HTTPS (Let's Encrypt) en un seul clic, sans jamais avoir à taper une ligne de code de configuration Nginx !

## ✨ Fonctionnalités
* **Architecture Flexible :** L'installateur vous laisse le choix entre une base de données **SQLite** (Ultra-légère, 1 conteneur, recommandée pour Homelab) ou **MariaDB** (Pour les environnements de haute charge, avec génération de mots de passe aléatoires intégrée).
* **Persistance Isolée :** Vos certificats SSL (`letsencrypt`) et configurations (`data`) sont stockés de manière sécurisée dans `/opt/npm/`. Vous pouvez mettre à jour ou supprimer le conteneur sans jamais perdre vos domaines.
* **Sécurité Automatique (UFW) :** Le script ouvre automatiquement les ports vitaux `80` et `443` nécessaires au proxy et à la validation des certificats Let's Encrypt.
* **Port d'Administration Dynamique :** Le port de l'interface graphique (81 par défaut) est personnalisable lors de l'installation pour éviter les conflits.

## 🚀 Utilisation

Lancez le script via le menu interactif global de ce dépôt :

```bash
sudo apt update -y && sudo apt install -y curl && curl -sO https://raw.githubusercontent.com/VOTRE_PSEUDO/VOTRE_DEPOT/main/menu.sh && bash menu.sh
```
*(Choisissez "Installer un service" puis "Nginx Proxy Manager").*

## 🏁 Après l'installation
1. Connectez-vous à l'interface via : `http://VOTRE_IP_STATIQUE:PORT_ADMIN`
2. Connectez-vous avec les identifiants d'usine :
   * **Email :** `admin@example.com`
   * **Mot de passe :** `changeme`
3. ⚠️ L'interface vous obligera immédiatement à modifier ces informations. Entrez votre véritable adresse email (elle servira pour l'expiration des certificats Let's Encrypt) et un mot de passe fort.
4. N'oubliez pas de rediriger les ports 80 et 443 de votre box internet (Routeur) vers l'adresse IP statique de cette machine Proxmox pour pouvoir accéder à vos services depuis l'extérieur !
