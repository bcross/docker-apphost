#!/bin/bash
if [ $EUID -ne 0 ]; then
    echo "Run this script with elevated privileges."
    exit 2
fi

#Script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "-----------------"
echo "|Firewall script|"
echo "-----------------"

echo "Allowing SSH"
ufw allow 22 > /dev/null
echo "Allowing HTTP"
ufw allow 80 > /dev/null
echo "Allowing HTTPS"
ufw allow 443 > /dev/null
echo "Enabling UFW"
ufw --force enable
