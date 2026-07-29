#!/bin/bash
# start_server.sh

# Restart Nginx and PHP-FPM to ensure they load the latest code and configs
systemctl restart php8.2-fpm
systemctl restart nginx

# Optional: Run Laravel migrations if you configure a database connection in .env later
# cd /var/www/laravel
# php artisan migrate --force
