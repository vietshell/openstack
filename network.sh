#!/bin/sh

#  network.sh
#  
#
#  Created by HSP SI Viet Nam on 5/7/14.
#

#import conifugre
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
METADATA_SECRET="1234567"
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

#configure sysctl
sed -i 's/net.ipv4.ip_forward/\#net.ipv4.ip_forward/g' /etc/sysctl.conf
sed -i 's/net.ipv4.conf.all.rp_filter/\#net.ipv4.conf.all.rp_filter/g' /etc/sysctl.conf
sed -i 's/net.ipv4.conf.default.rp_filter/\#net.ipv4.conf.default.rp_filter/g' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter=0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" >> /etc/sysctl.conf

clear
sysctl -p

#install neutron
echo "install neutron"
sleep 5
yum -y install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch

clear

#configure neutron
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
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT use_namespaces True

sed -i 's/service_provider=VPN:openswan:neutron.services.vpn.service_drivers.ipsec.IPsecVPNDriver:default/\#service_provider=VPN:openswan:neutron.services.vpn.service_drivers.ipsec.IPsecVPNDriver:default/g' /etc/neutron/neutron.conf

#To configure the DHCP agent
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT use_namespaces True
sed -i '/\[DEFAULT\]/a verbose = True' /etc/neutron/dhcp_agent.ini

openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_url http://$controller:5000/v2.0
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_region regionOne
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_tenant_name service
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_user neutron
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_password $NEUTRON_PASS
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip $controller
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $METADATA_SECRET

sed -i '/\[DEFAULT\]/a verbose = True' /etc/neutron/metadata_agent.ini

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 1:1000
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip INSTANCE_TUNNELS_INTERFACE_IP_ADDRESS
# openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs \
tunnel_type gre
# openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs \
enable_tunneling True
# openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup \
firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
# openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup \
enable_security_group True