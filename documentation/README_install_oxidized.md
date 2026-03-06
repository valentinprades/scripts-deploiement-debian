# 🔄 Déploiement Automatisé : Oxidized sur Debian 12/13

## 📝 Description
Ce script Bash automatise la préparation d'une machine virtuelle Debian (12 ou 13) et y déploie **Oxidized**, l'outil open-source de référence pour la sauvegarde automatique des configurations d'équipements réseau (switchs, routeurs, pare-feux). Le script génère à la volée une configuration YAML sur-mesure et initialise un dépôt Git local pour versionner chaque modification de vos équipements.

## ✨ Fonctionnalités
* **Modularité d'installation :** Vous avez le choix à l'exécution d'installer Oxidized de manière conteneurisée (Docker) ou de manière Native (compilation Ruby directement sur l'OS).
* **Configuration Dynamique :** Choix interactif du port d'écoute de l'interface Web et ajustement automatique du pare-feu `ufw`.
* **Routage de la Source :** Le script vous permet de définir si vos équipements seront listés manuellement dans un fichier `router.db` ou importés dynamiquement via l'API d'un outil de supervision (comme Zabbix).
* **Robustesse de démarrage :** Le script intègre un équipement local fictif (`127.0.0.1`) par défaut pour garantir que le service démarre sans erreur dès la première seconde.
* **🌐 Patch DNS Anti-Coupure :** Maintient la résolution de nom active lors du rechargement des interfaces réseau.
* **Auto-Versioning (Git) :** Le dépôt de sauvegarde est initialisé nativement pour que vous ayez un historique complet de vos configurations (mode "Time Machine" pour votre réseau).

## 🚀 Utilisation

Pour déployer Oxidized, utilisez le menu interactif global de ce dépôt :

```bash
sudo apt update -y && sudo apt install -y curl && curl -sO https://raw.githubusercontent.com/valentinprades/scripts-deploiement-debian/main/menu.sh && bash menu.sh
```
*(Choisissez "Installer un service" puis sélectionnez "Oxidized").*

## 🏁 Après l'installation
Une fois le redémarrage effectué :
1. Connectez-vous à l'interface Web : `http://VOTRE_IP_STATIQUE:PORT_CHOISI`
2. Configurez vos équipements :
   * **Mode Fichier :** Éditez le fichier `/etc/oxidized/router.db` *(Syntaxe : `IP:modele:utilisateur:mot_de_passe`)*. Pensez à supprimer la ligne `127.0.0.1` générée par défaut une fois vos vrais équipements ajoutés.
   * **Mode API :** Modifiez le bloc `http` dans le fichier `/etc/oxidized/config`.
3. Le service récupérera automatiquement les configurations selon l'intervalle défini dans le YAML.
