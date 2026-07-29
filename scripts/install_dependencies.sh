#!/bin/bash
# install_dependencies.sh

# Update apt cache and install Nginx, PHP 8.2, and required extensions
apt-get update -y
apt-get install -y nginx software-properties-common curl zip unzip

# Ensure PHP repository is added (Ubuntu 22.04 default has 8.1, but we might want 8.2)
add-apt-repository ppa:ondrej/php -y
apt-get update -y
apt-get install -y php8.2-fpm php8.2-cli php8.2-mysql php8.2-xml php8.2-curl php8.2-mbstring php8.2-zip

# Ensure the systemd services are enabled to start on boot
systemctl enable nginx
systemctl enable php8.2-fpm
