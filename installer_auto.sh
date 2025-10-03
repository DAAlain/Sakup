#!/bin/bash

# --- VARIABLES À PERSONNALISER ---
DOMAIN_NAME="Sakup" # Remplacez par votre nom de domaine ou adresse IP
DB_NAME="Sakup"      # Nom de la base de données existante
DB_USER="alain"    # Nom de l'utilisateur existant (avec tous les droits sur la DB)
DB_PASS="@NBG40709@" # Mot de passe de l'utilisateur existant

# Détection automatique de l'adresse IP du VPS
VPS_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
echo "Adresse IP du VPS détectée : $VPS_IP"

# Informations pour l'installation automatique
ADMIN_EMAIL="aladrs2003@gmail.com"
ADMIN_PASSWORD="@NBG40709@"
SHOP_NAME="Sakup"
SHOP_COUNTRY="fr"
SHOP_TIMEZONE="Europe/Paris"

# --- VÉRIFICATION DES DÉPENDANCES ---
echo "Vérification des dépendances nécessaires..."

# Mise à jour du système
apt update && apt upgrade -y

# Installation des dépendances de base
sudo apt install -y apache2 mariadb-server php php-mysql php-xml php-mbstring php-gd php-curl unzip wget phpmyadmin openssl pdo_mysql
sudo apt-get install -y php-cli php-zip php-intl php-bcmath php-soap php-imagick php-json php-tokenizer

# --- TÉLÉCHARGEMENT ET INSTALLATION DE PRESTASHOP 9.0 ---
echo "Téléchargement et installation de PrestaShop 9.0..."

# Création du répertoire de destination
DEST_DIR="/var/www/html/$DOMAIN_NAME"
sudo mkdir -p "$DEST_DIR"
cd "$DEST_DIR"

# Téléchargement de l'archive de PrestaShop
echo "Téléchargement de PrestaShop..."
wget -O prestashop-installer.zip "https://assets.prestashop3.com/dst/edition/corporate/9.0.0-1.0/prestashop_edition_classic_version_9.0.0-1.0.zip?source=docker"

# Décompression de la première archive (fichiers d'installation)
echo "Décompression de la première archive (fichiers d'installation)..."
sudo unzip -q prestashop-installer.zip -d "$DEST_DIR"
sudo rm prestashop-installer.zip

# Diagnostic : afficher le contenu après la première extraction
echo "Contenu après la première extraction:"
ls -la "$DEST_DIR"

# Recherche et extraction du fichier prestashop.zip dans les fichiers d'installation
echo "Extraction du fichier prestashop.zip dans les fichiers d'installation..."
cd "$DEST_DIR"
sudo unzip -o -q prestashop.zip

# Diagnostic : afficher le contenu après la deuxième extraction
echo "Contenu après la deuxième extraction:"
ls -la "$DEST_DIR"

# Diagnostic : Fichiers PrestaShop extraits avec succès !
echo "Fichiers PrestaShop extraits avec succès !"

# Ajustement des permissions pour le serveur web (optimisé)
echo "Réglage des permissions pour le serveur web..."
sudo chown -R www-data:www-data "$DEST_DIR"
# Optimisation : utilisation de chmod avec -R et -type pour plus de rapidité
sudo chmod -R 755 "$DEST_DIR"
sudo find "$DEST_DIR" -type f -print0 | sudo xargs -0 chmod 644

# --- CRÉATION DE LA BASE DE DONNÉES MYSQL ---
echo "Création de la base de données MySQL..."

# Création de la base de données et de l'utilisateur si nécessaire
echo "Création de la base de données '$DB_NAME'..."
sudo mysql -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;"
sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

echo "Création de l'utilisateur '$DB_USER' avec tous les droits sur la base '$DB_NAME'..."
sudo mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "Base de données '$DB_NAME' créée avec succès !"

# Activation des modules Apache nécessaires
echo "Activation des modules Apache nécessaires..."
sudo a2enmod rewrite ssl headers deflate expires
sudo systemctl restart apache2

# --- INSTALLATION AUTOMATIQUE VIA CLI PRESTASHOP ---
echo "Démarrage de l'installation automatique de PrestaShop..."

# Attendre que les services soient prêts
sleep 3

# Fonction pour effectuer l'installation automatique via CLI
install_prestashop_cli() {
    echo "Tentative d'installation via CLI..."
    
    # Vérifier si le CLI d'installation existe
    if [ -f "$DEST_DIR/install/index_cli.php" ]; then
        echo "Utilisation du CLI d'installation..."
        cd "$DEST_DIR"
        
        # Exécution de l'installation CLI avec l'URL correcte
        php ${DEST_DIR}/install/index_cli.php \
            --domain="$VPS_IP" \
            --base_uri="$DOMAIN_NAME" \
            --language="fr" \
            --db_server="localhost" \
            --db_name="$DB_NAME" \
            --db_user="$DB_USER" \
            --db_password="$DB_PASS" \
            --prefix="PrestSakup_" \
            --email="$ADMIN_EMAIL" \
            --password="$ADMIN_PASSWORD" \
            --country="$SHOP_COUNTRY" \
            --ssl=1 \
            --name="$SHOP_NAME" \
            --activity="general" \
            --timezone="$SHOP_TIMEZONE" \
            --firstname="Alain" \
            --lastname="DA-ROS" \
            --send_email="0"
        
        local install_result=$?
        if [ $install_result -eq 0 ]; then
            echo "Installation CLI réussie !"
            echo "Vérification de l'installation..."
            if [ -f "$DEST_DIR/app/config/parameters.php" ]; then
                echo "Fichier de configuration créé avec succès"
                return 0
            else
                echo "ATTENTION: Installation terminée mais fichier de configuration manquant"
                return 1
            fi
        else
            echo "Échec de l'installation CLI (code d'erreur: $install_result)"
            echo "Logs d'installation disponibles dans /tmp/prestashop_install.log"
            echo "Dernières lignes du log :"
            tail -20 /tmp/prestashop_install.log
            return 1
        fi
    else
        echo "CLI d'installation non trouvé."
        return 1
    fi
}


# Tentative d'installation automatique
echo "Démarrage des tentatives d'installation automatique..."

# Essayer d'abord l'installation CLI
if install_prestashop_cli; then
    echo "Installation CLI réussie !"
else
    echo "Installation automatique échouée. Configuration manuelle nécessaire."
fi

# Nettoyage des fichiers temporaires
rm -f /tmp/auto_install.php
rm -f install_params_cli.php

# Suppression du dossier d'installation pour la sécurité
if [ -d "$DEST_DIR/install" ]; then
    echo "Suppression du dossier d'installation pour la sécurité..."
    sudo rm -rf "$DEST_DIR/install"
fi

# Redémarrage d'Apache pour s'assurer que tout fonctionne
sudo systemctl restart apache2

cd "$DEST_DIR"

# Renommage du dossier admin pour la sécurité
echo "Renommage du dossier admin pour la sécurité..."

# Recherche du dossier admin qui n'est pas admin-api
ADMIN_DIR=$(find . -maxdepth 1 -type d -name "admin*" | grep -v "admin-api" | head -1)

if [ -n "$ADMIN_DIR" ]; then
    ADMIN_CURRENT_NAME=$(basename "$ADMIN_DIR")
    ADMIN_NEW_NAME="admin_Sak"
    sudo mv "$ADMIN_CURRENT_NAME" "$ADMIN_NEW_NAME"
    echo "Dossier '$ADMIN_CURRENT_NAME' renommé en: $ADMIN_NEW_NAME"
    echo "URL d'administration: http://$VPS_IP/$DOMAIN_NAME/$ADMIN_NEW_NAME"
else
    echo "Aucun dossier admin trouvé."
fi

# --- FIN DU SCRIPT ---s
echo "----------------------------------------"
echo "Installation automatique de PrestaShop terminée !"
echo "----------------------------------------"
echo "Votre boutique PrestaShop est maintenant accessible à :"
echo "Boutique : http://$VPS_IP/$DOMAIN_NAME"
echo "Administration : http://$VPS_IP/$DOMAIN_NAME/$ADMIN_NEW_NAME"
echo "" 
echo "Informations de connexion administrateur :"
echo "Email : $ADMIN_EMAIL"
echo "Mot de passe : $ADMIN_PASSWORD"
echo ""
echo "Informations de la base de données :"
echo "Nom de la base : $DB_NAME"
echo "Utilisateur : $DB_USER"
echo "Mot de passe : $DB_PASS"
echo "Serveur : localhost"
echo "----------------------------------------"
