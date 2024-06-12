Install some additional packages needed
Log in as the user set up during the installation, and at the $ prompt you'll do the following:

$ sudo apt-get install php-snmp snmp-mibs-downloader php-curl php-gettext graphviz
You will be asked to confirm, and once the packages are installed it is time to download the latest version of openDCIM.

Download and unpackage openDCIM
Assuming that you wish to install openDCIM under the /var/www directory, do the following, but be sure to use the most recent package link for openDCIM:

$ cd
$ wget http://opendcim.org/packages/openDCIM-4.0.1.tar.gz
$ cd /var/www
$ sudo tar zxpvf ~/openDCIM-4.0.1.tar.gz
$ sudo ln -s openDCIM-4.0.1 dcim
Give Apache permission to write to certain directories
There are times when Apache will need to be able to write to two of the directories - specifically the /drawings (maps of your data centers) and /pictures (pictures of your devices) folders. To do this, we need to set the group for those folders to the group that Apache is running as. On a default Ubuntu 15.04 server, that group is called www-data.

$ sudo chgrp -R www-data /var/www/dcim/pictures /var/www/dcim/drawings
Create your openDCIM DB and point openDCIM at it
You will need to either have your dba perform this step for you or you will need to know the MySQL root password (you are prompted to set it during installation). For our example, it is rootpw.

$ mysql -u root -prootpw
mysql> create database dcim;
mysql> grant all on dcim.* to 'dcim'@'localhost' identified by 'dcim';
mysql> quit
This will create a database called 'dcim' and also grant full access on it to a user who can only access the db locally and using the password of 'dcim'.

$ cd /var/www/dcim
$ cp db.inc.php-dist db.inc.php
If you are using a locally hosted MySQL database called 'dcim' with a user and password combination of 'dcim'/'dcim' then there is no need to edit the file once you have copied it over. If you have different values, please update the file accordingly.

Configure Apache
By default, Apache only runs on port 80 (http) and serves the content in directory /var/www/html. We want SSL encryption and we don't want the default site, either.

$ cd /etc/apache2/sites-available
$ sudo nano default-ssl.conf
Change the line that starts with DocumentRoot, plus add the following lines:

DocumentRoot /var/www/dcim

<Directory "/var/www/dcim">
    Options All
    AllowOverride All
    Require all granted
</Directory>
It is also suggested that you change the following two lines further down in the configuration file:

ErrorLog ${APACHE_LOG_DIR}/dcim-error.log
CustomLog ${APACHE_LOG_DIR}/dcim-access.log
Save the file and we're almost there.

Set up user access for your website
There are a lot of ways to control access to your web server and we are only going to cover the most basic. You can search the web for ways to integrate Apache with LDAP or Active Directory, but at that point it is an Apache issue, not an openDCIM issue.

To set up the most basic authentication possible:

$ nano /var/www/dcim/.htaccess

AuthType Basic
AuthName "openDCIM"
AuthUserFile /var/www/opendcim.password
Require valid-user
Save that file and Apache will know how to ask users to log in. We have one last thing to do before we can pull up the website.

Finalize the Apache configuration and restart it
Issue the following commands to enable the site and modules that we need. Most of these commands will tell you to restart apache after you issue them - ignore that, as you are restarting apache as the very last step.

$ sudo htpasswd -cb /var/www/opendcim.password dcim dcim
$ sudo a2enmod ssl
$ sudo a2enmod rewrite
$ sudo a2ensite default-ssl
$ sudo service apache2 restart
