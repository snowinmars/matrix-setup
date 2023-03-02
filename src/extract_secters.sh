SECRETS_BACKUP='./extracted.secrets'

rm -f $SECRETS_BACKUP

# FILE=./element/config.json
# echo '# $FILE' >> $SECRETS_BACKUP
# cat $FILE | grep base_url >> $SECRETS_BACKUP
# cat $FILE | grep server_name >> $SECRETS_BACKUP
# echo >> $SECRETS_BACKUP

# sed -i 's/base_url:.*/base_url: $ELEMENT_CONFIG_BASE_URL/g'          $FILE
# sed -i 's/server_name:.*/server_name: $ELEMENT_CONFIG_SERVER_NAME/g' $FILE

##########################

FILE=./synapse/homeserver.yaml
echo '# $FILE' >> $SECRETS_BACKUP
cat $FILE | grep server_name                 >> $SECRETS_BACKUP
cat $FILE | grep database                    >> $SECRETS_BACKUP
cat $FILE | grep user                        >> $SECRETS_BACKUP
cat $FILE | grep password                    >> $SECRETS_BACKUP
cat $FILE | grep host                        >> $SECRETS_BACKUP
cat $FILE | grep registration_shared_secret  >> $SECRETS_BACKUP
cat $FILE | grep macaroon_secret_key         >> $SECRETS_BACKUP
cat $FILE | grep form_secret                 >> $SECRETS_BACKUP
echo >> $SECRETS_BACKUP

sed -i 's/server_name:.*/server_name: $SYNAPSE_HOMESERVER_SERVER_NAME/g'                                              $FILE
sed -i 's/registration_shared_secret:.*/registration_shared_secret: $SYNAPSE_HOMESERVER_REGISTRATION_SHARED_SECRET/g' $FILE
sed -i 's/macaroon_secret_key:.*/macaroon_secret_key: $SYNAPSE_HOMESERVER_MACAROON_SECRET_KEY/g'                      $FILE
sed -i 's/form_secret:.*/form_secret: $SYNAPSE_HOMESERVER_FORM_SECRET/g'                                              $FILE

##########################

FILE=./mautrix-telegram/config.yaml
echo '# $FILE' >> $SECRETS_BACKUP
cat $FILE | grep shared_secret          >> $SECRETS_BACKUP
cat $FILE | grep as_token               >> $SECRETS_BACKUP
cat $FILE | grep hs_token               >> $SECRETS_BACKUP
cat $FILE | grep api_id                 >> $SECRETS_BACKUP
cat $FILE | grep api_hash               >> $SECRETS_BACKUP
echo >> $SECRETS_BACKUP

sed -i 's/shared_secret:.*/shared_secret: $MAUTRIX_TELEGRAM_CONFIG_SHARED_SECRET/g' $FILE
sed -i 's/as_token:.*/as_token: $MAUTRIX_TELEGRAM_CONFIG_AS_TOKEN/g'                $FILE
sed -i 's/hs_token:.*/hs_token: $MAUTRIX_TELEGRAM_CONFIG_HS_TOKEN/g'                $FILE
sed -i 's/api_id:.*/api_id: $MAUTRIX_TELEGRAM_CONFIG_API_ID/g'                      $FILE
sed -i 's/api_hash:.*/api_hash: $MAUTRIX_TELEGRAM_CONFIG_API_HASH/g'                $FILE

##########################

FILE=./mautrix-telegram/registration.yaml
echo '# $FILE' >> $SECRETS_BACKUP
cat $FILE | grep as_token         >> $SECRETS_BACKUP
cat $FILE | grep hs_token         >> $SECRETS_BACKUP
cat $FILE | grep sender_localpart >> $SECRETS_BACKUP
echo >> $SECRETS_BACKUP

sed -i 's/as_token:.*/as_token: $MAUTRIX_TELEGRAM_REGISTRATION_AS_TOKEN/g'                         $FILE
sed -i 's/hs_token:.*/hs_token: $MAUTRIX_TELEGRAM_REGISTRATION_HS_TOKEN/g'                         $FILE
sed -i 's/sender_localpart:.*/sender_localpart: $MAUTRIX_TELEGRAM_REGISTRATION_SENDER_LOCALPART/g' $FILE

##########################
