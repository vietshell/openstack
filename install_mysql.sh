#!/bin/sh

#  install_mysql.sh
#  
#
#  Created by HSP SI Viet Nam on 5/7/14.
#

thumuc=`pwd`
dbpass="1234567"
dbip="192.168.0.135"
controller="192.168.0.110"
ADMIN_PASS="123456a"
ADMIN_EMAIL="service.vietsi@gmail.com"
DEMO_PASS="123456a"
DEMO_EMAIL="namnt2202@gmail.com"
GLANCE_PASS="123456a"
NOVA_PASS="123456a"
NEUTRON_PASS="123456a"
ADMIN_TOKEN="1234567a"
METADATA_SECRET="1234567"
FLOATING_IP_START="172.16.6.1"
FLOATING_IP_END="172.16.6.252"
EXTERNAL_NETWORK_GATEWAY="172.16.6.254"
EXTERNAL_NETWORK_CIDR="172.16.6.0/24"
TENANT_NETWORK_GATEWAY="192.168.1.254"
TENANT_NETWORK_CIDR="192.168.1.0/24"
echo "Install MySQL Server"
echo "Please, wait...."
yum -y install mysql-server mlocate
clear
updatedb
link_mycnf=`locate my.cnf`
echo "Install MySQL Success Full."
echo "Start serivce mysql"
echo "Wait.............."
sed -i 's/bind-address/\#bind-address/g' $link_mycnf
sed -i '/\[mysqld\]/a character-set-server = utf8' $link_mycnf
sed -i '/\[mysqld\]/a init-connect = "SET NAMES utf8"' $link_mycnf
sed -i '/\[mysqld\]/a collation-server = utf8_general_ci' $link_mycnf
sed -i '/\[mysqld\]/a default-storage-engine = innodb' $link_mycnf
sleep 5
/etc/init.d/mysqld start
chkconfig mysqld on
echo $link_mycnf
sleep 3
#dbpass=`openssl rand -hex 16`
dbpass="1234567"
#Create user root % and db
mysql -u root << EOF

GRANT USAGE ON *.* TO root@'%' IDENTIFIED BY '$dbpass';
UPDATE mysql.user SET Password=PASSWORD('$dbpass') WHERE User='root';
delete from mysql.user where user='';
GRANT ALL PRIVILEGES ON * . * TO  'root'@'%' WITH GRANT OPTION MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0 ;

CREATE DATABASE keystone;
GRANT ALL ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$dbpass';
GRANT ALL ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$dbpass';

CREATE DATABASE glance;
GRANT ALL ON glance.* TO 'glance'@'%' IDENTIFIED BY '$dbpass';
GRANT ALL ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$dbpass';

CREATE DATABASE neutron;
GRANT ALL ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$dbpass';
GRANT ALL ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$dbpass';

CREATE DATABASE nova;
GRANT ALL ON nova.* TO 'nova'@'%' IDENTIFIED BY '$dbpass';
GRANT ALL ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$dbpass';

CREATE DATABASE cinder;
GRANT ALL ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$dbpass';
GRANT ALL ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$dbpass';

CREATE DATABASE heat;
GRANT ALL ON heat.* TO 'heat'@'%' IDENTIFIED BY '$dbpass';
GRANT ALL ON heat.* TO 'heat'@'localhost' IDENTIFIED BY '$dbpass';
EOF

echo "Restart MySQL - Server"
echo "Wait......."
sleep 3
/etc/init.d/mysqld restart
echo $dbpass