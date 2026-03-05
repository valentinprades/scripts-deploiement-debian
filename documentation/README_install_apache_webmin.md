# 🚀 Déploiement Automatisé : Apache 2 & Webmin (GUI) sur Debian 12 & 13

## 📝 Description
Ce script Bash automatise la configuration complète d'un serveur web Apache 2 sur une machine Debian (12 ou 13). Pour faciliter l'administration quotidienne sans passer exclusivement par la ligne de commande, le script installe également Webmin, une interface graphique (GUI) puissante accessible via navigateur, permettant de gérer vos sites, vos fichiers et votre système en quelques clics.

## ✨ Fonctionnalités
* **Résilience Anti-Erreur :** Utilisation de `set -e` et vérification préalable de la résolution DNS pour éviter tout échec en cours de route.
* **Auto-élévation :** Passage automatique en mode `sudo` si nécessaire.
* **Sécurité Réseau (UFW) :** Configuration stricte du pare-feu autorisant le SSH (22), le Web (80, 443) et l'administration Webmin (10000).
* **Réseau Statique :** Passage interactif d'une configuration DHCP à une IP fixe robuste.
* **Durcissement Apache :** Masquage des signatures du serveur et de l'OS pour limiter les informations données aux attaquants potentiels.
* **Correctif de Sécurité 2026 :** Installation de Webmin via le dépôt "stable" avec des clés de signature modernes (Ed25519/RSA 4096), contournant l'obsolescence du SHA-1 sur Debian 13.

## 🛠️ Prérequis
1. Une machine virtuelle sous Debian 12 ou 13.
2. Une connexion internet active (testée par le script).
3. Un utilisateur avec droits `sudo`.

## 🚀 Utilisation

Pour déployer Apache 2 & Webmin, nous vous recommandons d'utiliser le menu interactif global de ce dépôt. Sur votre machine vierge, lancez simplement la commande suivante :

```bash
sudo apt update -y && sudo apt install -y curl && curl -sO [https://raw.githubusercontent.com/valentinprades/scripts-deploiement-debian/main/menu.sh](https://raw.githubusercontent.com/valentinprades/scripts-deploiement-debian/main/menu.sh) && bash menu.sh
```

## 🚀 Après l'installation (Procédure de mise en place)
Une fois le script terminé et le serveur redémarré :

Étape 1 : Vérification Web

Ouvrez votre navigateur et saisissez : http://VOTRE_IP_STATIQUE

Vous devriez voir la page d'accueil personnalisée confirmant que le serveur Apache est opérationnel.

Étape 2 : Connexion à Webmin

Rendez-vous sur : https://VOTRE_IP_STATIQUE:10000

Note : Votre navigateur affichera une alerte de sécurité. Cliquez sur "Paramètres avancés" puis "Continuer vers le site".

Connectez-vous avec votre utilisateur Linux habituel (celui utilisé pour le SSH).

Étape 3 : Gestion du serveur

Dans le menu de gauche, allez dans Serveurs > Serveur Web Apache.

Vous pouvez maintenant créer vos VirtualHosts, gérer vos répertoires et éditer vos fichiers de configuration directement depuis l'interface visuelle.
