#!/bin/bash
if [ $EUID -ne 0 ]; then
    echo "Run this script with elevated privileges."
    exit 2
fi

#Script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#Run docker script if not configured already
if [ ! -f "/opt/docker/configured" ]; then
  echo "Docker not configured"
  $DIR/docker.sh
fi

echo "--------------"
echo "|Nginx script|"
echo "--------------"

#Create folders
echo "Creating folders"
mkdir /opt/nginx/vhosts -p
mkdir /opt/nginx/ssl -p

#Create self-signed certificate
echo "Creating self-signed certificate"
openssl req \
  -x509 \
  -nodes \
  -days 365 \
  -newkey rsa:2048 \
  -subj "/C=US/ST=NA/L=NA/O=NA/CN=*" \
  -keyout /opt/nginx/ssl/nginx.key \
  -out /opt/nginx/ssl/nginx.crt &> /dev/null

echo "Copying docker compose file"
cp -r $DIR/../composefiles/nginx /opt/docker/composefiles

touch /opt/nginx/configured