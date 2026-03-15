# 🔒 Déploiement Automatisé : Vaultwarden (Bitwarden)

## 📝 Description
Ce script Bash déploie **Vaultwarden**, une réécriture ultra-légère (en Rust) de l'API serveur du célèbre gestionnaire de mots de passe **Bitwarden**. Il est 100% compatible avec toutes les extensions de navigateur et applications mobiles Bitwarden officielles, tout en consommant drastiquement moins de RAM que la version officielle.

C'est l'outil indispensable pour reprendre le contrôle total de votre vie numérique et de vos secrets, sans dépendre du Cloud public.

## ✨ Fonctionnalités & Sécurité
* **Fermeture des inscriptions :** Par défaut (`SIGNUPS_ALLOWED=false`), personne ne peut créer de compte libre sur votre serveur s'il découvre son adresse. Les invitations se gèrent dans le panneau d'administration caché (`/admin`).
* **Admin Token :** Le script vous laisse le choix de saisir votre propre mot de passe administrateur ou de laisser le système générer un token ultra-robuste de 64 caractères aléatoires.
* **Légèreté absolue :** Utilise la base de données native **SQLite**. Tout votre coffre-fort (mots de passe, notes sécurisées) tient dans le dossier persistant `/opt/vaultwarden/data`, rendant les sauvegardes extrêmement simples.
* **Ports Modifiables :** Le port d'écoute interne (Défaut: `8000`) est personnalisable pour éviter les conflits si vous hébergez d'autres services Web sur la même machine.

## 🚀 Utilisation

Lancez le script via le menu interactif global de ce dépôt :

```bash
sudo apt update -y && sudo apt install -y curl && curl -sO https://raw.githubusercontent.com/VOTRE_PSEUDO/VOTRE_DEPOT/main/menu.sh && bash menu.sh
```
*(Choisissez "Installer un service" puis "Vaultwarden").*

## 🏁 Après l'installation (⚠️ HTTPS OBLIGATOIRE)
1. **L'exigence HTTPS :** Vaultwarden utilise la cryptographie côté client (les données sont chiffrées dans votre navigateur avant d'être envoyées au serveur). Par conséquent, **les navigateurs refusent de fonctionner si la connexion n'est pas sécurisée par HTTPS**.
2. Allez sur votre serveur **Nginx Proxy Manager** (installable via notre script précédent).
3. Créez une redirection (ex: `https://coffre.mondomaine.fr`) pointant vers l'IP de votre machine Vaultwarden sur le port que vous avez choisi.
4. Générez le certificat SSL via NPM.
5. Accédez à `https://coffre.mondomaine.fr/admin` avec votre Admin Token, créez votre compte utilisateur, puis connectez-vous avec l'application Bitwarden !
