#!/bin/bash
# Script Maître de Déploiement - Interface Whiptail dynamique
# Parse automatiquement le README.md depuis GitHub

if [ "$EUID" -ne 0 ]; then
  exec sudo bash "$0" "$@"
  exit $?
fi

# ---------------------------------------------------------
# 📦 DÉPENDANCES ET TÉLÉCHARGEMENT
# ---------------------------------------------------------
apt-get update -qq && apt-get install -y -qq whiptail curl grep sed

REPO_URL="https://raw.githubusercontent.com/valentinprades/scripts-deploiement-debian/main"
README_FILE="/tmp/main_readme.md"

curl -s "$REPO_URL/README.md" -o "$README_FILE"

# Vérification si le dépôt est introuvable ou privé
if grep -q "404: Not Found" "$README_FILE"; then
    whiptail --title "Erreur Critique" --msgbox "❌ Impossible de lire le README.md.\nVérifiez que votre dépôt GitHub est bien PUBLIC et que la branche s'appelle bien 'main'." 10 70
    clear
    exit 1
fi

# ---------------------------------------------------------
# 🔍 ANALYSE DYNAMIQUE DU README (Lecture assouplie)
# ---------------------------------------------------------
declare -a MENU_OPTIONS

# On lit les lignes commençant par "### " suivi d'un chiffre
while read -r line; do
    # On extrait n'importe quel mot se terminant par .sh
    SCRIPT_FILE=$(echo "$line" | grep -oE '[a-zA-Z0-9_-]+\.sh' | head -n 1)
    # On extrait le texte descriptif en nettoyant le début et la fin
    DESC=$(echo "$line" | sed -E 's/^###[ \t]*[0-9]+\.[ \t]*//; s/[ \t]*\(.*//')
    
    if [ -n "$SCRIPT_FILE" ] && [ -n "$DESC" ]; then
        MENU_OPTIONS+=("$SCRIPT_FILE" "$DESC")
    fi
done < <(grep -E "^###[ \t]*[0-9]+\." "$README_FILE")

# SÉCURITÉ : Si la liste est vide après l'analyse
if [ ${#MENU_OPTIONS[@]} -eq 0 ]; then
    whiptail --title "Menu Vide" --msgbox "⚠️ Aucun script n'a été détecté dans le README.md.\nAssurez-vous que vos lignes respectent le format :\n### 1. Nom du service (script.sh)" 12 70
    clear
    exit 1
fi

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
            DOC_FILE="README_${DOC_CHOICE%.sh}.md"
            DOC_URL="$REPO_URL/documentation/$DOC_FILE"
            
            curl -s "$DOC_URL" -o "/tmp/$DOC_FILE"
            
            if grep -q "404: Not Found" "/tmp/$DOC_FILE" || [ ! -s "/tmp/$DOC_FILE" ]; then
                whiptail --title "Erreur 404" --msgbox "La documentation '$DOC_FILE' est introuvable dans le dossier 'documentation/' sur votre GitHub." 10 60
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

    if [ $? -ne 0 ] || [ "$MAIN_CHOICE" == "3" ]; then
        clear
        echo "👋 Fermeture de la boîte à outils. À bientôt !"
        exit 0
    fi

    case $MAIN_CHOICE in
        1)
            SCRIPT_CHOICE=$(whiptail --title "📦 Installation de service" --menu "Sélectionnez le service à déployer :" 22 76 10 "${MENU_OPTIONS[@]}" 3>&1 1>&2 2>&3)
            
            if [ $? -eq 0 ] && [ -n "$SCRIPT_CHOICE" ]; then
                clear
                echo "📥 Lancement de $SCRIPT_CHOICE..."
                curl -sO "$REPO_URL/$SCRIPT_CHOICE"
                chmod +x "$SCRIPT_CHOICE"
                bash "$SCRIPT_CHOICE"
                
                echo -e "\n=========================================================="
                read -p "👉 Appuyez sur [ENTRÉE] pour retourner au menu principal..."
            fi
            ;;
        2)
            lire_doc
            ;;
    esac
done
