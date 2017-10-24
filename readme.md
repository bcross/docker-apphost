# Setup
## Install
1. Download this repo to a folder. I have done all my testing in Ubuntu. It may also work in Debian. It will not work in a CentOS based distro (yet).
1. If you want to install all the apps, run start.sh. Otherwise, run one of the scripts in the apps folder. Either way, sudo or run as root.
1. Both options will install docker, docker compose, and certbot. Nginx and the selected app(s) will be deployed as a container.
1. If running start.sh, it will remove the folder.

## Configuration
Check each app script's variables section. Change as needed. The app will still install and run if you don't, but certbot will fail for sure.

For certbot to work you will need to forward ports, know your external IP, and change public DNS. If you know what all of that means, you already know how.

If you don't change the domain variable, change your hosts file to point the domain(s) of the app(s) to the right IP. The nginx reverse proxy works off of server name.

Each app has a basic configuration to make sure it works. Sometimes, this means the app is configured beyond just pulling from Docker Hub and running.