#!/bin/bash
if [ $EUID -ne 0 ]; then
    echo "Run this script with elevated privileges."
    exit 2
fi

#Script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#Run nginx script if not configured already
if [ ! -f "/opt/nginx/configured" ]; then
  echo "Nginx not configured"
  $DIR/nginx.sh
fi

echo "----------------"
echo "|Certbot script|"
echo "----------------"

#Install certbot
dpkg -s certbot &> /dev/null
while [ $? != 0 ]; do
echo "Installing certbot"
{
  #Add certbot repo
  add-apt-repository -y ppa:certbot/certbot

  #Update apt
  apt-get update

  apt-get -y install certbot
  dpkg -s certbot
} &> /dev/null
done

#Create folder
echo "Creating domain validation folder"
mkdir /opt/certbot/www -p

#Configure cron
echo "Adding certbot to cron"
crontab -l > ~/crontemp 2> /dev/null
if [ $? != 0 ]; then
  touch ~/crontemp
fi
echo "1 0 * * * certbot renew" >> ~/crontemp
crontab ~/crontemp
rm ~/crontemp

#Add nginx vhost
echo "Adding nginx vhost"
cat > /opt/nginx/vhosts/certbot.conf <<EOL
server {
  listen 0.0.0.0:8080;
  port_in_redirect off;
  location /.well-known/acme-challenge/ {
    root /app;
  }
  location / {
    return 301 https://\$host\$request_uri;
  }
}
EOL

touch /opt/certbot/configured