# 🛩️ Déploiement Automatisé : Cockpit sur Debian 12/13

## 📝 Description
Ce script Bash permet d'automatiser entièrement la préparation d'une machine virtuelle Debian 12/13 "fraîche" et le déploiement de **Cockpit**. Il s'agit d'une interface d'administration serveur moderne, légère et accessible via navigateur Web. Parfaitement intégrée au système, elle offre une vue en temps réel sur les performances (CPU, RAM, Réseau), la gestion des services `systemd`, la lecture des logs, et inclut un terminal web intégré.

## ✨ Fonctionnalités
* **Auto-élévation des droits :** Demande automatiquement les droits `sudo` si lancé par un utilisateur standard.
* **Configuration Système :** Personnalisation du nom d'hôte (hostname) et du fuseau horaire (Europe/Paris).
* **Configuration Réseau :** Mise en place interactive d'une adresse IP statique (IP, Masque, Passerelle, DNS).
* **🌐 Patch DNS Anti-Coupure :** Maintient la résolution de nom active lors du rechargement des interfaces réseau pour garantir le téléchargement depuis les dépôts Debian.
* **Sécurité (UFW) :** Configuration du pare-feu `ufw` avec ouverture stricte des ports requis :
  * `22/tcp` (SSH)
  * `9090/tcp` (Interface Web de Cockpit)
* **Cockpit & Stockage :** Installation de Cockpit et du module additionnel `cockpit-storaged`, permettant de gérer visuellement vos disques, partitions et la santé SMART de votre stockage.

## 🛠️ Prérequis
1. Une machine virtuelle avec **Debian 12/13** fraîchement installée.
2. Un accès internet sur la machine.
3. Un utilisateur avec les droits d'administration (`sudo`).

## 🚀 Utilisation

Pour déployer Cockpit, nous vous recommandons d'utiliser le menu interactif global de ce dépôt. Sur votre machine vierge, lancez simplement la commande suivante :

```bash
sudo apt update -y && sudo apt install -y curl && curl -sO https://raw.githubusercontent.com/valentinprades/scripts-deploiement-debian/main/menu.sh && bash menu.sh
```

Choisissez ensuite **"Installer un service"** puis sélectionnez **Cockpit** dans la liste. Laissez-vous guider par les questions interactives à l'écran.

## 🏁 Après l'installation
Une fois le script terminé, il vous sera proposé de redémarrer le serveur pour appliquer la nouvelle adresse IP statique.

1. Connectez-vous ensuite à l'interface web via : `https://VOTRE_IP_STATIQUE:9090`
2. *Note : Votre navigateur affichera un avertissement de sécurité. Cliquez sur "Paramètres avancés" puis "Continuer vers le site" (Cockpit utilise un certificat auto-signé par défaut).*

**Identifiants de connexion :**
* **Identifiant :** Utilisez le nom de votre utilisateur Linux habituel (celui avec lequel vous vous connectez en SSH).
* **Mot de passe :** Le mot de passe de cet utilisateur Linux.

*(Astuce : Cochez la case "Réutiliser mon mot de passe pour les tâches privilégiées" lors de la connexion pour pouvoir utiliser les fonctions administrateur directement dans l'interface).*
