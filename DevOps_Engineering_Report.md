# 🚀 Comprehensive DevOps Engineering & CI/CD Deployment Report

## 1. Executive Summary & The "Mechanical" Pivot
**Objective:** Deploy a modern, enterprise-grade 3-Tier Laravel application to AWS using a fully automated CI/CD pipeline, demonstrating mastery over cloud infrastructure, Linux administration, and network security.

**The Initial Plan vs. The Pivot:**
Initially, the architecture was designed to use AWS CodePipeline and AWS CodeDeploy. Configuration files like `appspec.yml`, `buildspec.yml`, and bash lifecycle scripts (`start_server.sh`, `install_dependencies.sh`) were explicitly written to handle this deployment flow. 

However, during infrastructure provisioning, strict AWS Free Tier account limitations explicitly blocked the creation of CodeDeploy applications. Instead of abandoning the automation requirement, we executed a **Senior DevOps Pivot**. We bypassed the abstracted AWS managed services and mechanically built a self-hosted **Jenkins CI/CD engine** directly on the EC2 target server. 

This approach required a significantly deeper understanding of underlying technologies: raw Linux systems administration, package management, JVM debugging, reverse proxy configuration (Nginx), and daemon management (`systemd`).

---

## 2. Phase 1: Architecture & Network Topology
We established a strict 3-tier architecture, physically decoupling the application layers to ensure security and scalability.

### A. Compute Tier (AWS EC2)
*   **Hardware:** Spun up an AWS EC2 `t3.micro` instance running Ubuntu 24.04 LTS (Noble) in the `eu-north-1` (Stockholm) region.
*   **Security Groups (Firewall):** We created a dedicated security group named `Laravel-Web-SG`. We applied the principle of least privilege, explicitly punching holes *only* for necessary traffic:
    *   `Port 22 (TCP)`: Locked down for secure, mechanical SSH administration.
    *   `Port 80 (TCP)`: Opened for public HTTP web traffic to hit the Nginx reverse proxy.
    *   `Port 8080 (TCP)`: Opened specifically to access the Jenkins CI/CD web dashboard.
*   **SSH Key Mechanics:** We encountered a classic Windows `UNPROTECTED PRIVATE KEY FILE` error because Windows inherits broad folder permissions by default. We used the Windows `icacls` command to mechanically strip inherited permissions and grant explicit, locked-down read-only access to `key.pem`, securing the SSH tunnel.

### B. Database Tier (AWS RDS MySQL)
*   **Hardware:** Provisioned a managed AWS RDS `db.t3.micro` instance running MySQL 8.
*   **Security Lockdown:** We ensured the RDS instance was **not publicly accessible**. We created a dedicated Security Group (`RDS-Laravel-SG`) and explicitly whitelisted inbound port 3306 TCP traffic *only* from the EC2 `Laravel-Web-SG` identifier. It is physically impossible to access this database from the outside internet.

### C. Object Storage Tier (AWS S3)
*   **Provisioning:** Created a secure Amazon S3 bucket (`laravel-app-storage-umair63`) with all public access strictly blocked.
*   **IAM Integration:** Hardcoding AWS access keys (`AWS_ACCESS_KEY_ID`) inside the application code is a massive security risk. Instead, we utilized an **EC2 IAM Role** (`EC2-CodeDeploy-Role`). We attached the `AmazonS3FullAccess` policy directly to the role, granting the EC2 server's virtual hardware inherent permission to interact with the bucket. Laravel uses the AWS SDK to seamlessly inherit these permissions, which is the enterprise gold standard for AWS security.

---

## 3. Phase 2: Linux Administration & Resource Management
A `t3.micro` instance only has 1GB of physical RAM. Running an Nginx web server, a PHP engine, and a Java-based Jenkins CI/CD server simultaneously will trigger the Linux Kernel's Out-Of-Memory (OOM) killer, which aggressively crashes processes to prevent system failure.

*   **The Engineering Fix:** We manually carved out a 2GB Swap file on the SSD to act as virtual memory.
    *   `sudo fallocate -l 2G /swapfile`: Allocated the block space.
    *   `sudo chmod 600 /swapfile`: Locked permissions so only root can access the memory pages.
    *   `sudo mkswap /swapfile` & `sudo swapon /swapfile`: Formatted and mounted the memory block.
    This mechanically prevented catastrophic crashes during heavy Jenkins and Composer builds.

---

## 4. Phase 3: The Jenkins CI/CD Engine & JVM Mechanics
Installing and configuring Jenkins required navigating complex package manager and Java runtime issues.

*   **Problem 1: GPG Key Mismatch:** The Jenkins repository threw a `NO_PUBKEY 7198F4B714ABFC68` error. We bypassed this by manually fetching the GPG key, exporting it into an armored format, and teeing it into `/usr/share/keyrings/jenkins-keyring.asc` to satisfy `apt` security requirements.
*   **Problem 2: JVM Crash:** After installation, `systemctl start jenkins` immediately crashed.
    *   *Diagnosis:* We read the raw daemon logs using `journalctl -xeu jenkins.service`. The logs revealed a JVM failure because Jenkins recently deprecated Java 17 and now strictly requires Java 21. 
    *   *Fix:* We installed `openjdk-21-jre`, used `update-alternatives --config java` to mechanically switch the default Linux Java engine, and ran `systemctl reset-failed jenkins` to clear the timeout lock before successfully restarting the daemon.
*   **Problem 3: Sudoers Configuration:** Jenkins runs under a restricted Linux user account (`jenkins`). By default, it lacks permissions to copy files into `/var/www` or restart the Nginx web server. 
    *   *Fix:* We manually edited the Linux `sudoers` configurations by creating `/etc/sudoers.d/jenkins` and injecting `jenkins ALL=(ALL) NOPASSWD: ALL`. This grants the Jenkins engine the exact clearance required to execute mechanical deployments without prompting for a human password.

---

## 5. Phase 4: Web Server & PHP Runtime Mismatch
Because we bypassed AWS CodeDeploy, the automated bash scripts we originally wrote to install the web server were never executed. We had to provision the stack manually via SSH.

*   **Stack Installation:** We installed `nginx`, `software-properties-common`, and `composer`.
*   **Problem 4: PHP Version Mismatch (Laravel 13):** During the first Jenkins Pipeline run, the build failed at the Composer stage.
    *   *Diagnosis:* The Jenkins console logs showed `laravel/framework ^13.8 requires php ^8.3`. Ubuntu 24.04 had installed PHP 8.2 by default.
    *   *Fix:* We SSH'd back in, added the `ondrej/php` PPA repository, and executed a full upgrade to PHP 8.3 (`php8.3-fpm`, `php8.3-cli`, `php8.3-xml`, etc.). 
    *   *Routing:* We then opened `/etc/nginx/sites-available/laravel.conf` and explicitly updated the `fastcgi_pass` directive to point to the new socket: `unix:/var/run/php/php8.3-fpm.sock`. Finally, we ran `sudo update-alternatives --set php /usr/bin/php8.3` to force the Composer CLI to use the new engine.

---

## 6. Phase 5: Pipeline as Code (Jenkinsfile Flow)
We authored a Declarative `Jenkinsfile` stored directly in GitHub to automate the entire deployment lifecycle. Every `git push` triggers this exact flow:
1.  **Checkout (`checkout scm`):** Jenkins pulls the latest code from the `main` branch on GitHub into its hidden workspace (`/var/lib/jenkins/workspace/laravel-deployment`).
2.  **Dependencies (`composer install`):** Executes `composer install --no-dev` to reliably resolve and download all PHP packages defined in `composer.lock`.
3.  **Deployment (`rsync / cp`):** Mechanically copies the built artifact directly from the Jenkins workspace into the live Nginx web root (`/var/www/laravel`).
4.  **Web Server Configuration:** Automatically moves the custom `laravel.conf` reverse proxy configuration into `/etc/nginx/sites-available`, symlinks it to `sites-enabled`, and deletes the default Nginx splash page.
5.  **Service Management (`systemctl`):** Reapplies strict `www-data` ownership to prevent permission hijacking, locks down the `storage` directory, and restarts the `nginx` and `php8.3-fpm` systemd daemons to flush the cache and serve the new code.

---

## 7. Phase 6: Finalizing the 3-Tier Integration
Once the application was deploying automatically, we connected the final two tiers.

*   **Database Integration:** We used the Linux `sed` command to mechanically inject the RDS Endpoint, Database Name, and strict credentials directly into the `/var/www/laravel/.env` file. We then authenticated into RDS via `mysql-client` to create the schema, and successfully ran `php artisan migrate:fresh --force` to build the tables.
*   **S3 Object Storage Driver:** We encountered a runtime error: `Class "League\Flysystem\AwsS3V3\PortableVisibilityConverter" not found`. This proved Laravel was trying to use S3, but lacked the AWS driver. We executed `composer require league/flysystem-aws-s3-v3`, tested the connection via `php artisan tinker` (`Storage::disk('s3')->put()`), and confirmed a successful upload using IAM role authentication. We then committed and pushed the updated `composer.json` and `composer.lock` files so Jenkins would install the AWS driver automatically on all future deployments.

---

## 8. Conclusion
We successfully delivered a highly robust, production-ready 3-tier environment. 

The application compute is fully decoupled from state (RDS) and storage (S3). Nginx is reverse-proxying traffic perfectly to the PHP 8.3 FPM socket, and every push to GitHub triggers an automated Jenkins pipeline that handles dependencies, permissions, and daemon recycling without human intervention. 

By manually resolving GPG keys, diagnosing JVM crashes via system logs, upgrading PHP sockets, and meticulously constructing a secure AWS VPC and IAM topology, this project thoroughly demonstrates deep technical ownership over enterprise Cloud DevOps mechanics.
