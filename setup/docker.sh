#!/bin/bash
if [ $EUID -ne 0 ]; then
    echo "Run this script with elevated privileges."
    exit 2
fi

#Script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "---------------"
echo "|Docker script|"
echo "---------------"
#Install docker
dpkg -s docker-ce &> /dev/null
while [ $? != 0 ]; do
echo "Docker not installed"

#Install docker prereqs
echo "Installing docker prereqs"
apt-get update &> /dev/null
apt-get -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common &> /dev/null

#Add docker repo
echo "Adding docker repo"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - &> /dev/null
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable" &> /dev/null
apt-get update &> /dev/null
echo "Installing docker"
apt-get -y install docker-ce &> /dev/null
dpkg -s docker-ce &> /dev/null
if [ $? != 0 ]; then
   echo "Failed. Trying again."
   false
fi
done
#Install docker-compose. Make sure version is latest.
while [ ! -f "/usr/local/bin/docker-compose" ]; do
  echo "Installing docker compose"
  curl -s -S -L https://github.com/docker/compose/releases/download/1.16.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
done
chmod +x /usr/local/bin/docker-compose

#Create folder
mkdir /opt/docker/composefiles -p

#Configure cron
echo "Creating docker startup script and adding it to cron"
crontab -l > ~/crontemp 2> /dev/null
if [ $? != 0 ]; then
  touch ~/crontemp
fi
echo "@reboot /opt/docker/dockerstartup.sh" >> ~/crontemp
crontab ~/crontemp &> /dev/null
rm ~/crontemp

#Create docker startup script
cat > /opt/docker/dockerstartup.sh <<'EOL'
#!/bin/bash
for file in $(find /opt/docker/composefiles -iname '*.yml'); do
app=$(basename $(dirname $file))
counter=0
false
while [ $? != 0 -a $counter -le 5 ]; do (($counter++)); sleep 2; /usr/local/bin/docker-compose -f $file up -d; done &
done
EOL
chmod +x /opt/docker/dockerstartup.sh

ip=$(ip addr | grep enp0 | grep inet | sed 's/.*inet \(.*\)\/[0-9]\{2\} brd.*/\1/')

echo "Initializing docker swarm"
docker swarm init --advertise-addr $ip &> /dev/null

echo "Creating docker overlay network app"
docker network create -d overlay --attachable app &> /dev/null

touch /opt/docker/configured