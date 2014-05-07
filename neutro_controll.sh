FLOATING_IP_START="172.16.6.1"
FLOATING_IP_END="172.16.6.252"
EXTERNAL_NETWORK_GATEWAY="172.16.6.254"
EXTERNAL_NETWORK_CIDR="172.16.6.0/24"
TENANT_NETWORK_GATEWAY="192.168.1.254"
TENANT_NETWORK_CIDR="192.168.1.0/24"
source admin-openrc.sh

neutron net-create ext-net --shared --router:external=True
neutron subnet-create ext-net --name ext-subnet --allocation-pool start=$FLOATING_IP_START,end=$FLOATING_IP_END --disable-dhcp --gateway $EXTERNAL_NETWORK_GATEWAY $EXTERNAL_NETWORK_CIDR
source demo-openrc.sh
neutron net-create demo-net
neutron subnet-create demo-net --name demo-subnet --gateway $TENANT_NETWORK_GATEWAY $TENANT_NETWORK_CIDR

neutron router-create demo-router
neutron router-interface-add demo-router demo-subnet
neutron router-gateway-set demo-router ext-net