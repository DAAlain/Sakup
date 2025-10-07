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
  $BACKUP_DIR/ $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/

# === NETTOYAGE LOCAL (supprimer anciens fichiers de backup) ===
# Les fichiers sont automatiquement écrasés à chaque sauvegarde
# Pas besoin de nettoyage local

# === NETTOYAGE DISTANT (supprimer anciens fichiers de backup) ===
# Les fichiers sont automatiquement écrasés à chaque sauvegarde
# Pas besoin de nettoyage distant
