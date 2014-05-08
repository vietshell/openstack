IP:
ethx: 192.168.0.4
ethy: 192.168.2.3
service iptables stop
chkconfig iptables off
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
echo "192.168.0.2 controller" >> /etc/hosts
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
-----------------------------------
yum install openstack-nova-compute -y
openstack-config --set /etc/nova/nova.conf database connection mysql://nova:1357@controller/nova
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://controller:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host controller
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password 1246
openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend qpid
openstack-config --set /etc/nova/nova.conf DEFAULT qpid_hostname controller
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip 192.168.0.3
openstack-config --set /etc/nova/nova.conf DEFAULT vnc_enabled True
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address 192.168.0.3
openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://controller:6080/vnc_auto.html
openstack-config --set /etc/nova/nova.conf DEFAULT glance_host controller
service libvirtd start
service messagebus start
chkconfig libvirtd on
chkconfig messagebus on
service openstack-nova-compute start
chkconfig openstack-nova-compute on
---------------------------------------
# Edit /etc/sysctl.conf:
fil=`cat /etc/sysctl.conf | grep net.ipv4.conf.default.rp_filter`
echo 'net.ipv4.conf.all.rp_filter=0' >> /etc/sysctl.conf
sed -i 's/$fil/net.ipv4.conf.default.rp_filter=0/g' /etc/sysctl.conf
sysctl -p
yum install openstack-neutron-ml2 openstack-neutron-openvswitch -y
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://controller:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_host 192.168.0.2
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_user neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_password 1536
openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend neutron.openstack.common.rpc.impl_qpid
openstack-config --set /etc/neutron/neutron.conf DEFAULT qpid_hostname 192.168.0.2
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
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip 192.168.2.2
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs tunnel_type gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs enable_tunneling True
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
service openvswitch start
chkconfig openvswitch on
ovs-vsctl add-br br-int
----------------------------------------
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
------------------------------------------
ln -s plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
cp /etc/init.d/neutron-openvswitch-agent /etc/init.d/neutron-openvswitch-agent.orig
sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' /etc/init.d/neutron-openvswitch-agent
service openstack-nova-compute restart
service neutron-openvswitch-agent start
chkconfig neutron-openvswitch-agent on

