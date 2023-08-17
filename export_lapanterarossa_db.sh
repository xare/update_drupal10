#!/bin/bash
# Load variables from .env file
source .env
#VARIABLES

declare -A DIRS=(
    ["$LOCAL_PATH/web/libraries"]="$REMOTE_PATH/web"
    ["$LOCAL_PATH/web/themes/custom/lapanterarossa"]="$REMOTE_PATH/web/themes/custom"
    ["$LOCAL_PATH/web/modules"]="$REMOTE_PATH/web"
    ["$LOCAL_PATH/vendor"]="$REMOTE_PATH"
    ["$LOCAL_PATH/web/sites/default/files"]="$REMOTE_PATH/web/sites/default"
)

#Localcal MySQL Variables
SSH_DB_PATH="$REMOTE_PATH/db/"

#Dump file parameters
LOCAL_BACKUP_PATH="$LOCAL_PATH/db"
FILENAME="lapanterarrossa_$(date +'%d_%m_%Y_%H%M').sql"

# Dump the database
mysqldump $LOCAL_DB_NAME > $LOCAL_BACKUP_PATH/$FILENAME

echo "DB saved at $LOCAL_BACKUP_PATH/$FILENAME"

# Sync the dump file to the remote server
rsync -avz $LOCAL_BACKUP_PATH/$FILENAME $SSH_USER@$SSH_SERVER:$SSH_DB_PATH

# Connect to remote server and create the database if it doesn't exist, then import the dump
ssh $SSH_USER@$SSH_SERVER <<EOF
    LATEST_DUMP=\$(ls -Art $SSH_DB_PATH | tail -n 1)
    echo "We are updating the database on the remote server"
    mysql -u $REMOTE_DB_USER -p$REMOTE_DB_PASS -h $REMOTE_DB_HOST -e "CREATE DATABASE IF NOT EXISTS $REMOTE_DB_NAME;"
    mysql -u $REMOTE_DB_USER -p$REMOTE_DB_PASS -h $REMOTE_DB_HOST $REMOTE_DB_NAME < $SSH_DB_PATH/\$LATEST_DUMP
EOF


# Iterate over source directories and rsync each to the corresponding remote destination
for local_dir in "${!DIRS[@]}"; do
  remote_dir=${DIRS[$local_dir]}
  echo "This is the $local_dir that copies to the $remote_dir"
  rsync -avzu $local_dir $SSH_USER@$SSH_SERVER:$remote_dir
done
