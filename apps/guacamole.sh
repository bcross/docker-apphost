#!/bin/bash
if [ $EUID -ne 0 ]; then
    echo "Run this script with elevated privileges."
    exit 2
fi

#Script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#Variables
GUACAMOLE_DOMAIN=guacamole.example.com
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
echo "|Guacamole script|"
echo "------------------"

#Create folder
echo "Creating data folder"
mkdir $DATA_ROOT/guacamole -p 


#Add nginx vhost
echo "Adding nginx vhost"
cat > /opt/nginx/vhosts/guacamole.conf <<EOL
server {
  listen 0.0.0.0:8443;
  port_in_redirect off;
  ssl_certificate /bitnami/certs/letsencrypt/$GUACAMOLE_DOMAIN/fullchain.pem;
  ssl_certificate_key /bitnami/certs/letsencrypt/$GUACAMOLE_DOMAIN/privkey.pem;
  server_name $GUACAMOLE_DOMAIN;
  location / {
    proxy_buffering off;
    proxy_http_version 1.1;
    proxy_set_header X-Forwarded-For \$remote_addr;
    proxy_set_header Host \$host;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$http_connection;
    proxy_cookie_path /guacamole/ /new-path/;
    resolver 127.0.0.11;
    set \$guacamole guacamole;
    proxy_pass http://\$guacamole:8080/guacamole\$uri\$is_args\$args;
  }
}
EOL

#Create certs with certbot
echo "Creating certs with certbot"
certbot certonly --webroot --email $CERTBOT_EMAIL --agree-tos -w /opt/certbot/www -d $GUACAMOLE_DOMAIN &> /dev/null
if [ $? != 0 ]; then
  echo "Cert creation with certbot failed. Defaulting to self-signed."
  sed -i "s|ssl_certificate .*|ssl_certificate /bitnami/certs/nginx.crt;|" /opt/nginx/vhosts/guacamole.conf
  sed -i "s|ssl_certificate_key .*|ssl_certificate_key /bitnami/certs/nginx.key;|" /opt/nginx/vhosts/guacamole.conf
fi

echo "Copying docker compose file"
cp -r $DIR/../composefiles/guacamole /opt/docker/composefiles

#Modify compose file with data root
echo "Updating data locations in docker compose file"
sed -i "s|guacamole_data:/guacamole|$DATA_ROOT/guacamole/guacamole_data:/guacamole|" /opt/docker/composefiles/guacamole/docker-compose.yml
sed -i "s|postgresql_data:/bitnami|$DATA_ROOT/guacamole/postgresql_data:/bitnami|" /opt/docker/composefiles/guacamole/docker-compose.yml

#Start guacamole
echo "Starting guacamole"
false
while [ $? != 0 ]; do 
  sleep 2
  docker-compose -f "/opt/docker/composefiles/guacamole/docker-compose.yml" up -d &> /dev/null
  docker-compose -f "/opt/docker/composefiles/guacamole/docker-compose.yml" up -d &> /dev/null
done

echo "Started. Waiting..."
while [ ! -f $DATA_ROOT/guacamole/postgresql_data/postgresql/data/postmaster.pid ]; do
  sleep 5
done
sleep 10

echo "Initializing PostgreSQL database"
docker exec guacamole_guacamole_1 /opt/guacamole/bin/initdb.sh --postgres > $DATA_ROOT/guacamole/postgresql_data/initdb.sql 
docker exec -e PGPASSWORD=$(grep -oP "(?<=POSTGRES_PASSWORD=).*" /opt/docker/composefiles/guacamole/docker-compose.yml) guacamole_postgresql_1 psql postgresql://postgres@localhost/guacamole_db -f /bitnami/initdb.sql &> /dev/null
rm $DATA_ROOT/guacamole/postgresql_data/initdb.sql