# 🚀 Node.js DevOps Deployment Pipeline

This repository contains a modern Node.js 3-tier application designed for a production AWS deployment, meeting the updated DevOps Engineering Technical Assessment criteria.

## 🌟 Key Features
- **Node.js (Express)** backend instead of Laravel.
- **Direct EC2 Deployment** via automated **Jenkins CI/CD** (No Containers).
- **AWS Secrets Manager** integration for securing database credentials.
- **Amazon S3** integration to fetch and display image assets using dynamic pre-signed URLs.
- **Modern Glassmorphism UI** with a dark-mode theme, utilizing asynchronous JavaScript for smooth UX.
- **Nginx Reverse Proxy** routing traffic via a custom Domain Name.

## 🏗 Architecture Diagram

```mermaid
graph TD
    User([End User]) -->|HTTP/HTTPS| Domain[Domain Name / Nginx]
    Domain -->|Proxy Pass 80->3000| EC2[EC2 Instance: Node.js App]
    
    subgraph AWS VPC
        EC2 -->|Query DB| Secrets[AWS Secrets Manager]
        Secrets -.->|Injects Creds| EC2
        EC2 -->|Port 3306| RDS[(AWS RDS: MySQL)]
        EC2 -->|IAM Role Fetch| S3[(Amazon S3: Images)]
    end
    
    subgraph CI/CD Pipeline
        Dev([Developer]) -->|Push| GitHub[GitHub Repo (Main Branch)]
        GitHub -->|Webhook| Jenkins[Jenkins CI/CD]
        Jenkins -->|Deploy & Restart PM2| EC2
    end
```

## ⚙️ Deployment Instructions
1. Push code to the `main` branch.
2. Jenkins automatically checks out the source code, installs dependencies (`npm install`), and uses `rsync` to move files to `/var/www/node-app`.
3. Jenkins restarts the Node application via **PM2** and reloads **Nginx**.
4. Access the web app through the configured domain name. No ALB is required.
