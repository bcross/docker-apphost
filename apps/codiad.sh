#!/bin/bash
if [ $EUID -ne 0 ]; then
    echo "Run this script with elevated privileges."
    exit 2
fi

#Script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#Variables
CODIAD_DOMAIN=codiad.example.com
CERTBOT_EMAIL=example@example.com
DATA_ROOT=/media/data

#Run docker, certbot, and nginx if not configured already
if [ ! -f "/opt/certbot/configured" ]; then
  echo "Certbot not configured"
  $DIR/../setup/certbot.sh
fi
if [ ! -f "/opt/nginx/configured" ]; then
  echo "Nginx not configured"
  $DIR/../setup/nginx.sh
fi
if [ ! -f "/opt/docker/configured" ]; then
  echo "Docker not configured"
  $DIR/../setup/docker.sh
fi

echo "---------------"
echo "|Codiad script|"
echo "---------------"

#Create folders and copy files
echo "Creating data folder"
mkdir $DATA_ROOT/codiad -p
echo "Copying app files"
cp -r $DIR/../appfiles/codiad/* $DATA_ROOT/codiad 


#Add nginx vhost
echo "Adding nginx vhost"
cat > /opt/nginx/vhosts/codiad.conf <<EOL
server {
  listen 0.0.0.0:8443;
  port_in_redirect off;
  ssl_certificate /bitnami/certs/letsencrypt/$CODIAD_DOMAIN/fullchain.pem;
  ssl_certificate_key /bitnami/certs/letsencrypt/$CODIAD_DOMAIN/privkey.pem;
  server_name $CODIAD_DOMAIN;
  location / {
    proxy_set_header X-Forwarded-For \$remote_addr;
    proxy_set_header Host \$host;
    resolver 127.0.0.11;
    set \$codiad codiad;
    proxy_pass http://\$codiad:80;
  }
}
EOL

#Create certs with certbot
echo "Creating certs with certbot"
certbot certonly --webroot --email $CERTBOT_EMAIL --agree-tos -w /opt/certbot/www -d $CODIAD_DOMAIN &> /dev/null
if [ $? != 0 ]; then
  echo "Cert creation with certbot failed. Defaulting to self-signed."
  sed -i "s|ssl_certificate .*|ssl_certificate /bitnami/certs/nginx.crt;|" /opt/nginx/vhosts/codiad.conf
  sed -i "s|ssl_certificate_key .*|ssl_certificate_key /bitnami/certs/nginx.key;|" /opt/nginx/vhosts/codiad.conf
fi

echo "Copying docker compose file"
cp -r $DIR/../composefiles/codiad /opt/docker/composefiles

#Modify compose file with data root
echo "Updating data locations in docker compose file"
sed -i "s|codiad_data:/bitnami|$DATA_ROOT/codiad/codiad_data:/bitnami|" /opt/docker/composefiles/codiad/docker-compose.yml
sed -i "s|codiad_themes:/opt/bitnami/codiad/themes|$DATA_ROOT/codiad/codiad_themes:/opt/bitnami/codiad/themes|" /opt/docker/composefiles/codiad/docker-compose.yml
sed -i "s|codiad_plugins:/opt/bitnami/codiad/plugins|$DATA_ROOT/codiad/codiad_plugins:/opt/bitnami/codiad/plugins|" /opt/docker/composefiles/codiad/docker-compose.yml