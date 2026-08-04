#!/bin/bash
# =============================================================================
#  EC2 #2 — JENKINS SERVER SETUP (new EC2)
#  Installs: Java 21, Jenkins only
#  Run once: sudo bash setup_jenkins_server.sh
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

echo "=== Java 21 (Jenkins requirement) ==="
apt-get install -y openjdk-21-jre-headless
update-alternatives --set java /usr/lib/jvm/java-21-openjdk-amd64/bin/java
java -version

echo "=== Jenkins ==="
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
    gpg --dearmor -o /usr/share/keyrings/jenkins-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] \
    https://pkg.jenkins.io/debian-stable binary/" | \
    tee /etc/apt/sources.list.d/jenkins.list > /dev/null

apt-get update -y && apt-get install -y jenkins
systemctl enable jenkins && systemctl start jenkins

echo "=== Generate SSH key for Jenkins to deploy to App EC2 ==="
# Jenkins will use this key to SSH into the App EC2 (13.60.82.64)
if [ ! -f /var/lib/jenkins/.ssh/id_rsa ]; then
    mkdir -p /var/lib/jenkins/.ssh
    ssh-keygen -t rsa -b 4096 -f /var/lib/jenkins/.ssh/id_rsa -N ""
    chown -R jenkins:jenkins /var/lib/jenkins/.ssh
    chmod 700 /var/lib/jenkins/.ssh
    chmod 600 /var/lib/jenkins/.ssh/id_rsa
fi

echo ""
echo "=== Jenkins Server Ready ==="
echo "  Jenkins UI : http://<THIS-EC2-IP>:8080"
echo ""
echo "  Initial Admin Password:"
cat /var/lib/jenkins/secrets/initialAdminPassword
echo ""
echo "  !! IMPORTANT — Copy this public key to App EC2 authorized_keys:"
echo ""
cat /var/lib/jenkins/.ssh/id_rsa.pub
echo ""
echo "  On App EC2 (13.61.174.62) run:"
echo "  echo '<above-key>' >> /home/ubuntu/.ssh/authorized_keys"
