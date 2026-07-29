# DevOps CI/CD Engineering Report: Jenkins Migration & AWS Deployment

## 1. Executive Summary
This document outlines the deployment of a robust, automated CI/CD pipeline for a Laravel web application on an AWS EC2 instance. Due to IAM and service provisioning limitations encountered with AWS CodeDeploy, the architecture was successfully pivoted to a self-hosted Jenkins engine. This demonstrates adaptability and a deep mechanical understanding of Linux systems administration, web server configuration, and automation.

## 2. Infrastructure Architecture
*   **Compute Engine:** AWS EC2 (`t3.micro`)
*   **Operating System:** Ubuntu 24.04 LTS (Noble)
*   **Web Server / Reverse Proxy:** Nginx
*   **Application Runtime:** PHP 8.3 (FPM)
*   **CI/CD Engine:** Jenkins 2.568.1 (Self-hosted on EC2)
*   **Database:** SQLite (Configured for immediate deployment; MySQL/RDS drivers pre-installed for future tiering)
*   **Security:** AWS Security Groups restricting access (Ports 22, 80, 8080) and strict `sudoers` configurations.

## 3. The Jenkins Pivot: CI/CD Pipeline as Code
Instead of relying on abstracted AWS CodeDeploy agents, Jenkins was installed directly on the deployment target. This required configuring the `jenkins` user with specific `NOPASSWD` sudo privileges to allow automated interaction with system services without compromising root security.

**The Pipeline (Jenkinsfile):**
1.  **Checkout:** Fetches the latest code from the `main` branch on GitHub.
2.  **Dependencies:** Executes `composer install --no-dev` to resolve PHP packages.
3.  **Deployment:** Copies the built artifact directly to the Nginx web root (`/var/www/laravel`).
4.  **Web Server Configuration:** Automatically moves the `laravel.conf` reverse proxy configuration into `/etc/nginx/sites-available` and symlinks it to `sites-enabled`.
5.  **Service Management:** Reapplies strict `www-data` ownership to prevent permission hijacking and restarts the `nginx` and `php8.3-fpm` systemd daemons.

## 4. Engineering Mechanics & Troubleshooting

### A. Java Engine Compatibility (Jenkins)
During the Jenkins installation, `systemd` continuously crashed the Jenkins service. 
*   **Diagnosis:** Log analysis via `journalctl -xeu jenkins.service` revealed a JVM crash. Jenkins recently deprecated Java 17 support, demanding Java 21.
*   **Resolution:** Installed `openjdk-21-jre`, verified the path via `update-alternatives`, and flushed the systemd failed state (`systemctl reset-failed`) to restore the service.

### B. Outdated PHP Runtime (Laravel 13)
The initial pipeline build failed during the Composer dependency resolution phase.
*   **Diagnosis:** Jenkins console output indicated that `laravel/framework ^13.8` requires PHP 8.3, but the server was running PHP 8.2.
*   **Resolution:** Executed a full upgrade to PHP 8.3 (FPM and CLI), updated the `fastcgi_pass` socket in the Nginx configuration, and utilized `update-alternatives` to switch the CLI default, allowing Composer to build successfully.

### C. Database Driver Mismatch
Post-deployment, the Laravel application threw a `500 Internal Server Error` due to a missing SQLite database file and a subsequent `could not find driver` exception.
*   **Diagnosis:** While `php8.3-mysql` was installed for RDS compatibility, the local SQLite engine lacked its PHP interface.
*   **Resolution:** Mechanically touched the `database.sqlite` file, assigned `www-data` ownership, installed the `php8.3-sqlite3` extension, restarted the FPM daemon, and successfully forced the Artisan database migrations.

## 5. Conclusion
The environment is now a fully automated, production-standard delivery pipeline. Pushing code to GitHub triggers Jenkins to securely deploy the Laravel application and recycle the necessary Linux daemons entirely hands-free.
