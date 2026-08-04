pipeline {
    agent any

    environment {
        APP_IP      = '13.61.174.62'
        APP_USER    = 'ubuntu'
        APP_DIR     = '/var/www/node-app'
        PM2_APP     = 'node-app'
        // SSH key added via Jenkins Credentials (id: 'app-ec2-ssh-key')
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Pulling latest code from GitHub...'
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                echo 'Installing Node.js dependencies on Jenkins agent...'
                sh 'npm install --production'
            }
        }

        stage('Deploy to App EC2') {
            steps {
                echo "Deploying to App EC2: ${APP_IP}..."
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'app-ec2-ssh-key',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    sh """
                        # Sync code (exclude git and node_modules)
                        rsync -av \
                            -e "ssh -i \$SSH_KEY -o StrictHostKeyChecking=no" \
                            --exclude='.git' \
                            --exclude='node_modules' \
                            --delete ./ ${APP_USER}@${APP_IP}:${APP_DIR}/

                        # Install dependencies on App EC2
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no \
                            ${APP_USER}@${APP_IP} \
                            "cd ${APP_DIR} && npm install --production"
                    """
                }
            }
        }

        stage('Configure Nginx') {
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'app-ec2-ssh-key',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    sh """
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no \
                            ${APP_USER}@${APP_IP} "
                            sudo cp ${APP_DIR}/nginx.conf /etc/nginx/sites-available/node-app
                            sudo ln -sf /etc/nginx/sites-available/node-app /etc/nginx/sites-enabled/node-app
                            sudo rm -f /etc/nginx/sites-enabled/default
                            sudo nginx -t && sudo systemctl reload nginx
                        "
                    """
                }
            }
        }

        stage('Restart App via PM2') {
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'app-ec2-ssh-key',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    sh """
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no \
                            ${APP_USER}@${APP_IP} "
                            cd ${APP_DIR}
                            if pm2 describe ${PM2_APP} > /dev/null 2>&1; then
                                pm2 reload ${PM2_APP}
                            else
                                pm2 start server.js --name ${PM2_APP}
                                pm2 save
                            fi
                        "
                    """
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'app-ec2-ssh-key',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    sh """
                        sleep 5
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no \
                            ${APP_USER}@${APP_IP} "
                            curl -sf http://127.0.0.1:3000 > /dev/null && \
                            echo '✅ App is live on 13.61.174.62' || \
                            echo '⚠️  App health check failed'
                            pm2 list
                        "
                    """
                }
            }
        }
    }

    post {
        success { echo '🚀 Deployment to 13.61.174.62 successful!' }
        failure { echo '❌ Deployment failed. Check logs above.' }
    }
}
