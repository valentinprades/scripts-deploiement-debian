#!/bin/bash
# Script Maître de Déploiement - Interface Whiptail dynamique
# Parse automatiquement le README.md depuis GitHub

# ---------------------------------------------------------
# ✨ AUTO-ÉLÉVATION DES PRIVILÈGES
# ---------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
  exec sudo bash "$0" "$@"
  exit $?
fi

# ---------------------------------------------------------
# 📦 VÉRIFICATION DES DÉPENDANCES DU MENU
# ---------------------------------------------------------
# On s'assure que whiptail (pour l'interface) et curl sont présents
apt-get update -qq && apt-get install -y -qq whiptail curl grep sed

# ---------------------------------------------------------
# 🌐 VARIABLES ET TÉLÉCHARGEMENT
# ---------------------------------------------------------
REPO_URL="https://raw.githubusercontent.com/valentinprades/scripts-deploiement-debian/main"
README_FILE="/tmp/main_readme.md"

# On télécharge silencieusement le README principal
curl -s "$REPO_URL/README.md" -o "$README_FILE"

if [ ! -f "$README_FILE" ]; then
    echo "❌ Erreur : Impossible de joindre le GitHub de Valentin Prades."
    exit 1
fi

# ---------------------------------------------------------
# 🔍 ANALYSE DYNAMIQUE DU README (Scraping)
# ---------------------------------------------------------
declare -a MENU_OPTIONS

# On lit le README ligne par ligne pour chercher les lignes qui commencent par "### 1. " etc.
while read -r line; do
    # On extrait le nom du script (ex: install_glpi.sh)
    SCRIPT_FILE=$(echo "$line" | grep -o '\`[^\`]*\.sh\`' | tr -d '\`')
    # On extrait le nom lisible (ex: 🎫 GLPI)
    DESC=$(echo "$line" | sed -E 's/^### [0-9]+\. (.*) \(`.*/\1/')
    
    if [ -n "$SCRIPT_FILE" ] && [ -n "$DESC" ]; then
        # On ajoute ces infos dans notre tableau pour construire le menu
        MENU_OPTIONS+=("$SCRIPT_FILE" "$DESC")
    fi
done < <(grep -E "^### [0-9]+\. " "$README_FILE")

# ---------------------------------------------------------
# 📖 FONCTION : LECTURE DE DOCUMENTATION
# ---------------------------------------------------------
lire_doc() {
    DOC_CHOICE=$(whiptail --title "📖 Documentation" --menu "Quelle documentation souhaitez-vous consulter ?" 20 70 12 \
        "README.md" "Présentation globale (Racine du projet)" \
        "${MENU_OPTIONS[@]}" 3>&1 1>&2 2>&3)
    
    if [ $? -eq 0 ]; then
        if [ "$DOC_CHOICE" == "README.md" ]; then
            whiptail --title "Documentation : README principal" --textbox "$README_FILE" 24 80 --scrolltext
        else
            # 🔧 LA MODIFICATION EST ICI : On ajoute le préfixe "README_"
            DOC_FILE="README_${DOC_CHOICE%.sh}.md"
            DOC_URL="$REPO_URL/documentation/$DOC_FILE"
            
            # On télécharge le fichier doc temporairement
            curl -s "$DOC_URL" -o "/tmp/$DOC_FILE"
            
            # On vérifie si le fichier existe bien sur GitHub (pas d'erreur 404)
            if grep -q "404: Not Found" "/tmp/$DOC_FILE" || [ ! -s "/tmp/$DOC_FILE" ]; then
                whiptail --title "Erreur 404" --msgbox "La documentation '$DOC_FILE' est introuvable dans le dossier 'documentation/' sur votre GitHub.\nAvez-vous bien nommé le fichier ?" 10 60
            else
                whiptail --title "Documentation : $DOC_FILE" --textbox "/tmp/$DOC_FILE" 24 80 --scrolltext
            fi
        fi
    fi
}

# ---------------------------------------------------------
# 🚀 BOUCLE DU MENU PRINCIPAL
# ---------------------------------------------------------
while true; do
    MAIN_CHOICE=$(whiptail --title "🛠️  Boîte à outils DevOps - Valentin Prades" \
        --menu "Que souhaitez-vous faire sur ce serveur vierge ?" 18 70 5 \
        "1" "📦 Installer un service" \
        "2" "📖 Lire la documentation" \
        "3" "🚪 Quitter" 3>&1 1>&2 2>&3)

    # Si l'utilisateur clique sur Annuler, Echap, ou Quitter (Choix 3)
    if [ $? -ne 0 ] || [ "$MAIN_CHOICE" == "3" ]; then
        clear
        echo "👋 Fermeture de la boîte à outils. À bientôt !"
        exit 0
    fi

    case $MAIN_CHOICE in
        1)
            # Sous-menu d'installation
            SCRIPT_CHOICE=$(whiptail --title "📦 Installation de service" --menu "Sélectionnez le service à déployer sur cette machine :" 22 76 10 "${MENU_OPTIONS[@]}" 3>&1 1>&2 2>&3)
            
            if [ $? -eq 0 ] && [ -n "$SCRIPT_CHOICE" ]; then
                clear
                echo "📥 Téléchargement et lancement de $SCRIPT_CHOICE..."
                # On télécharge et on exécute
                curl -sO "$REPO_URL/$SCRIPT_CHOICE"
                chmod +x "$SCRIPT_CHOICE"
                bash "$SCRIPT_CHOICE"
                
                # Pause à la fin de l'installation avant de réafficher le menu
                echo -e "\n=========================================================="
                read -p "👉 Appuyez sur [ENTRÉE] pour retourner au menu principal..."
            fi
            ;;
        2)
            lire_doc
            ;;
    esac
done
