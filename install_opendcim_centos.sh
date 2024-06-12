#!/bin/bash

# Load variables from .env file
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "Error: $ENV_FILE not found."
    exit 1
fi

# Install Apache
yum -y install httpd
systemctl enable httpd.service
systemctl start httpd.service

# Install PHP
yum -y install php php-mysql php-mbstring php-snmp

# Install MySQL Server
yum -y install mariadb-server
systemctl enable mariadb.service
systemctl start mariadb.service

# Secure MySQL Server
mysql_secure_installation

# Create a database for openDCIM
mysql -u root -p <<EOF
CREATE DATABASE $DB_NAME;
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER' IDENTIFIED BY '$DB_PASSWORD';
EXIT;
EOF

# Enable HTTPS
yum -y install mod_ssl

# Generate SSL keys
cd /root
openssl genrsa -out ca.key 1024 
openssl req -new -key ca.key -out ca.csr
openssl x509 -req -days 365 -in ca.csr -signkey ca.key -out ca.crt
cp ca.crt /etc/pki/tls/certs
cp ca.key /etc/pki/tls/private/ca.key
cp ca.csr /etc/pki/tls/private/ca.csr

# Set server name for HTTPS
sed -i "/#ServerName www.example.com:80/a ServerName $SERVER_NAME:443" /etc/httpd/conf/httpd.conf

# Restart Apache
systemctl restart httpd.service

# Create VirtualHost configuration
cat <<EOT >> /etc/httpd/conf.d/opendcim.example.net.conf
<VirtualHost *:443>
    SSLEngine On
    SSLCertificateFile /etc/pki/tls/certs/ca.crt
    SSLCertificateKeyFile /etc/pki/tls/private/ca.key
    ServerAdmin $SERVER_ADMIN
    DocumentRoot /opt/openDCIM/opendcim
    ServerName $SERVER_NAME
    <Directory /opt/openDCIM/opendcim>
        AllowOverride All
        AuthType Basic
        AuthName "openDCIM"   
        AuthUserFile /opt/openDCIM/opendcim/.htpasswd
        Require valid-user
    </Directory>
</VirtualHost>
EOT

# Enable User Authentication
touch /opt/openDCIM/opendcim/.htpasswd
htpasswd -b -c /opt/openDCIM/opendcim/.htpasswd Administrator $HTPASSWD_PASSWORD

# Open Web Access on Firewall
firewall-cmd --zone=public --add-port=443/tcp --permanent
firewall-cmd --reload

# Download and Install openDCIM
mkdir /opt/openDCIM
cd /opt/openDCIM
curl -O https://www.opendcim.org/packages/openDCIM-23.04.tar.gz
tar zxvf openDCIM-23.04.tar.gz
ln -s openDCIM-23.04 opendcim

# Prepare the configuration file for database access
cd /opt/openDCIM/opendcim
cp db.inc.php-dist db.inc.php
sed -i "s/\$dbhost = 'localhost';/\$dbhost = 'localhost';/" db.inc.php
sed -i "s/\$dbname = 'dcim';/\$dbname = '$DB_NAME';/" db.inc.php
sed -i "s/\$dbuser = 'dcim';/\$dbuser = '$DB_USER';/" db.inc.php
sed -i "s/\$dbpass = 'dcimpassword';/\$dbpass = '$DB_PASSWORD';/" db.inc.php

# Restart Apache
systemctl restart httpd.service

# Rename install.php
mv /opt/openDCIM/opendcim/install.php /opt/openDCIM/opendcim/install.php.original

echo "openDCIM installation complete."
