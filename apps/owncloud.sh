#!/bin/bash
if [ $EUID -ne 0 ]; then
    echo "Run this script with elevated privileges."
    exit 2
fi

#Script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#Variables
OWNCLOUD_DOMAIN=files.example.com
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

echo "-----------------"
echo "|Owncloud script|"
echo "-----------------"

#Create folders
echo "Creating data and script folders"
mkdir /opt/owncloud/scripts -p
mkdir $DATA_ROOT/owncloud -p

echo "Creating Owncloud scripts and adding them to cron"
#Configure cron
crontab -l > ~/crontemp 2> /dev/null
if [ $? != 0 ]; then
  touch ~/crontemp
fi
echo "*/30 * * * * /opt/owncloud/scripts/syncusers.sh" >> ~/crontemp
echo "*/15 * * * * /opt/owncloud/scripts/cron.sh" >> ~/crontemp
crontab ~/crontemp
rm ~/crontemp

#Create OwnCloud scripts
cat > /opt/owncloud/scripts/syncusers.sh <<EOL
#!/bin/bash
docker exec owncloud_owncloud_1 bash -c 'sudo -u daemon /opt/bitnami/owncloud/occ user:sync "OCA\User_LDAP\User_Proxy" -m "disable"'
EOL
chmod +x /opt/owncloud/scripts/syncusers.sh
cat > /opt/owncloud/scripts/cron.sh <<EOL
#!/bin/bash
docker exec owncloud_owncloud_1 bash -c 'sudo -u daemon /opt/bitnami/php/bin/php -f /opt/bitnami/owncloud/cron.php'
EOL
chmod +x /opt/owncloud/scripts/cron.sh

#Add nginx vhost
echo "Adding nginx vhost"
cat > /opt/nginx/vhosts/owncloud.conf <<EOL
server {
  listen 0.0.0.0:8443;
  port_in_redirect off;
  ssl_certificate /bitnami/certs/letsencrypt/$OWNCLOUD_DOMAIN/fullchain.pem;
  ssl_certificate_key /bitnami/certs/letsencrypt/$OWNCLOUD_DOMAIN/privkey.pem;
  server_name $OWNCLOUD_DOMAIN;
  location / {
    client_max_body_size 16384m;
    proxy_buffering off;
    proxy_set_header X-Forwarded-For \$remote_addr;
    proxy_set_header Host \$host;
    resolver 127.0.0.11;
    set \$owncloud owncloud;
    proxy_pass http://\$owncloud:80;
  }
}
EOL

#Create certs with certbot
echo "Creating certs with certbot"
certbot certonly --webroot --email $CERTBOT_EMAIL --agree-tos -w /opt/certbot/www -d $OWNCLOUD_DOMAIN &> /dev/null
if [ $? != 0 ]; then
  echo "Cert creation with certbot failed. Defaulting to self-signed."
  sed -i "s|ssl_certificate .*|ssl_certificate /bitnami/certs/nginx.crt;|" /opt/nginx/vhosts/owncloud.conf
  sed -i "s|ssl_certificate_key .*|ssl_certificate_key /bitnami/certs/nginx.key;|" /opt/nginx/vhosts/owncloud.conf
fi

echo "Copying docker compose file"
cp -r $DIR/../composefiles/owncloud /opt/docker/composefiles

#Modify compose file with domain and data root
echo "Updating data locations in docker compose file"
sed -i "s/localhost/$OWNCLOUD_DOMAIN/" /opt/docker/composefiles/owncloud/docker-compose.yml
sed -i "s|owncloud_data:/bitnami|$DATA_ROOT/owncloud/owncloud_data:/bitnami|" /opt/docker/composefiles/owncloud/docker-compose.yml
sed -i "s|mariadb_data:/bitnami|$DATA_ROOT/owncloud/mariadb_data:/bitnami|" /opt/docker/composefiles/owncloud/docker-compose.yml

#Start OwnCloud and wait for it to initialize
echo "Starting Owncloud"
false
while [ $? != 0 ]; do 
  sleep 2
  docker-compose -f "/opt/docker/composefiles/owncloud/docker-compose.yml" up -d &> /dev/null
done

echo "Started. Waiting..."
while [ ! -f $DATA_ROOT/owncloud/owncloud_data/apache/conf/vhosts/htaccess/owncloud-htaccess.conf ]; do
  sleep 5
done
sleep 10

#Edit OwnCloud config to allow large files
echo "Modifying OwnCloud config"
sed -i 's/php_value upload_max_filesize .*/php_value upload_max_filesize 16384M/' $DATA_ROOT/owncloud/owncloud_data/apache/conf/vhosts/htaccess/owncloud-htaccess.conf
sed -i 's/php_value post_max_size .*/php_value post_max_size 16384M/' $DATA_ROOT/owncloud/owncloud_data/apache/conf/vhosts/htaccess/owncloud-htaccess.conf
bash -c "echo upload_tmp_dir = \'/opt/bitnami/php/temp\' >> $DATA_ROOT/owncloud/owncloud_data/php/conf/php.ini"
mkdir $DATA_ROOT/owncloud/owncloud_data/php/temp

echo "Stopping Owncloud"
docker-compose  -f "/opt/docker/composefiles/owncloud/docker-compose.yml" stop &> /dev/null

