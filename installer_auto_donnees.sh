#!/bin/bash

# --- VARIABLES À PERSONNALISER ---
DOMAIN_NAME="Sakup" # Remplacez par votre nom de domaine ou adresse IP
DB_NAME="Sakup"      # Nom de la base de données existante
DB_USER="alain"    # Nom de l'utilisateur existant (avec tous les droits sur la DB)
DB_PASS="@NBG40709@" # Mot de passe de l'utilisateur existant

# Configuration pour la restauration des données depuis le second VPS
REMOTE_USER="alain"
REMOTE_HOST="87.106.123.58"
REMOTE_DIR="/home/alain/backupSakup"
BACKUP_DIR="backSakup"

# Détection automatique de l'adresse IP du VPS
VPS_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
echo "Adresse IP du VPS détectée : $VPS_IP"

# Informations pour l'installation automatique
ADMIN_EMAIL="aladrs2003@gmail.com"
ADMIN_PASSWORD="@NBG40709@"
SHOP_NAME="Sakup"
SHOP_COUNTRY="fr"
SHOP_TIMEZONE="Europe/Paris"

# --- Variables pour les utilisateurs ---
MAIN_USER="alain"
SFTP_USER="alainftp"
MAIN_USER_PASSWORD="@NBG40709@"
SFTP_USER_PASSWORD="@NBG40709@"
SFTP_HOME="/home/alainftp"
SFTP_CHROOT="/var/www/html"

# ------------------------------------
# --- VÉRIFICATION DES DÉPENDANCES ---
# ------------------------------------

echo "Vérification des dépendances nécessaires..."

# Mise à jour du système
apt update && apt upgrade -y

# --- Installation des dépendances ---
sudo apt install -y apache2 mariadb-server php php-mysql php-xml php-mbstring php-gd php-curl unzip wget phpmyadmin openssl
sudo apt-get install -y php-cli php-zip php-intl php-bcmath php-soap php-imagick php-json php-tokenizer php-memcached

# --- Activation des modules Apache ---
echo "Activation des modules Apache et mariadb nécessaires..."
sudo a2enmod rewrite ssl headers deflate expires
sudo a2ensite default-ssl
sudo systemctl restart apache2
sudo systemctl restart mariadb
echo "Activation des modules Apache et mariadb nécessaires terminée !"

# ---------------------------------
# --- CONFIGURATION DU Swapfile ---
# ---------------------------------

echo "Configuration du Swapfile..."

# --- Configuration default-ssl.conf ---
echo "<Directory /var/www/html>AllowOverride All</Directory>" >> /etc/apache2/sites-available/default-ssl.conf
sudo systemctl restart apache2

# --- Configuration du Swapfile ---
dd if=/dev/zero of=/swapfile1 bs=1024 count=1048576
chmod 600 /swapfile1
mkswap /swapfile1
swapon /swapfile1
echo "/swapfile1 none swap sw 0 0" >> /etc/fstab
echo "Configuration du Swapfile terminée !"

# ----------------------------
# --- CONFIGURATION DU PHP ---
# ----------------------------

echo "Configuration du PHP..."
sudo sed -i 's/max_input_vars = 1000/max_input_vars = 5000/' /etc/php/8.4/cli/php.ini
sudo sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/8.4/apache2/php.ini
sudo sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 128M/' /etc/php/8.4/apache2/php.ini
sudo sed -i 's/post_max_size = 8M/post_max_size = 128M/' /etc/php/8.4/apache2/php.ini
sudo systemctl restart apache2
echo "Configuration du PHP terminée !"

# ===============================================
# --- CRÉATION D'UTILISATEUR ET UTILISATEUR SFTP ---
# ===============================================

echo "Création des utilisateurs système et SFTP..."

# --- Création de l'utilisateur principal ---
echo "Création de l'utilisateur principal '$MAIN_USER'..."
if ! id "$MAIN_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$MAIN_USER"
    echo "$MAIN_USER:$MAIN_USER_PASSWORD" | chpasswd
    usermod -aG sudo "$MAIN_USER"
    echo "Utilisateur principal '$MAIN_USER' créé avec succès"
else
    echo "L'utilisateur '$MAIN_USER' existe déjà"
fi

# --- Création de l'utilisateur SFTP ---
echo "Création de l'utilisateur SFTP '$SFTP_USER'..."
if ! id "$SFTP_USER" &>/dev/null; then
    useradd -m -s /bin/false "$SFTP_USER"
    echo "$SFTP_USER:$SFTP_USER_PASSWORD" | chpasswd
    echo "Utilisateur SFTP '$SFTP_USER' créé avec succès"
else
    echo "L'utilisateur SFTP '$SFTP_USER' existe déjà"
fi

# --- Configuration du répertoire SFTP ---
echo "Configuration du répertoire SFTP..."
mkdir -p "$SFTP_CHROOT"
mkdir -p "$SFTP_CHROOT/upload"
mkdir -p "$SFTP_CHROOT/download"

# --- Attribution des permissions pour SFTP ---
chown root:root "$SFTP_CHROOT"
chmod 755 "$SFTP_CHROOT"
chown "$SFTP_USER:$SFTP_USER" "$SFTP_CHROOT/upload"
chown "$SFTP_USER:$SFTP_USER" "$SFTP_CHROOT/download"
chmod 755 "$SFTP_CHROOT/upload"
chmod 755 "$SFTP_CHROOT/download"

# --- Configuration SSH pour SFTP (chroot) ---
echo "Configuration SSH pour SFTP..."
if ! grep -q "Match User $SFTP_USER" /etc/ssh/sshd_config; then
    cat >> /etc/ssh/sshd_config << EOF

# Configuration SFTP pour $SFTP_USER
Match User $SFTP_USER
    ChrootDirectory $SFTP_CHROOT
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
EOF
    echo "Configuration SSH pour SFTP ajoutée"
else
    echo "Configuration SSH pour SFTP existe déjà"
fi

# --- Redémarrage du service SSH ---
systemctl restart sshd

echo "Configuration des utilisateurs terminée !"
echo "Utilisateur principal: $MAIN_USER (mot de passe: $MAIN_USER_PASSWORD)"
echo "Utilisateur SFTP: $SFTP_USER (mot de passe: $SFTP_USER_PASSWORD)"
echo "Répertoire SFTP: $SFTP_CHROOT"
echo "==============================================="


# --------------------------------------------------------
# --- TÉLÉCHARGEMENT ET INSTALLATION DE PRESTASHOP 9.0 ---
# --------------------------------------------------------

echo "Téléchargement et installation de PrestaShop 9.0..."

# --- Création du répertoire de destination ---
DEST_DIR="/var/www/html/$DOMAIN_NAME"
sudo mkdir -p "$DEST_DIR"
cd "$DEST_DIR"

# --- Téléchargement de l'archive de PrestaShop ---
echo "Téléchargement de PrestaShop..."
wget -O prestashop-installer.zip "https://assets.prestashop3.com/dst/edition/corporate/9.0.0-1.0/prestashop_edition_classic_version_9.0.0-1.0.zip?source=docker"

# --- Décompression de la première archive (fichiers d'installation) ---
echo "Décompression de la première archive (fichiers d'installation)..."
sudo unzip -q prestashop-installer.zip -d "$DEST_DIR"
sudo rm prestashop-installer.zip

# --- Diagnostic : afficher le contenu après la première extraction ---
echo "Contenu après la première extraction:"
ls -la "$DEST_DIR"

# --- Recherche et extraction du fichier prestashop.zip dans les fichiers d'installation ---
echo "Extraction du fichier prestashop.zip dans les fichiers d'installation..."
cd "$DEST_DIR"
sudo unzip -o -q prestashop.zip

# --- Diagnostic : afficher le contenu après la deuxième extraction ---
echo "Contenu après la deuxième extraction:"
ls -la "$DEST_DIR"

# --- Diagnostic : Fichiers PrestaShop extraits avec succès ! ---
echo "Fichiers PrestaShop extraits avec succès !"

# --- Ajustement des permissions pour le serveur web (optimisé) ---
echo "Réglage des permissions pour le serveur web..."
sudo chown -R www-data:www-data "$DEST_DIR"
# --- Optimisation : utilisation de chmod avec -R et -type pour plus de rapidité ---
sudo chmod -R 755 "$DEST_DIR"
sudo find "$DEST_DIR" -type f -print0 | sudo xargs -0 chmod 644

# --------------------------------------------------------
# --- CRÉATION DE LA BASE DE DONNÉES MYSQL ---
# --------------------------------------------------------

echo "Création de la base de données MySQL..."

# --- Création de la base de données et de l'utilisateur si nécessaire ---
echo "Création de la base de données '$DB_NAME'..."
sudo mysql -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;"
sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

echo "Création de l'utilisateur '$DB_USER' avec tous les droits sur la base '$DB_NAME'..."
sudo mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "Base de données '$DB_NAME' créée avec succès !"

# --------------------------------------------------------
# --- INSTALLATION AUTOMATIQUE VIA CLI PRESTASHOP ---
# --------------------------------------------------------

echo "Démarrage de l'installation automatique de PrestaShop..."

# --- Attendre que les services soient prêts ---
sleep 3

# --- Fonction pour effectuer l'installation automatique via CLI ---
install_prestashop_cli() {
    echo "Tentative d'installation via CLI..."
    
    # --- Vérifier si le CLI d'installation existe ---
    if [ -f "$DEST_DIR/install/index_cli.php" ]; then
        echo "Utilisation du CLI d'installation..."
        cd "$DEST_DIR"
        
        # --- Exécution de l'installation CLI avec l'URL correcte ---
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


# --- Tentative d'installation automatique ---
echo "Démarrage des tentatives d'installation automatique..."

# --- Essayer d'abord l'installation CLI ---
if install_prestashop_cli; then
    echo "Installation CLI réussie !"
else
    echo "Installation automatique échouée. Configuration manuelle nécessaire."
fi

# --- Nettoyage des fichiers temporaires ---
rm -f /tmp/auto_install.php
rm -f install_params_cli.php

# --- Suppression du dossier d'installation pour la sécurité ---
if [ -d "$DEST_DIR/install" ]; then
    echo "Suppression du dossier d'installation pour la sécurité..."
    sudo rm -rf "$DEST_DIR/install"
fi

# --- Redémarrage d'Apache pour s'assurer que tout fonctionne ---
sudo systemctl restart apache2

cd "$DEST_DIR"

# --- Renommage du dossier admin pour la sécurité ---
echo "Renommage du dossier admin pour la sécurité..."

# --- Recherche du dossier admin qui n'est pas admin-api ---
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

# ----------------------------------------------------------------
# --- RESTAURATION DES DONNÉES PRESTASHOP DEPUIS LE SECOND VPS ---
# ----------------------------------------------------------------

echo "----------------------------------------"
echo "Début de la restauration des données PrestaShop..."
echo "----------------------------------------"

# --- Création du dossier de backup local ---
mkdir -p $BACKUP_DIR

# --- Téléchargement des fichiers de backup depuis le serveur distant ---
echo "Téléchargement des fichiers de backup depuis le serveur distant..."

# --- Vérification de la connexion SSH avant le téléchargement ---
echo "Vérification de la connexion SSH au serveur distant..."
if ssh -i ~/.ssh/backup_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 $REMOTE_USER@$REMOTE_HOST "echo 'Connexion SSH réussie'" 2>/dev/null; then
    echo "Connexion SSH établie avec succès !"
else
    echo "ERREUR: Impossible de se connecter au serveur distant $REMOTE_HOST"
    echo "Vérifiez que :"
    echo "1. La clé SSH ~/.ssh/backup_key existe et est correcte"
    echo "2. L'utilisateur $REMOTE_USER a accès au serveur"
    echo "3. Le serveur $REMOTE_HOST est accessible"
    exit 1
fi

# --- Configuration automatique pour éviter les demandes d'interaction ---
export RSYNC_RSH="ssh -i ~/.ssh/backup_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
export RSYNC_PASSWORD="alainmmi"

# --- Téléchargement avec réponses automatiques ---
echo "Début du téléchargement des fichiers de backup..."
echo "yes" | rsync -avz --progress -e "ssh -i ~/.ssh/backup_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/ $BACKUP_DIR/

# --- Vérification que les fichiers de backup sont présents --- 
if [ ! -d "$BACKUP_DIR/Sakup" ]; then
    echo "ERREUR: Dossier de backup non trouvé. Vérifiez la connexion au serveur distant."
    exit 1
fi

echo "Fichiers de backup téléchargés avec succès !"

# --- RESTAURATION DE LA BASE DE DONNÉES ---
echo "Restauration de la base de données..."
if [ -f "$BACKUP_DIR/Sakup/sakup_database.sql.gz" ]; then
    echo "Restauration de la base de données depuis sakup_database.sql.gz..."
    gunzip -c "$BACKUP_DIR/Sakup/sakup_database.sql.gz" | mysql -u $DB_USER -p$DB_PASS $DB_NAME
    echo "Base de données restaurée avec succès !"
else
    echo "ATTENTION: Fichier de base de données non trouvé: sakup_database.sql.gz"
fi

# --- RESTAURATION DES IMAGES ---
echo "Restauration des images..."
if [ -f "$BACKUP_DIR/Sakup/sakup_images.tar.gz" ]; then
    echo "Restauration des images depuis sakup_images.tar.gz..."
    sudo tar -xzf "$BACKUP_DIR/Sakup/sakup_images.tar.gz" -C "$DEST_DIR"
    echo "Images restaurées avec succès !"
else
    echo "ATTENTION: Fichier d'images non trouvé: sakup_images.tar.gz"
fi

# --- RESTAURATION DES THÈMES ---
echo "Restauration des thèmes..."
if [ -f "$BACKUP_DIR/Sakup/sakup_themes.tar.gz" ]; then
    echo "Restauration des thèmes depuis sakup_themes.tar.gz..."
    sudo tar -xzf "$BACKUP_DIR/Sakup/sakup_themes.tar.gz" -C "$DEST_DIR"
    echo "Thèmes restaurés avec succès !"
else
    echo "ATTENTION: Fichier de thèmes non trouvé: sakup_themes.tar.gz"
fi

# --- RESTAURATION DES MODULES ---
echo "Restauration des modules..."
if [ -f "$BACKUP_DIR/Sakup/sakup_modules.tar.gz" ]; then
    echo "Restauration des modules depuis sakup_modules.tar.gz..."
    sudo tar -xzf "$BACKUP_DIR/Sakup/sakup_modules.tar.gz" -C "$DEST_DIR"
    echo "Modules restaurés avec succès !"
else
    echo "ATTENTION: Fichier de modules non trouvé: sakup_modules.tar.gz"
fi

# --- RESTAURATION DES FICHIERS DE CONFIGURATION ---
echo "Restauration des fichiers de configuration..."
if [ -f "$BACKUP_DIR/Sakup/sakup_config.tar.gz" ]; then
    echo "Restauration des fichiers de configuration depuis sakup_config.tar.gz..."
    sudo tar -xzf "$BACKUP_DIR/Sakup/sakup_config.tar.gz" -C "$DEST_DIR"
    echo "Fichiers de configuration restaurés avec succès !"
else
    echo "ATTENTION: Fichier de configuration non trouvé: sakup_config.tar.gz"
fi

# --- RESTAURATION DES FICHIERS UPLOADÉS ---
echo "Restauration des fichiers uploadés..."
if [ -f "$BACKUP_DIR/Sakup/sakup_uploads.tar.gz" ]; then
    echo "Restauration des fichiers uploadés depuis sakup_uploads.tar.gz..."
    sudo tar -xzf "$BACKUP_DIR/Sakup/sakup_uploads.tar.gz" -C "$DEST_DIR"
    echo "Fichiers uploadés restaurés avec succès !"
else
    echo "ATTENTION: Fichier d'uploads non trouvé: sakup_uploads.tar.gz"
fi

# --- RESTAURATION DES TRADUCTIONS ---
echo "Restauration des traductions..."
if [ -f "$BACKUP_DIR/Sakup/sakup_translations.tar.gz" ]; then
    echo "Restauration des traductions depuis sakup_translations.tar.gz..."
    sudo tar -xzf "$BACKUP_DIR/Sakup/sakup_translations.tar.gz" -C "$DEST_DIR"
    echo "Traductions restaurées avec succès !"
else
    echo "ATTENTION: Fichier de traductions non trouvé: sakup_translations.tar.gz"
fi

# --- RESTAURATION DE LA CONFIGURATION SERVEUR ---
echo "Restauration de la configuration serveur..."
if [ -f "$BACKUP_DIR/Sakup/sakup_server_config.tar.gz" ]; then
    echo "Restauration de la configuration serveur depuis sakup_server_config.tar.gz..."
    sudo tar -xzf "$BACKUP_DIR/Sakup/sakup_server_config.tar.gz" -C "$DEST_DIR"
    echo "Configuration serveur restaurée avec succès !"
else
    echo "ATTENTION: Fichier de configuration serveur non trouvé: sakup_server_config.tar.gz"
fi

# --- AJUSTEMENT DES PERMISSIONS APRÈS RESTAURATION ---
echo "Ajustement des permissions après restauration..."
sudo chown -R www-data:www-data "$DEST_DIR"
sudo chmod -R 755 "$DEST_DIR"
sudo find "$DEST_DIR" -type f -print0 | sudo xargs -0 chmod 644

# --- REDÉMARRAGE DES SERVICES ---
echo "Redémarrage des services..."
sudo systemctl restart apache2
sudo systemctl restart mariadb

# --- NETTOYAGE DES FICHIERS TEMPORAIRES ---
echo "Nettoyage des fichiers temporaires..."
rm -rf "$BACKUP_DIR"

# ---------------------
# --- FIN DU SCRIPT ---
# ---------------------

echo "----------------------------------------"
echo "Installation et restauration de PrestaShop terminées !"
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
echo "Toutes les données ont été restaurées depuis le serveur de backup !"
echo "----------------------------------------"
