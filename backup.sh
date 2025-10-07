#!/bin/bash

ARG_DB_PASS="$1"
if [ -z "$ARG_DB_PASS" ]; then
    echo "Utilisation: $0 <mot_de_passe_bdd>"
    exit 1
fi


# === CONFIGURATION ===
BACKUP_DIR="backSakup"
DB_USER="alain"                   # Ton user MySQL
DB_PASS="$ARG_DB_PASS"       # Ton mot de passe MySQL
DB_NAME="Sakup"             # Nom de ta base PrestaShop
PS_DIR="/var/www/html/Sakup" # Répertoire de PrestaShop

# Serveur distant (si tu veux envoyer les backups ailleurs)
REMOTE_USER="alain"
REMOTE_HOST="87.106.123.58"
REMOTE_DIR="/home/alain/backupSakup"

# === CRÉATION DU DOSSIER DE BACKUP ===
mkdir -p $BACKUP_DIR/Sakup

# Sauvegarde base MySQL
mysqldump -u $DB_USER -p$DB_PASS $DB_NAME | gzip > $BACKUP_DIR/Sakup/sakup_database.sql.gz

# Sauvegarde images
tar -czf $BACKUP_DIR/Sakup/sakup_images.tar.gz -C $PS_DIR img

# Sauvegarde thème
tar -czf $BACKUP_DIR/Sakup/sakup_themes.tar.gz -C $PS_DIR themes

# Sauvegarde modules
tar -czf $BACKUP_DIR/Sakup/sakup_modules.tar.gz -C $PS_DIR modules

# Sauvegarde fichiers de configuration
tar -czf $BACKUP_DIR/Sakup/sakup_config.tar.gz -C $PS_DIR config app/config

# Sauvegarde fichiers uploadés
tar -czf $BACKUP_DIR/Sakup/sakup_uploads.tar.gz -C $PS_DIR upload

# Sauvegarde fichiers de traduction
tar -czf $BACKUP_DIR/Sakup/sakup_translations.tar.gz -C $PS_DIR translations

# Sauvegarde fichiers de configuration serveur
tar -czf $BACKUP_DIR/Sakup/sakup_server_config.tar.gz -C $PS_DIR .htaccess robots.txt

# === ENVOI SUR SERVEUR DISTANT ===
# Créer le dossier distant s'il n'existe pas
ssh -i ~/.ssh/backup_key $REMOTE_USER@$REMOTE_HOST "mkdir -p $REMOTE_DIR"
# Envoyer les fichiers
rsync -avz -e "ssh -i ~/.ssh/backup_key" $BACKUP_DIR/ $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/

# === NETTOYAGE LOCAL (supprimer anciens fichiers de backup) ===
# Les fichiers sont automatiquement écrasés à chaque sauvegarde
# Pas besoin de nettoyage local

# === NETTOYAGE DISTANT (supprimer anciens fichiers de backup) ===
# Les fichiers sont automatiquement écrasés à chaque sauvegarde
# Pas besoin de nettoyage distant
