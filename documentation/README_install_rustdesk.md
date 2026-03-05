# 🚀 Déploiement Automatisé : RustDesk Server sur Debian 12/13

## 📝 Description
Ce script Bash permet d'automatiser entièrement la préparation d'une machine virtuelle Debian 12/13 "fraîche" et le déploiement de **RustDesk Server** (alternative open-source à TeamViewer). Il configure le système de base, sécurise le réseau et installe les deux composants vitaux de RustDesk : `hbbs` (Serveur d'Identification) et `hbbr` (Serveur de Relais).

## ✨ Fonctionnalités
* **Auto-élévation des droits :** Demande automatiquement les droits `sudo` si lancé par un utilisateur standard.
* **Configuration Système :** Personnalisation du nom d'hôte (hostname) et du fuseau horaire (Europe/Paris).
* **Configuration Réseau :** Mise en place interactive d'une adresse IP statique (IP, Masque, Passerelle, DNS).
* **Sécurité (UFW) :** Configuration du pare-feu `ufw` avec ouverture stricte des ports requis par RustDesk :
  * `22/tcp` (SSH)
  * `21115` à `21119/tcp` (RustDesk TCP)
  * `21116/udp` (RustDesk UDP)
* **RustDesk Server :** Téléchargement dynamique des exécutables binaires purs, création des processus d'arrière-plan via `systemd` pour un démarrage automatique, et affichage en clair de la Clé Publique (Key) générée, indispensable pour chiffrer les connexions.

## 🛠️ Prérequis
1. Une machine virtuelle avec **Debian 12/13** fraîchement installée.
2. Un accès internet sur la machine.
3. Un utilisateur avec les droits d'administration (`sudo`).

## 🚀 Utilisation

1. Créez le fichier sur votre machine virtuelle :
   ```bash
   nano install_rustdesk.sh

2. Collez le code du script
3. Sauvegardez avec Ctrl+O puis Entrée, et quittez avec Ctrl+X
4. Lancez l'installation directement avec l'interpréteur bash :

bash install_rustdesk.sh

Laissez-vous guider par les questions interactives à l'écran.

🏁 Après l'installation
Une fois le script terminé, il vous sera proposé de redémarrer le serveur pour appliquer la nouvelle adresse IP statique.

Important : Notez bien la clé publique (Key) qui s'affichera en vert à la fin du script.

Téléchargez le client RustDesk sur vos PC/Mac.

Allez dans les paramètres réseau du client RustDesk ("ID/Serveur de relais").

Renseignez l'IP statique de votre serveur dans la case "Serveur ID", et collez la clé publique dans la case "Key". 
Les connexions sont désormais privées et transitent par votre propre VM !
