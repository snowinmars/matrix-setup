sed -i 's/registration_shared_secret:.*/registration_shared_secret: REMOVED FROM GIT/g' ./synapse/homeserver.yaml
sed -i 's/macaroon_secret_key:.*/macaroon_secret_key: REMOVED FROM GIT/g'               ./synapse/homeserver.yaml
sed -i 's/form_secret:.*/form_secret: REMOVED FROM GIT/g'                               ./synapse/homeserver.yaml
