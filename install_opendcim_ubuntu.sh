#!/bin/bash

# Load variables from .env file
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "Error: $ENV_FILE not found."
    exit 1
fi

# Install required packages
sudo apt-get update
sudo apt-get install -y apache2 php php-snmp snmp-mibs-downloader php-curl php-gettext graphviz mariadb-server

# Download and unpack openDCIM
cd /var/www
sudo wget http://opendcim.org/packages/openDCIM-4.0.1.tar.gz
sudo tar zxpvf openDCIM-4.0.1.tar.gz
sudo ln -s openDCIM-4.0.1 dcim

# Set permissions for Apache
sudo chgrp -R www-data /var/www/dcim/pictures /var/www/dcim/drawings

# Create openDCIM database and user
sudo mysql -u root -p"$DB_ROOT_PASSWORD" <<EOF
CREATE DATABASE $DB_NAME;
GRANT ALL ON $DB_NAME.* TO '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
quit
EOF

# Copy and configure db.inc.php
cd /var/www/dcim
sudo cp db.inc.php-dist db.inc.php
sudo sed -i "s/\$dbhost = 'localhost';/\$dbhost = 'localhost';/" db.inc.php
sudo sed -i "s/\$dbname = 'dcim';/\$dbname = '$DB_NAME';/" db.inc.php
sudo sed -i "s/\$dbuser = 'dcim';/\$dbuser = '$DB_USER';/" db.inc.php
sudo sed -i "s/\$dbpass = 'dcimpassword';/\$dbpass = '$DB_PASSWORD';/" db.inc.php

# Configure Apache
sudo sed -i 's/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www\/dcim/' /etc/apache2/sites-available/default-ssl.conf
sudo sed -i '/DocumentRoot \/var\/www\/dcim/a \
    <Directory "/var/www/dcim"> \
        Options All \
        AllowOverride All \
        Require all granted \
    </Directory>' /etc/apache2/sites-available/default-ssl.conf
sudo sed -i 's/ErrorLog ${APACHE_LOG_DIR}\/error.log/ErrorLog ${APACHE_LOG_DIR}\/dcim-error.log/' /etc/apache2/sites-available/default-ssl.conf
sudo sed -i 's/CustomLog ${APACHE_LOG_DIR}\/access.log combined/CustomLog ${APACHE_LOG_DIR}\/dcim-access.log/' /etc/apache2/sites-available/default-ssl.conf

# Set up user access
sudo htpasswd -cb /var/www/opendcim.password dcim dcim
sudo cp /var/www/opendcim.password /var/www/dcim/.htpasswd

# Enable SSL and other required modules
sudo a2enmod ssl
sudo a2enmod rewrite
sudo a2ensite default-ssl

# Restart Apache
sudo service apache2 restart

echo "openDCIM installation complete."
