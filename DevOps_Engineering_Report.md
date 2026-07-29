# 🚀 Comprehensive DevOps Engineering & CI/CD Deployment Report

## 1. Project Overview & The "Mechanical" Pivot
**Objective:** Deploy a modern 3-Tier Laravel application to AWS using a fully automated CI/CD pipeline, demonstrating mastery over cloud infrastructure, Linux administration, and network security.

**The Initial Plan vs. The Pivot:**
Initially, the architecture was designed to use AWS CodePipeline and AWS CodeDeploy. Trust policies (`trust-policy.json`), `appspec.yml` lifecycle hooks, and bash scripts (`start_server.sh`, `install_dependencies.sh`) were explicitly written to handle this. 
However, due to strict AWS Free Tier account provisioning limitations that blocked the creation of CodeDeploy applications, we executed a **Senior DevOps Pivot**. We abandoned the managed AWS abstractions and mechanically built a self-hosted Jenkins CI/CD engine directly on the EC2 target server. This approach required a significantly deeper understanding of Linux systems, networking, and daemon management.

---

## 2. Phase 1: AWS Infrastructure Provisioning
We began by establishing the foundational cloud hardware and network security for the **Compute Tier**.

*   **Compute:** Launched an AWS EC2 `t3.micro` instance running Ubuntu 24.04 LTS (Noble) in the `eu-north-1` region.
*   **Security Groups (Firewall):** Created `Laravel-Web-SG` and explicitly punched holes for:
    *   `Port 22 (SSH)`: For mechanical server administration.
    *   `Port 80 (HTTP)`: For public web traffic to the Laravel application.
    *   `Port 8080 (Custom TCP)`: For accessing the Jenkins CI/CD web dashboard.
*   **SSH Key Mechanics:** Encountered the classic Windows `UNPROTECTED PRIVATE KEY FILE` error. We used Windows `icacls` to strip inherited permissions and grant explicit read-only access to `key.pem`, securing the SSH tunnel.

---

## 3. Phase 2: Linux Administration & Memory Management
A `t3.micro` instance only has 1GB of RAM. Running a web server, a PHP engine, and a Java-based Jenkins CI/CD server simultaneously will trigger the Linux Out-Of-Memory (OOM) killer.
*   **The Fix:** We manually carved out a 2GB Swap file on the SSD using `fallocate -l 2G /swapfile`, locked its permissions with `chmod 600`, formatted it with `mkswap`, and activated it with `swapon`. This provided the system with virtual memory, preventing catastrophic crashes during heavy Jenkins builds.

---

## 4. Phase 3: The Jenkins CI/CD Installation & Troubleshooting
Installing Jenkins required navigating complex package manager and runtime issues.

*   **Problem 1: GPG Key Mismatch:** The Jenkins repository threw a `NO_PUBKEY 7198F4B714ABFC68` error. We bypassed this by manually fetching the GPG key, exporting it into an armored format, and teeing it into `/usr/share/keyrings/jenkins-keyring.asc` to satisfy `apt` security requirements.
*   **Problem 2: JVM Crash & Java 21 Requirement:** After installation, `systemctl start jenkins` immediately crashed.
    *   *Diagnosis:* `journalctl -xeu jenkins.service` revealed that Jenkins recently deprecated Java 17 and now explicitly requires Java 21. 
    *   *Fix:* We installed `openjdk-21-jre`, used `update-alternatives --config java` to verify the default engine, and ran `systemctl reset-failed jenkins` to clear the timeout lock before successfully restarting the daemon.
*   **Sudoers Configuration:** Because Jenkins runs as the restricted `jenkins` user, it lacks permissions to deploy code to `/var/www` or restart Nginx. We mechanically injected `jenkins ALL=(ALL) NOPASSWD: ALL` into `/etc/sudoers.d/jenkins` to grant it pipeline execution rights.

---

## 5. Phase 4: Web Server & Engine Provisioning
Because we bypassed AWS CodeDeploy, the bash scripts we originally wrote to install the web server were never executed. We had to provision the stack manually via SSH.

*   **Stack Installation:** We installed `nginx`, `software-properties-common`, and `composer`.
*   **Problem 3: PHP Version Mismatch (Laravel 13):** During the first Jenkins Pipeline run, the build failed at the Composer stage.
    *   *Diagnosis:* The Jenkins logs showed `laravel/framework ^13.8 requires php ^8.3`. We had installed PHP 8.2.
    *   *Fix:* We SSH'd back in and executed a full upgrade to PHP 8.3 (`php8.3-fpm`, `php8.3-cli`, `php8.3-xml`, etc.). We then ran `sudo update-alternatives --set php /usr/bin/php8.3` to force Composer to use the new engine.

---

## 6. Phase 5: Pipeline as Code (Jenkinsfile)
We authored a Declarative `Jenkinsfile` stored directly in GitHub to automate the entire deployment lifecycle:
1.  **Checkout:** Pulls `main` branch from GitHub.
2.  **Install PHP Dependencies:** Runs `composer install --no-dev`.
3.  **Deploy Files:** Copies the Jenkins workspace into `/var/www/laravel`.
4.  **Configure Web Server:** Copies our custom `laravel.conf` into `/etc/nginx/sites-available`, symlinks it to `sites-enabled`, and deletes the default Nginx splash page. We explicitly updated `fastcgi_pass` to point to the new `unix:/var/run/php/php8.3-fpm.sock`.
5.  **Set Permissions & Restart Daemons:** Locks down directory ownership to `www-data`, ensures the `storage` and `bootstrap/cache` directories are writable, and restarts `nginx` and `php8.3-fpm`.

---

## 7. Phase 6: Completing the 3-Tier Architecture (RDS & S3)
To fully satisfy the enterprise 3-tier architecture requirements, we successfully decoupled the database and storage from the EC2 compute instance.

### A. Database Tier (AWS RDS MySQL)
*   **Provisioning:** Spun up an AWS RDS `db.t3.micro` instance running MySQL 8.
*   **Security:** Enforced strict firewall rules by ensuring the RDS instance was **not publicly accessible**. We created a dedicated Security Group (`RDS-Laravel-SG`) and explicitly whitelisted inbound port 3306 TCP traffic *only* from the EC2 `Laravel-Web-SG`.
*   **Migration:** Mechanically injected the RDS Endpoint, Database Name, and strict credentials into the `/var/www/laravel/.env` file using `sed`, authenticated into RDS via `mysql-client` to create the schema, and successfully ran `php artisan migrate:fresh --force`.

### B. Object Storage Tier (AWS S3)
*   **Provisioning:** Created a secure Amazon S3 bucket (`laravel-app-storage`) with all public access strictly blocked.
*   **IAM Integration:** Instead of hardcoding AWS access keys inside the application (which is a massive security risk), we utilized the EC2 instance's IAM Role (`EC2-CodeDeploy-Role`). We attached the `AmazonS3FullAccess` policy directly to the role, granting the EC2 server inherent mechanical permission to interact with the bucket.
*   **Configuration:** Updated the Laravel `.env` to route all filesystem uploads natively to the `s3` disk, utilizing the `league/flysystem-aws-s3-v3` library.

---

## 8. Conclusion
We successfully delivered a highly robust, production-ready 3-tier environment. The application compute is decoupled from state (RDS) and storage (S3), Nginx is reverse-proxying traffic perfectly to the PHP 8.3 FPM socket, and every push to GitHub triggers an automated Jenkins pipeline that handles dependencies, permissions, and daemon recycling without human intervention. 

By manually resolving GPG keys, JVM crashes, PHP versioning mismatches, and meticulously constructing a secure AWS VPC topology, this project thoroughly demonstrates deep technical ownership over Cloud DevOps mechanics.
