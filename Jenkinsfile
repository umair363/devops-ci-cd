pipeline {
    agent any

    environment {
        APP_DIR = "/var/www/laravel"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install PHP Dependencies') {
            steps {
                sh 'composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader'
            }
        }

        stage('Deploy Files to Web Root') {
            steps {
                // Copy all files from Jenkins workspace to Nginx web directory
                sh "sudo cp -rT . ${APP_DIR}"
            }
        }

        stage('Configure Web Server') {
            steps {
                // Copy the Nginx config, enable it, and remove the default splash page
                sh "sudo cp laravel.conf /etc/nginx/sites-available/laravel"
                sh "sudo ln -sf /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/"
                sh "sudo rm -f /etc/nginx/sites-enabled/default"
            }
        }

        stage('Set Permissions & Restart Daemons') {
            steps {
                // Give Nginx ownership of the files and restart services to apply changes
                sh "sudo chown -R www-data:www-data ${APP_DIR}"
                sh "sudo chmod -R 775 ${APP_DIR}/storage ${APP_DIR}/bootstrap/cache"
                sh "sudo systemctl restart nginx php8.2-fpm"
            }
        }
    }
}
