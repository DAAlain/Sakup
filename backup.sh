#!/bin/bash

ARG_DB_PASS="$1"
ARG_REMOTE_PASS="$2"
if [ -z "$ARG_DB_PASS" ] || [ -z "$ARG_REMOTE_PASS" ]; then
    echo "Utilisation: $0 <mot_de_passe_bdd> <mot_de_passe_remote>"
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

# Nombre de backups à conserver
KEEP_BACKUPS=7

# === CRÉATION DU DOSSIER DE BACKUP AVEC TIMESTAMP ===
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_NAME="backup_${TIMESTAMP}"
mkdir -p $BACKUP_DIR/$BACKUP_NAME/Sakup

# Sauvegarde base MySQL
mysqldump -u $DB_USER -p$DB_PASS $DB_NAME | gzip > $BACKUP_DIR/$BACKUP_NAME/Sakup/sakup_database.sql.gz

# Sauvegarde images
tar -czf $BACKUP_DIR/$BACKUP_NAME/Sakup/sakup_images.tar.gz -C $PS_DIR img

# Sauvegarde thème
tar -czf $BACKUP_DIR/$BACKUP_NAME/Sakup/sakup_themes.tar.gz -C $PS_DIR themes

# Sauvegarde modules
tar -czf $BACKUP_DIR/$BACKUP_NAME/Sakup/sakup_modules.tar.gz -C $PS_DIR modules

# Sauvegarde fichiers de configuration
tar -czf $BACKUP_DIR/$BACKUP_NAME/Sakup/sakup_config.tar.gz -C $PS_DIR config app/config

# Sauvegarde fichiers uploadés
tar -czf $BACKUP_DIR/$BACKUP_NAME/Sakup/sakup_uploads.tar.gz -C $PS_DIR upload

# Sauvegarde fichiers de traduction
tar -czf $BACKUP_DIR/$BACKUP_NAME/Sakup/sakup_translations.tar.gz -C $PS_DIR translations

# Sauvegarde dossier override
tar -czf $BACKUP_DIR/$BACKUP_NAME/Sakup/sakup_override.tar.gz -C $PS_DIR override

# Sauvegarde fichiers de configuration serveur
tar -czf $BACKUP_DIR/$BACKUP_NAME/Sakup/sakup_server_config.tar.gz -C $PS_DIR .htaccess robots.txt

# Sauvegarde dossier classes
tar -czf $BACKUP_DIR/$BACKUP_NAME/Sakup/sakup_classes.tar.gz -C $PS_DIR classes

# Sauvegarde dossier controllers
tar -czf $BACKUP_DIR/$BACKUP_NAME/Sakup/sakup_controllers.tar.gz -C $PS_DIR controllers

# Sauvegarde fichiers de configuration PHP essentiels
tar -czf $BACKUP_DIR/$BACKUP_NAME/Sakup/sakup_php_config.tar.gz -C $PS_DIR autoload.php

# Sauvegarde dossier vendor (dépendances Composer)
tar -czf $BACKUP_DIR/$BACKUP_NAME/Sakup/sakup_vendor.tar.gz -C $PS_DIR vendor

# Sauvegarde fichiers Composer
tar -czf $BACKUP_DIR/$BACKUP_NAME/Sakup/sakup_composer.tar.gz -C $PS_DIR composer.json composer.lock 2>/dev/null || true

# Sauvegarde templates emails
tar -czf $BACKUP_DIR/$BACKUP_NAME/Sakup/sakup_mails.tar.gz -C $PS_DIR mails

# Sauvegarde templates PDF
tar -czf $BACKUP_DIR/$BACKUP_NAME/Sakup/sakup_pdf.tar.gz -C $PS_DIR pdf

# Sauvegarde dossier var (cache et logs)
tar -czf $BACKUP_DIR/$BACKUP_NAME/Sakup/sakup_var.tar.gz -C $PS_DIR var



# === ENVOI SUR SERVEUR DISTANT ===
# Vérification de la connexion SSH avant l'envoi
echo "Vérification de la connexion SSH au serveur distant (auth par mot de passe)..."
if sshpass -p "$ARG_REMOTE_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=10 $REMOTE_USER@$REMOTE_HOST "echo 'Connexion SSH réussie'" 2>/dev/null; then
    echo "Connexion SSH établie avec succès !"
else
    echo "ERREUR: Impossible de se connecter au serveur distant $REMOTE_HOST avec le mot de passe fourni"
    echo "Vérifiez que :"
    echo "1. Le mot de passe distant est correct"
    echo "2. L'utilisateur $REMOTE_USER a accès au serveur"
    echo "3. Le serveur $REMOTE_HOST est accessible"
    exit 1
fi

# Créer le dossier distant s'il n'existe pas
sshpass -p "$ARG_REMOTE_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no $REMOTE_USER@$REMOTE_HOST "mkdir -p $REMOTE_DIR"

# Envoyer les fichiers avec rsync sur SSH + mot de passe
echo "Début de l'envoi des fichiers de backup..."
sshpass -p "$ARG_REMOTE_PASS" rsync -avz --progress \
  -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no" \
  $BACKUP_DIR/$BACKUP_NAME/ $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/$BACKUP_NAME/

# === NETTOYAGE DISTANT (rotation des backups - garder seulement les 7 plus récents) ===
echo "Nettoyage des anciens backups sur le serveur distant..."
KEEP_PLUS_ONE=$((KEEP_BACKUPS + 1))
sshpass -p "$ARG_REMOTE_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no $REMOTE_USER@$REMOTE_HOST "
    cd $REMOTE_DIR
    # Compter le nombre de dossiers backup_*
    BACKUP_COUNT=\$(ls -d backup_* 2>/dev/null | wc -l)
    if [ \$BACKUP_COUNT -gt $KEEP_BACKUPS ]; then
        echo \"Il y a \$BACKUP_COUNT backups, on garde seulement les $KEEP_BACKUPS plus récents\"
        # Lister les dossiers triés par date (plus récent en premier) et supprimer les plus anciens
        ls -dt backup_* | tail -n +$KEEP_PLUS_ONE | while read old_backup; do
            echo \"Suppression de l'ancien backup: \$old_backup\"
            rm -rf \"\$old_backup\"
        done
        echo \"Nettoyage terminé\"
    else
        echo \"Il y a \$BACKUP_COUNT backups, pas de nettoyage nécessaire (limite: $KEEP_BACKUPS)\"
    fi
"

# === NETTOYAGE LOCAL ===
# Supprimer le dossier de backup local après l'envoi
echo "Suppression du dossier de backup local..."
rm -rf $BACKUP_DIR/$BACKUP_NAME
echo "Backup terminé avec succès !"
