# AWS 3-Tier CI/CD Pipeline (Laravel)

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Jenkins](https://img.shields.io/badge/jenkins-%232C5263.svg?style=for-the-badge&logo=jenkins&logoColor=white)
![Laravel](https://img.shields.io/badge/laravel-%23FF2D20.svg?style=for-the-badge&logo=laravel&logoColor=white)
![MySQL](https://img.shields.io/badge/mysql-4479A1.svg?style=for-the-badge&logo=mysql&logoColor=white)

An enterprise-grade, fully automated 3-tier web application deployment on Amazon Web Services. This project demonstrates advanced cloud infrastructure provisioning, Linux systems administration, and secure Continuous Integration / Continuous Deployment (CI/CD) mechanics.

## 🏗️ Architecture

This project strictly adheres to a decoupled 3-tier architecture:
1. **Compute Tier (EC2):** Ubuntu 24.04 server running Nginx as a reverse proxy, routing traffic to a PHP 8.3-FPM socket.
2. **Database Tier (RDS):** A private AWS RDS MySQL 8 instance, secured via VPC Security Groups, accessible only by the Compute Tier.
3. **Storage Tier (S3):** An Amazon S3 bucket for object storage, accessed securely via EC2 IAM Roles (`AmazonS3FullAccess`) rather than hardcoded environment credentials.

## ⚙️ CI/CD Pipeline

Deployment is fully automated using a self-hosted **Jenkins** engine operating directly on the deployment target, orchestrated via a Declarative `Jenkinsfile`.

**Pipeline Flow:**
1. **Trigger:** GitHub webhook fires on `main` branch push.
2. **Source Control:** Jenkins pulls the latest repository state.
3. **Build:** Executes `composer install --no-dev` to resolve PHP/Laravel dependencies.
4. **Deploy:** Synchronizes the Jenkins workspace with the `/var/www/laravel` web root.
5. **Configure:** Mechanically injects `laravel.conf` into `/etc/nginx/sites-available` and manages symbolic links.
6. **Daemon Management:** Restores strict `www-data` filesystem ownership and recycles the `nginx` and `php8.3-fpm` systemd services to serve the updated application cache.

## 🔒 Security Posture

*   **Network Isolation:** RDS is provisioned without public IP addresses. Inbound Port 3306 TCP traffic is explicitly whitelisted to the `Laravel-Web-SG` security group.
*   **IAM Integration:** Application utilizes the AWS SDK in tandem with an EC2 Instance Profile (IAM Role) to authenticate with S3, completely eliminating hardcoded AWS keys.
*   **Mechanical Sudoers:** The CI/CD pipeline executes via the `jenkins` Linux user, configured with explicit `NOPASSWD` sudo clearance in `/etc/sudoers.d` to restart required daemons securely.

## 🛠️ Infrastructure Mechanics
*   **Memory Management:** Implements a 2GB Virtual Swap Space (`/swapfile`) to prevent OOM Kernel panics during concurrent JVM and PHP compilation tasks on `t3.micro` instances.
*   **Runtime:** Upgraded default Ubuntu PHP 8.2 engine to PHP 8.3 to satisfy Laravel 13 requirements.

## 🚀 Deployment Instructions
This repository contains the `Jenkinsfile` required for deployment. Ensure the target EC2 instance has Jenkins, Nginx, PHP 8.3, and Composer installed, and that the `jenkins` user has appropriate sudo permissions.
