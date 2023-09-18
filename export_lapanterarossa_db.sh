#!/bin/bash
# Load variables from .env file
source .env
#VARIABLES

declare -A DIRS=(
    ["$LOCAL_PATH/web/libraries"]="$REMOTE_PATH/web"
    ["$LOCAL_PATH/web/themes/custom/$THEME_NAME"]="$REMOTE_PATH/web/themes/custom"
    ["$LOCAL_PATH/web/modules"]="$REMOTE_PATH/web"
    ["$LOCAL_PATH/vendor"]="$REMOTE_PATH"
    ["$LOCAL_PATH/web/sites/default/files"]="$REMOTE_PATH/web/sites/default"
)

#Localcal MySQL Variables
SSH_DB_PATH="$REMOTE_PATH/db/"
SSH_UPSTREAM_PATH="$SSH_DB_PATH/upstream/"
SSH_DOWNSTREAM_PATH="$SSH_DB_PATH/downstream/"

#Dump file parameters
LOCAL_BACKUP_PATH="$LOCAL_PATH/db"

# 1. Dump the remote specified tables
REMOTE_DUMP_NAME="remote_extract_$(date +'%d_%m_%Y_%H%M').sql"
ssh $SSH_USER@$SSH_SERVER <<EOF
    mysqldump -u $REMOTE_DB_USER -p$REMOTE_DB_PASS -h $REMOTE_DB_HOST $REMOTE_DB_NAME commerce_order commerce_order_item commerce_order_item__adjustments commerce_order__adjustments commerce_order__coupons commerce_order__order_items users users_data users_field_data user__roles> $SSH_DOWNSTREAM_PATH/$REMOTE_DUMP_NAME
EOF

# 2. Download the remote extract to local environment
rsync -avz $SSH_USER@$SSH_SERVER:$SSH_DOWNSTREAM_PATH/$REMOTE_DUMP_NAME $LOCAL_BACKUP_PATH/

# 3. Insert the downloaded tables' data into your local database
mysql $LOCAL_DB_NAME < $LOCAL_BACKUP_PATH/$REMOTE_DUMP_NAME

# 4. Dump and sync your entire local database (now with downloaded tables) to the remote
FILENAME="$LOCAL_DB_NAME"_"$(date +'%d_%m_%Y_%H%M').sql"

# Dump the database
mysqldump $LOCAL_DB_NAME > $LOCAL_BACKUP_PATH/$FILENAME
echo "DB saved at $LOCAL_BACKUP_PATH/$FILENAME"

# Sync the dump file to the remote server
rsync -avz $LOCAL_BACKUP_PATH/$FILENAME $SSH_USER@$SSH_SERVER:$SSH_UPSTREAM_PATH

# Connect to remote server and create the database if it doesn't exist, then import the dump
ssh $SSH_USER@$SSH_SERVER <<EOF
    LATEST_DUMP=\$(ls -Art $SSH_UPSTREAM_PATH | tail -n 1)
    echo "We are updating the database on the remote server: $LATEST_DUMP"
    mysql -u $REMOTE_DB_USER -p$REMOTE_DB_PASS -h $REMOTE_DB_HOST -e "CREATE DATABASE IF NOT EXISTS $REMOTE_DB_NAME;"
    mysql -u $REMOTE_DB_USER -p$REMOTE_DB_PASS -h $REMOTE_DB_HOST $REMOTE_DB_NAME < $SSH_UPSTREAM_PATH/\$LATEST_DUMP
EOF


# Iterate over source directories and rsync each to the corresponding remote destination
for local_dir in "${!DIRS[@]}"; do
  remote_dir=${DIRS[$local_dir]}
  echo "This is the $local_dir that copies to the $remote_dir"
  rsync -avzu $local_dir $SSH_USER@$SSH_SERVER:$remote_dir
done
