#!/bin/sh

#  install_controller.sh
#  
#
#  Created by HSP SI Viet Nam on 5/7/14.
#
#setting system
thumuc=`pwd`
dbpass="1234567"
dbip="192.168.0.134"
controller="192.168.0.110"
ADMIN_PASS="123456a"
ADMIN_EMAIL="service.vietsi@gmail.com"
DEMO_PASS="123456a"
DEMO_EMAIL="namnt2202@gmail.com"
GLANCE_PASS="123456a"
NOVA_PASS="123456a"
NEUTRON_PASS="123456a"
ADMIN_TOKEN="1234567a"
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
#Install
#echo "Install MySQL Client - MySQL For Python"
#sleep 2
#yum -y install mysql MySQL-python wget mlocate

clear
echo "Install Message Server: qpid"
sleep 3
#install qpid
yum -y install qpid-cpp-server

clear
echo "Setting qpid"
sleep 3
sed -i 's/auth=yes/auth=no/g' /etc/qpidd.conf
/etc/init.d/qpidd start
chkconfig qpidd on

#Install the Identity Service
clear
echo "Install the Identity Service"
sleep 3
yum -y install openstack-keystone python-keystoneclient
openstack-config --set /etc/keystone/keystone.conf database connection mysql://keystone:$dbpass@$dbip/keystone
su -s /bin/sh -c "keystone-manage db_sync" keystone

#setup admintoken

penstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $ADMIN_TOKEN
keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
chown -R keystone:keystone /etc/keystone/ssl
chmod -R o-rwx /etc/keystone/ssl
/etc/init.d/openstack-keystone start
chkconfig openstack-keystone on
(crontab -l 2>&1 | grep -q token_flush) || echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' >> /var/spool/cron/root

#Define users, tenants, and roles

export OS_SERVICE_TOKEN=$ADMIN_TOKEN
export OS_SERVICE_ENDPOINT=http://192.168.0.110:35357/v2.0
echo "export OS_SERVICE_TOKEN=$ADMIN_TOKEN" > $thumuc/seting_openstack
echo "export OS_SERVICE_ENDPOINT=http://192.168.0.110:35357/v2.0" >> $thumuc/seting_openstack
chmod +x $thumuc/seting_openstack
keystone user-create --name=admin --pass=$ADMIN_PASS --email=$ADMIN_EMAIL
keystone role-create --name=admin
keystone tenant-create --name=admin --description="Admin Tenant"
keystone user-role-add --user=admin --tenant=admin --role=admin
keystone user-role-add --user=admin --role=_member_ --tenant=admin
keystone user-create --name=demo --pass=$DEMO_PASS --email=$DEMO_EMAIL
keystone tenant-create --name=demo --description="Demo Tenant"
keystone user-role-add --user=demo --role=_member_ --tenant=demo
keystone tenant-create --name=service --description="Service Tenant"
keystone service-create --name=keystone --type=identity --description="OpenStack Identity"
keystone endpoint-create --service-id=$(keystone service-list | awk '/ identity / {print $2}') --publicurl=http://$controller:5000/v2.0 --internalurl=http://$controller:5000/v2.0 --adminurl=http://$controller:35357/v2.0

#Verify the Identity Service installation
unset OS_SERVICE_TOKEN OS_SERVICE_ENDPOINT
keystone --os-username=admin --os-password=$ADMIN_PASS --os-auth-url=http://$controller:35357/v2.0 token-get
keystone --os-username=admin --os-password=$ADMIN_PASS --os-tenant-name=admin --os-auth-url=http://$controller:35357/v2.0 token-get


export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://$controller:35357/v2.0

cat > $thumuc/admin-openrc.sh << eof
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://$controller:35357/v2.0
eof
chmod +x $thumuc/admin-openrc.sh
source $thumuc/admin-openrc.sh
keystone token-get
keystone user-list
sleep 3
keystone user-role-list --user admin --tenant admin
sleep 3


#Install glance
yum -y install openstack-glance python-glanceclient
openstack-config --set /etc/glance/glance-api.conf database connection mysql://glance:$dbpass@$dbip/glance
openstack-config --set /etc/glance/glance-registry.conf database connection mysql://$dbpass@$dbip/glance
openstack-config --set /etc/glance/glance-api.conf DEFAULT rpc_backend qpid
openstack-config --set /etc/glance/glance-api.conf DEFAULT qpid_hostname $controller

#import db
su -s /bin/sh -c "glance-manage db_sync" glance
keystone user-create --name=glance --pass=$GLANCE_PASS --email=$ADMIN_EMAIL
keystone user-role-add --user=glance --tenant=service --role=admin
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://$controller:5000
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_host $controller
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_user glance
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_password $GLANCE_PASS
openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://$controller:5000
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_host $controller
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_user glance
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_password $GLANCE_PASS
openstack-config --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
keystone service-create --name=glance --type=image --description="OpenStack Image Service"
keystone endpoint-create --service-id=$(keystone service-list | awk '/ image / {print $2}') --publicurl=http://$controller:9292 --internalurl=http://$controller:9292 --adminurl=http://$controller:9292

#start service glance
for sv_glance in $( ls /etc/init.d | grep openstack-glance );
do /etc/init.d/$sv_glance restart
chkconfig $sv_glance on;
done

#create images
source $thumuc/admin-openrc.sh
mkdir $thumuc/images
cd $thumuc/images/
wget http://cdn.download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img
glance image-create --name "cirros-0.3.2-x86_64" --disk-format qcow2 --container-format bare --is-public True --progress < $thumuc/images/cirros-0.3.2-x86_64-disk.img

#Install Compute controller services
yum -y install openstack-nova-api openstack-nova-cert openstack-nova-conductor \
openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler \
python-novaclient

#configure nova
openstack-config --set /etc/nova/nova.conf database connection mysql://nova:$dbpass@$dbip/nova
openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend qpid
openstack-config --set /etc/nova/nova.conf DEFAULT qpid_hostname $controller
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip $controller
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen $controller
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $controller

#create db
su -s /bin/sh -c "nova-manage db sync" nova
keystone user-create --name=nova --pass=$NOVA_PASS --email=$ADMIN_EMAIL
keystone user-role-add --user=nova --tenant=service --role=admin

openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$controller:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host $controller
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password $NOVA_PASS

keystone service-create --name=nova --type=compute --description="OpenStack Compute"
keystone endpoint-create --service-id=$(keystone service-list | awk '/ compute / {print $2}') --publicurl=http://$controller:8774/v2/%\(tenant_id\)s --internalurl=http://$controller:8774/v2/%\(tenant_id\)s --adminurl=http://$controller:8774/v2/%\(tenant_id\)s

#start service glance
for sv_nova in $( ls /etc/init.d | grep openstack-nova );
do /etc/init.d/$sv_glance restart
chkconfig $sv_nova on;
done

clear
nova image-list
sleep 3


#Networking
keystone user-create --name neutron --pass $NEUTRON_PASS --email $ADMIN_EMAIL
keystone user-role-add --user neutron --tenant service --role admin
keystone service-create --name neutron --type network --description "OpenStack Networking"
keystone endpoint-create --service-id $(keystone service-list | awk '/ network / {print $2}') --publicurl http://$controller:9696 --adminurl http://$controller:9696 --internalurl http://$controller:9696

#install network
yum -y install openstack-neutron openstack-neutron-ml2 python-neutronclient

#configure neutron
openstack-config --set /etc/neutron/neutron.conf database connection mysql://neutron:$dbpass@$dbip/neutron
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://$controller:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_host $controller
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_user neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_password $NEUTRON_PASS
openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend neutron.openstack.common.rpc.impl_qpid
openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_hostname $controller

openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_url http://$controller:8774/v2
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_admin_username nova
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_admin_tenant_id $(keystone tenant-list | awk '/ service / { print $2 }')
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_admin_password $NOVA_PASS
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_admin_auth_url http://$controller:35357/v2.0

openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router

#To configure the Modular Layer 2 (ML2) plug-in

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 1:1000
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True

#To configure Compute to use Networking
openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_url http://$controller:9696
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_auth_strategy keystone
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_tenant_name service
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_username neutron
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_password $NEUTRON_PASS
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_auth_url http://$controller:35357/v2.0
openstack-config --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf DEFAULT security_group_api neutron

#create link ml2.conf
ln -s plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

#start service
/etc/init.d/openstack-nova-api restart
/etc/init.d/openstack-nova-scheduler restart
/etc/init.d/openstack-nova-conductor restart
service neutron-server start
chkconfig neutron-server on

#configure sysctl
sed -i 's/net.ipv4.ip_forward/\#net.ipv4.ip_forward/g' /etc/sysctl.conf
sed -i 's/net.ipv4.conf.all.rp_filter/\#net.ipv4.conf.all.rp_filter/g' /etc/sysctl.conf
sed -i 's/net.ipv4.conf.default.rp_filter/\#net.ipv4.conf.default.rp_filter/g' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter=0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" >> /etc/sysctl.conf
sysctl -p

#Configure Dashboard
yum -y install memcached python-memcached mod_wsgi openstack-dashboard
/etc/init.d/httpd start
chkconfig httpd on


clear
ip link show | grep BROADCAST,MULTICAST | awk '{print $2}' | sed 's/://' > list_allinterface.txt
for interface in $( cat list_allinterface.txt );
do ipadd=`/sbin/ifconfig $interface | grep inet | awk '{print $2}' | sed 's/addr://'`
echo "http://$ipadd/dashboard";
done
echo "Success"
exit 1