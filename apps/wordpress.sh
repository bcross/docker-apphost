#!/bin/bash
if [ $EUID -ne 0 ]; then
    echo "Run this script with elevated privileges."
    exit 2
fi

#Script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#Variables
WORDPRESS_DOMAIN=wp.example.com
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

echo "------------------"
echo "|Wordpress script|"
echo "------------------"

#Create folders
echo "Creating data folder"
mkdir $DATA_ROOT/wordpress -p

#Add nginx vhost
echo "Adding nginx vhost"
cat > /opt/nginx/vhosts/wordpress.conf <<EOL
server {
  listen 0.0.0.0:8443;
  port_in_redirect off;
  ssl_certificate /bitnami/certs/letsencrypt/$WORDPRESS_DOMAIN/fullchain.pem;
  ssl_certificate_key /bitnami/certs/letsencrypt/$WORDPRESS_DOMAIN/privkey.pem;
  server_name $WORDPRESS_DOMAIN;
  location / {
    proxy_set_header X-Forwarded-For \$remote_addr;
    proxy_set_header Host \$host;
    resolver 127.0.0.11;
    set \$wordpress wordpress;
    proxy_pass https://\$wordpress:443;
  }
}
EOL

#Create certs with certbot
echo "Creating certs with certbot"
certbot certonly --webroot --email $CERTBOT_EMAIL --agree-tos -w /opt/certbot/www -d $WORDPRESS_DOMAIN &> /dev/null
if [ $? != 0 ]; then
  echo "Cert creation with certbot failed. Defaulting to self-signed."
  sed -i "s|ssl_certificate .*|ssl_certificate /bitnami/certs/nginx.crt;|" /opt/nginx/vhosts/wordpress.conf
  sed -i "s|ssl_certificate_key .*|ssl_certificate_key /bitnami/certs/nginx.key;|" /opt/nginx/vhosts/wordpress.conf
fi

echo "Copying docker compose file"
cp -r $DIR/../composefiles/wordpress /opt/docker/composefiles

#Modify compose file with data root
echo "Updating data locations in docker compose file"
sed -i "s|wordpress_data:/bitnami|$DATA_ROOT/wordpress/wordpress_data:/bitnami|" /opt/docker/composefiles/wordpress/docker-compose.yml
sed -i "s|mariadb_data:/bitnami|$DATA_ROOT/wordpress/mariadb_data:/bitnami|" /opt/docker/composefiles/wordpress/docker-compose.yml