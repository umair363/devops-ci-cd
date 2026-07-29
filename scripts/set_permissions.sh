#!/bin/bash
# set_permissions.sh

APP_DIR="/var/www/laravel"

# Change ownership to the web server user
chown -R www-data:www-data $APP_DIR

# Set appropriate directory and file permissions
find $APP_DIR -type d -exec chmod 755 {} \;
find $APP_DIR -type f -exec chmod 644 {} \;

# Give special permissions to storage and cache directories for Laravel
chmod -R 775 $APP_DIR/storage
chmod -R 775 $APP_DIR/bootstrap/cache
