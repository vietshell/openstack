#!/bin/sh

#  computer.sh
#  
#
#  Created by HSP SI Viet Nam on 5/7/14.
#
clear
thumuc=`pwd`
dbpass="1234567"
dbip="192.168.0.110"
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
INSTANCE_TUNNELS_INTERFACE_IP_ADDRESS="192.168.2.220"
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

#Install neutron network
#INSTANCE_TUNNELS_INTERFACE_IP_ADDRESS="192.168.2.220"
sed -i 's/net.ipv4.conf.all.rp_filter/\#net.ipv4.conf.all.rp_filter/g' /etc/sysctl.conf
sed -i 's/net.ipv4.conf.default.rp_filter/\#net.ipv4.conf.default.rp_filter/g' /etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter=0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" >> /etc/sysctl.conf
sysctl -p
yum -y install openstack-neutron-ml2 openstack-neutron-openvswitch
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

openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router

sed -i '/\[DEFAULT\]/a verbose = True' /etc/neutron/neutron.conf
sed -i 's/service_provider=VPN:openswan:neutron.services.vpn.service_drivers.ipsec.IPsecVPNDriver:default/\#service_provider=VPN:openswan:neutron.services.vpn.service_drivers.ipsec.IPsecVPNDriver:default/g' /etc/neutron/neutron.conf

#confugre tunner interface
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 1:1000
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip $INSTANCE_TUNNELS_INTERFACE_IP_ADDRESS
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs tunnel_type gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs enable_tunneling True
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True

#Start service openvswitch
/etc/init.d/openvswitch start
chkconfig openvswitch on
ovs-vsctl add-br br-int

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

#To finalize the installation
ln -s plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
cp /etc/init.d/neutron-openvswitch-agent /etc/init.d/neutron-openvswitch-agent.orig
sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' /etc/init.d/neutron-openvswitch-agent

#restart service
/etc/init.d/openstack-nova-compute restart
/etc/init.d/neutron-openvswitch-agent start
chkconfig neutron-openvswitch-agent on


clear
echo " Success"
