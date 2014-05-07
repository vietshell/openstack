#!/bin/sh

#  computer.sh
#  
#
#  Created by HSP SI Viet Nam on 5/7/14.
#
clear
thumuc=`pwd`
dbpass="1234567"
dbip="192.168.0.135"
controller="192.168.0.110"
novaip="192.168.0.220"
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
yum -y install openstack-nova-compute

#Configure Nova Computer
openstack-config --set /etc/nova/nova.conf database connection mysql://nova:$dbpass@$dbip/nova
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$controller:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host $controller
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password $NOVA_PASS

openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend qpid
openstack-config --set /etc/nova/nova.conf DEFAULT qpid_hostname $controller
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip $novaip
openstack-config --set /etc/nova/nova.conf DEFAULT vnc_enabled True
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $novaip
openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://$controller:6080/vnc_auto.html

openstack-config --set /etc/nova/nova.conf DEFAULT glance_host $controller

checkvm=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ "$checkvm" = "" ]; then
openstack-config --set /etc/nova/nova.conf libvirt virt_type qemu
fi

#start service
echo "start service"
sleep 3
/etc/init.d/libvirtd start
/etc/init.d/messagebus start
chkconfig libvirtd on
chkconfig messagebus on
/etc/init.d/openstack-nova-compute start
chkconfig openstack-nova-compute on


clear
echo " Success"
