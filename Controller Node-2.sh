#IP: 
#eth1: controller
service iptables stop
chkconfig iptables off
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
echo "192.168.0.2 controller" >> /etc/hosts
echo "192.168.0.3 network" >> /etc/hosts
echo "192.168.0.4 compute" >> /etc/hosts
echo "192.168.0.6 mysql" >> /etc/hosts


yum install http://repos.fedorapeople.org/repos/openstack/openstack-icehouse/rdo-release-icehouse-3.noarch.rpm -y;
yum install http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm -y;
yum install mysql mysql-server MySQL-python wget -y;
yum install openstack-utils -y;
yum install openstack-selinux -y;
yum upgrade -y;
yum install ntp -y
service ntpd start
chkconfig ntpd on
reboot
#-----------------------------------
# cau hinh my.cnf #
yum -y install mlocate
updatedb
linkmycnf=`locate my.cnf`
sed -i 's/bind-address/\#bind-address/g' $linkmycnf
sed -i '/\[mysqld\]/a character-set-server = utf8' $linkmycnf
sed -i '/\[mysqld\]/a init-connect = "SET NAMES utf8"' $linkmycnf
sed -i '/\[mysqld\]/a collation-server = utf8_general_ci' $linkmycnf
sed -i '/\[mysqld\]/a default-storage-engine = innodb' $linkmycnf
service mysqld restart
chkconfig mysqld on
sleep 3
mysql_install_db
mysql -u root << eof
GRANT USAGE ON *.* TO root@'%' IDENTIFIED BY '123456a@';
UPDATE mysql.user SET Password=PASSWORD('123456a@') WHERE User='root';
delete from mysql.user where user='';
GRANT ALL PRIVILEGES ON * . * TO  'root'@'%' WITH GRANT OPTION MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0 ;
eof
service mysqld restart
mysql -u root -p123456a@ << eof
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '123456';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '123456';
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '2345';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '2345';
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '1357';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '1357';
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '1768';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '1768';
eof
# ----------------------------------
yum install qpid-cpp-server -y
sed -i 's/auth=yes/auth=no/g' /etc/qpidd.conf
service qpidd start; chkconfig qpidd on
# ------------------------------------
yum install openstack-keystone python-keystoneclient -y
openstack-config --set /etc/keystone/keystone.conf  database connection mysql://keystone:123456@controller/keystone
# ------------------------------------
su -s /bin/sh -c "keystone-manage db_sync" keystone
ADMIN_TOKEN=$(openssl rand -hex 10)
echo $ADMIN_TOKEN
openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $ADMIN_TOKEN
keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
chown -R keystone:keystone /etc/keystone/ssl
chmod -R o-rwx /etc/keystone/ssl
service openstack-keystone start
chkconfig openstack-keystone on
(crontab -l 2>&1 | grep -q token_flush) || \
echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' >> /var/spool/cron/root
export OS_SERVICE_TOKEN=$ADMIN_TOKEN
export OS_SERVICE_ENDPOINT=http://controller:35357/v2.0
# ---------------------------------------
keystone user-create --name=admin --pass=123456a --email=admin@hsp-vn.com
keystone role-create --name=admin
keystone tenant-create --name=admin --description="Admin Tenant"
keystone user-role-add --user=admin --tenant=admin --role=admin
keystone user-role-add --user=admin --role=_member_ --tenant=admin
keystone user-create --name=demo --pass=12345 --email=abc@yahoo.com
keystone tenant-create --name=demo --description="Demo Tenant"
keystone user-role-add --user=demo --role=_member_ --tenant=demo
keystone tenant-create --name=service --description="Service Tenant"
keystone service-create --name=keystone --type=identity --description="OpenStack Identity"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ identity / {print $2}') \
--publicurl=http://controller:5000/v2.0 \
--internalurl=http://controller:5000/v2.0 \
--adminurl=http://controller:35357/v2.0
unset OS_SERVICE_TOKEN OS_SERVICE_ENDPOINT
keystone --os-username=admin --os-password=123456a --os-auth-url=http://controller:35357/v2.0 token-get
keystone --os-username=admin --os-password=123456a --os-tenant-name=admin --os-auth-url=http://controller:35357/v2.0 token-get
export OS_USERNAME=admin
export OS_PASSWORD=123456a
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://controller:35357/v2.0
keystone token-get
keystone user-list
keystone user-role-list --user admin --tenant admin
# Ket thuc Keystone #
# Image service ( Glance ) #
yum install openstack-glance python-glanceclient -y
openstack-config --set /etc/glance/glance-api.conf database connection mysql://glance:2345@controller/glance
openstack-config --set /etc/glance/glance-registry.conf database connection mysql://glance:2345@controller/glance
openstack-config --set /etc/glance/glance-api.conf DEFAULT rpc_backend qpid
openstack-config --set /etc/glance/glance-api.conf DEFAULT qpid_hostname controller
# ----------------------------
su -s /bin/sh -c "glance-manage db_sync" glance
keystone user-create --name=glance --pass=23456 --email=glance@hsp-vn.com
keystone user-role-add --user=glance --tenant=service --role=admin
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://controller:5000
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_host controller
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_user glance
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_password 23456
openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://controller:5000
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_host controller
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_user glance
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_password 23456
openstack-config --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
keystone service-create --name=glance --type=image --description="OpenStack Image Service"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ image / {print $2}') \
--publicurl=http://controller:9292 \
--internalurl=http://controller:9292 \
--adminurl=http://controller:9292
service openstack-glance-api start
service openstack-glance-registry start
chkconfig openstack-glance-api on
chkconfig openstack-glance-registry on
# --------------------------------------------
mkdir images
cd images/
wget http://cdn.download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img
glance image-create --name "cirros-0.3.2-x86_64" --disk-format qcow2 --container-format bare --is-public True --progress < cirros-0.3.2-x86_64-disk.img
glance image-list

# Ket thuc Glance #
#--------------------------------------------
# Install nova_controller
yum install -y openstack-nova-api openstack-nova-cert openstack-nova-conductor \
openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler \
python-novaclient
openstack-config --set /etc/nova/nova.conf database connection mysql://nova:1357@controller/nova
openstack-config --set /etc/nova/nova.conf \
DEFAULT rpc_backend qpid
# Su dung IP Manager controller #
openstack-config --set /etc/nova/nova.conf DEFAULT qpid_hostname controller
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip 192.168.0.2
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen 192.168.0.2
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address 192.168.0.2
# ----------------------------------
su -s /bin/sh -c "nova-manage db sync" nova
keystone user-create --name=nova --pass=1246 --email=nova@hsp-vn.com
keystone user-role-add --user=nova --tenant=service --role=admin
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://controller:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host controller
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password 1246
keystone service-create --name=nova --type=compute \
--description="OpenStack Compute"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ compute / {print $2}') \
--publicurl=http://controller:8774/v2/%\(tenant_id\)s \
--internalurl=http://controller:8774/v2/%\(tenant_id\)s \
--adminurl=http://controller:8774/v2/%\(tenant_id\)s
service openstack-nova-api start
service openstack-nova-cert start
service openstack-nova-consoleauth start
service openstack-nova-scheduler start
service openstack-nova-conductor start
service openstack-nova-novncproxy start
chkconfig openstack-nova-api on
chkconfig openstack-nova-cert on
chkconfig openstack-nova-consoleauth on
chkconfig openstack-nova-scheduler on
chkconfig openstack-nova-conductor on
chkconfig openstack-nova-novncproxy on
nova image-list
# ---------------------------------------------------
# Cai dat Neutron_controller #
keystone user-create --name neutron --pass 1536 --email neutron@hsp-vn.com
keystone user-role-add --user neutron --tenant service --role admin
keystone service-create --name neutron --type network --description "OpenStack Networking"
keystone endpoint-create \
--service-id $(keystone service-list | awk '/ network / {print $2}') \
--publicurl http://controller:9696 \
--adminurl http://controller:9696 \
--internalurl http://controller:9696
yum install openstack-neutron openstack-neutron-ml2 python-neutronclient -y
openstack-config --set /etc/neutron/neutron.conf database connection mysql://neutron:1768@controller/neutron
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://controller:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_host controller
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_user neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_password 1536
openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend neutron.openstack.common.rpc.impl_qpid
openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_hostname controller
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_url http://controller:8774/v2
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_admin_username nova
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_admin_tenant_id $(keystone tenant-list | awk '/ service / { print $2 }')
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_admin_password 1246
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_admin_auth_url http://controller:35357/v2.0
openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router
openstack-config --set /etc/neutron/neutron.conf DEFAULT verbose True
sed -i 's/service_provider=VPN:openswan:neutron.services.vpn.service_drivers.ipsec.IPsecVPNDriver:default/\#service_provider=VPN:openswan:neutron.services.vpn.service_drivers.ipsec.IPsecVPNDriver:default/g' /etc/neutron/neutron.conf
## We recommend adding verbose = True to the [DEFAULT] section in /etc/neutron/neutron.conf to assist with troubleshooting.
## Comment out any lines in the [service_providers] section.
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 1:1000
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
# -----------------------------------------------
openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_url http://controller:9696
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_auth_strategy keystone
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_tenant_name service
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_username neutron
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_password 1536
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_auth_url http://controller:35357/v2.0
openstack-config --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf DEFAULT security_group_api neutron
# -----------------------------------------------
ln -s plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
service openstack-nova-api restart
service openstack-nova-scheduler restart
service openstack-nova-conductor restart
service neutron-server start
chkconfig neutron-server on
# --------------------------------------------------
openstack-config --set /etc/nova/nova.conf DEFAULT service_neutron_metadata_proxy true
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_metadata_proxy_shared_secret 1234568
service openstack-nova-api restart
# Khoi tao network #
source openrc.sh
#- Share router -#
neutron net-create ext-net --shared --router:external=True
#- External subnet -#
neutron subnet-create ext-net --name ext-subnet \
  --allocation-pool start=172.16.6.200,end=172.16.6.210 \
  --disable-dhcp --gateway 172.16.6.254 172.16.6.0/24
#- create the tenant network -#
source demo-openrc.sh
export OS_USERNAME=demo
export OS_PASSWORD=12345
export OS_TENANT_NAME=demo
export OS_AUTH_URL=http://controller:35357/v2.0
neutron net-create demo-net
neutron subnet-create demo-net --name demo-subnet \
  --gateway 192.168.1.1 192.168.1.0/24
neutron router-create demo-router
neutron router-interface-add demo-router demo-subnet
neutron router-gateway-set demo-router ext-net
# B8 Dashboard #
yum install memcached python-memcached mod_wsgi openstack-dashboard -y
#- edit /etc/openstack-dashboard/local_settings:
CACHES = {
'default': {
'BACKEND' : 'django.core.cache.backends.memcached.MemcachedCache',
'LOCATION' : '127.0.0.1:11211'
}
}
ALLOWED_HOSTS = ['localhost', 'my-desktop']
OPENSTACK_HOST = "controller"
setsebool -P httpd_can_network_connect on
service httpd start
service memcached start
chkconfig httpd on
chkconfig memcached on
## Local memory cache ##
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
CACHES = {
  'default' : {
    'BACKEND': 'django.core.cache.backends.locmem.LocMemCache'
  }
}
## Cau hinh memcached ##
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
CACHES = {
  'default': {
    'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache'
    'LOCATION': '127.0.0.1:11211',
  }
}
## Cau hinh database cho Dashboard ##
mysql -u root -p123456a@
CREATE DATABASE dash;
GRANT ALL PRIVILEGES ON dash.* TO 'dash'@'%' IDENTIFIED BY '1268';
GRANT ALL PRIVILEGES ON dash.* TO 'dash'@'localhost' IDENTIFIED BY '1268';
## Edit /etc/openstack-dashboard/local_settings ##
SESSION_ENGINE = 'django.core.cache.backends.db.DatabaseCache'
DATABASES = {
    'default': {
        # Database configuration here
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'dash',
        'USER': 'dash',
        'PASSWORD': '1268',
        'HOST': 'localhost',
        'default-character-set': 'utf8'
    }
}
/usr/share/openstack-dashboard/manage.py syncdb
service httpd restart
service nova-api restart
## Cached database ##
SESSION_ENGINE = "django.contrib.sessions.backends.cached_db"
------------------------------------------------------------------
# Block Storage #
yum install openstack-cinder -y
openstack-config --set /etc/cinder/cinder.conf \
database connection mysql://cinder:4523@controller/cinder
# - Tao DB -#
mysql -u root -p123456a@
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' \
IDENTIFIED BY '4523';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' \
IDENTIFIED BY '4523';
su -s /bin/sh -c "cinder-manage db sync" cinder
# - Tao User - #
keystone user-create --name=cinder --pass=4678 --email=cinder@hsp-vn.com
keystone user-role-add --user=cinder --tenant=service --role=admin
openstack-config --set /etc/cinder/cinder.conf DEFAULT \
  auth_strategy keystone
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
  auth_uri http://controller:5000
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
  auth_host controller
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
  auth_protocol http
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
  auth_port 35357
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
  admin_user cinder
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
  admin_tenant_name service
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
  admin_password 4678
openstack-config --set /etc/cinder/cinder.conf \
  DEFAULT rpc_backend cinder.openstack.common.rpc.impl_qpid
openstack-config --set /etc/cinder/cinder.conf \
  DEFAULT qpid_hostname controller
-----------------------------
keystone service-create --name=cinder --type=volume --description="OpenStack Block Storage"
keystone endpoint-create \
  --service-id=$(keystone service-list | awk '/ volume / {print $2}') \
  --publicurl=http://controller:8776/v1/%\(tenant_id\)s \
  --internalurl=http://controller:8776/v1/%\(tenant_id\)s \
  --adminurl=http://controller:8776/v1/%\(tenant_id\)s
keystone service-create --name=cinderv2 --type=volumev2 --description="OpenStack Block Storage v2"
keystone endpoint-create \
  --service-id=$(keystone service-list | awk '/ volumev2 / {print $2}') \
  --publicurl=http://controller:8776/v2/%\(tenant_id\)s \
  --internalurl=http://controller:8776/v2/%\(tenant_id\)s \
  --adminurl=http://controller:8776/v2/%\(tenant_id\)s
service openstack-cinder-api restart
service openstack-cinder-scheduler restart
chkconfig openstack-cinder-api on
chkconfig openstack-cinder-scheduler on