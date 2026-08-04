#!/bin/bash
# =============================================================================
#  EC2 Bootstrap Script — Node.js Assessment App
#  Run once on a fresh Ubuntu 22.04 EC2 instance as: sudo bash setup_ec2.sh
# =============================================================================
set -e

echo "================================================================"
echo "  Step 0: System Update & Swap File (prevents OOM on t3.micro)"
echo "================================================================"
apt-get update -y && apt-get upgrade -y

if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo "Swap file created."
fi

echo ""
echo "================================================================"
echo "  Step 1: Install Node.js 20 LTS"
echo "================================================================"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
node -v && npm -v

echo ""
echo "================================================================"
echo "  Step 2: Install PM2 (Process Manager)"
echo "================================================================"
npm install -g pm2
pm2 startup systemd -u ubuntu --hp /home/ubuntu

echo ""
echo "================================================================"
echo "  Step 3: Install Nginx"
echo "================================================================"
apt-get install -y nginx
systemctl enable nginx

echo ""
echo "================================================================"
echo "  Step 4: Install Java 21 (Jenkins Requirement)"
echo "================================================================"
apt-get install -y openjdk-21-jre-headless
update-alternatives --set java /usr/lib/jvm/java-21-openjdk-amd64/bin/java
java -version

echo ""
echo "================================================================"
echo "  Step 5: Install Jenkins"
echo "================================================================"
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
    gpg --dearmor -o /usr/share/keyrings/jenkins-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] \
    https://pkg.jenkins.io/debian-stable binary/" | \
    tee /etc/apt/sources.list.d/jenkins.list > /dev/null

apt-get update -y
apt-get install -y jenkins

systemctl enable jenkins
systemctl start jenkins

echo "Waiting for Jenkins to start..."
sleep 15
systemctl status jenkins --no-pager

echo ""
echo "================================================================"
echo "  Step 6: Allow Jenkins to deploy without password prompts"
echo "================================================================"
cat > /etc/sudoers.d/jenkins << 'EOF'
jenkins ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/jenkins

echo ""
echo "================================================================"
echo "  Step 7: Create App Directory & Set Permissions"
echo "================================================================"
mkdir -p /var/www/node-app
chown jenkins:jenkins /var/www/node-app

echo ""
echo "================================================================"
echo "  Step 8: Install mysql-client (for RDS verification)"
echo "================================================================"
apt-get install -y mysql-client

echo ""
echo "================================================================"
echo "  Step 9: Install AWS CLI v2"
echo "================================================================"
apt-get install -y unzip curl
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
aws --version

echo ""
echo "================================================================"
echo "  DONE! Summary:"
echo "================================================================"
echo ""
echo "  Node.js:   $(node -v)"
echo "  NPM:       $(npm -v)"
echo "  PM2:       $(pm2 -v)"
echo "  Java:      $(java -version 2>&1 | head -n1)"
echo "  Nginx:     $(nginx -v 2>&1)"
echo "  Jenkins:   http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo ""
echo "  Jenkins Initial Admin Password:"
cat /var/lib/jenkins/secrets/initialAdminPassword
echo ""
echo "  Next Steps:"
echo "  1. Open port 8080 in your EC2 Security Group for Jenkins UI."
echo "  2. Configure the Jenkins pipeline using the Jenkinsfile in the repo."
echo "  3. Set up a GitHub Webhook pointing to:"
echo "     http://<EC2-PUBLIC-IP>:8080/github-webhook/"
echo "  4. Apply your domain name in nginx.conf and reload nginx."
