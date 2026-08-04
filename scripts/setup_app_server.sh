#!/bin/bash
# =============================================================================
#  EC2 #1 — APP SERVER SETUP (13.60.82.64)
#  Installs: Node.js, PM2, Nginx
#  Run once: sudo bash setup_app_server.sh
# =============================================================================
set -e

echo "=== Swap File (2GB) ==="
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile && chmod 600 /swapfile
    mkswap /swapfile && swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "=== System Update ==="
apt-get update -y

echo "=== Node.js 20 LTS ==="
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
node -v && npm -v

echo "=== PM2 ==="
npm install -g pm2
pm2 startup systemd -u ubuntu --hp /home/ubuntu

echo "=== Nginx ==="
apt-get install -y nginx
systemctl enable nginx

echo "=== App directory ==="
mkdir -p /var/www/node-app
chown ubuntu:ubuntu /var/www/node-app

echo "=== AWS CLI v2 ==="
apt-get install -y unzip curl
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/install
aws --version

echo ""
echo "=== App Server Ready ==="
echo "  App directory : /var/www/node-app"
echo "  App URL       : http://13.61.174.62"
echo ""
echo "  NEXT: Add the Jenkins EC2's public key to:"
echo "  /home/ubuntu/.ssh/authorized_keys  (on THIS server: 13.61.174.62)"
echo "  so Jenkins can SSH in and deploy."
