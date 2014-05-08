IP:
eth2: 192.168.0.3
eth3: 192.168.2.2
eth1: 172.16.6.x
service iptables stop
chkconfig iptables off
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
echo "controller controller" >> /etc/hosts
echo "192.168.0.3 network" >> /etc/hosts
echo "192.168.0.4 compute" >> /etc/hosts
echo "192.168.0.6 mysql" >> /etc/hosts
-----------------------------------------------
yum install http://repos.fedorapeople.org/repos/openstack/openstack-icehouse/rdo-release-icehouse-3.noarch.rpm -y
yum install http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm -y
yum install MySQL-python wget -y
yum install openstack-utils -y
yum install openstack-selinux -y 
yum upgrade -y
reboot
----------------------------------
#yum install qpid-cpp-server -y
#sed -i 's/auth=yes/auth=no/g' /etc/qpidd.conf
#service qpidd start; chkconfig qpidd on
------------------------------------
# Edit /etc/sysctl.conf:
#fil=`cat /etc/sysctl.conf | grep net.ipv4.conf.default.rp_filter`
#fil1=`cat /etc/sysctl.conf | grep net.ipv4.ip_forward`
#sed -i 's/$fil1/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf
#echo 'net.ipv4.conf.all.rp_filter=0' >> /etc/sysctl.conf
#sed -i 's/$fil/net.ipv4.conf.default.rp_filter=0/g' /etc/sysctl.conf
sysctl -p
yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch -y
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
openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT verbose True
## We recommend adding verbose = True to the [DEFAULT] section in /etc/neutron/l3_agent.conf to assist with troubleshooting.
## Comment out any lines in the [service_providers] section.
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT use_namespaces True
-------------------------------
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT use_namespaces True
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT verbose True
## We recommend adding verbose = True to the [DEFAULT] section in /etc/neutron/dhcp_agent.conf to assist with troubleshooting.
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_url http://controller:5000/v2.0
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_region regionOne
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_tenant_name service
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_user neutron
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_password 1536
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip controller
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret 1234568
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT verbose True
## We recommend adding verbose = True to the [DEFAULT] section in /etc/neutron/metadata_agent.ini to assist with troubleshooting.
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 1:1000
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip 192.168.2.3
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs tunnel_type gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs enable_tunneling True
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
-----------------------------------------
service openvswitch start
chkconfig openvswitch on
ovs-vsctl add-br br-int
ovs-vsctl add-br br-ex
ovs-vsctl add-port br-ex eth0 // chua add
# ethtool -K eth1 gro off
ln -s plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
cp /etc/init.d/neutron-openvswitch-agent /etc/init.d/neutron-openvswitch-agent.orig
sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' /etc/init.d/neutron-openvswitch-agent
service neutron-openvswitch-agent restart
service neutron-l3-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart
chkconfig neutron-openvswitch-agent on
chkconfig neutron-l3-agent on
chkconfig neutron-dhcp-agent on
chkconfig neutron-metadata-agent on
