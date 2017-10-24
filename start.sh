#!/bin/bash
if [ $EUID -ne 0 ]; then
    echo "Run this script with elevated privileges."
    exit 2
fi

#Script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "--------------"
echo "|Start script|"
echo "--------------"

find $DIR -type f -name "*.sh" -exec chmod +x {} \;

for script in $(find $DIR/apps -iname '*.sh' | sort); do
    "$script"
done
$DIR/setup/ufw.sh
rm -rf $DIR