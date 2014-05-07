#!/bin/sh

#  basic_configure.sh
#  
#
#  Created by HSP SI Viet Nam on 5/7/14.
#
#!/bin/sh

#  install_mysql.sh
#
#
#  Created by HSP SI Viet Nam on 5/7/14.
#
service NetworkManager stop
service network start
chkconfig NetworkManager off
chkconfig network on
service firewalld stop
service iptables stop
chkconfig firewalld off
chkconfig iptables off
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config 
#!/bin/sh

#  setup_interface.sh
#
#
#  Created by HSP SI Viet Nam on 5/6/14.
#
clear
ip link show | grep BROADCAST,MULTICAST | awk '{print $2}' | sed 's/://' > list_allinterface.txt
for interface in $( cat list_allinterface.txt );
do ipadd=`/sbin/ifconfig $interface | grep inet | awk '{print $2}' | sed 's/addr://'`
macaddr=`ip link show $interface | grep link/ether | awk '{print $2}'`
netmask=`ifconfig $interface | grep Mask | awk '{print $4}' | sed 's/Mask://'`
kieu=`cat /etc/sysconfig/network-scripts/ifcfg-$interface | grep BOOTPROTO | sed 's/BOOTPROTO=//'`
if [ "$kieu" = "none" ]; then
kieu=static
fi
echo "interface $interface  -  Dia Chi IP: $ipadd  -  Subnet Mask: $netmask  -  Kieu: $kieu  - MAC Addr - $macaddr";
done
DF_GATEWAY=`route -n | grep 'UG[ \t]' | awk '{print $2, $8}'`
echo "=============================="
echo "Default gateway $DF_GATEWAY"
echo ""
echo ""
echo "Can you configure interface?"
#configure interface
PS3="Please, choose number: "
select yn in "yes" "no";
do
break
done
if [ "$yn" = "no" ]; then
exit 1
fi
echo ""

#setup interface
echo "Setup Static IP ADDRESS For Interface"
listcase=`cat list_allinterface.txt`
PS3="Please, choose number: "
select name in $listcase "Exit....."
do
break
done
if [ "$name" = "" ]; then
echo "Error in entry."
exit 1
fi
if [ "$name" = "Exit..." ]; then
echo "Exit...."
exit 1
fi
echo ""
echo "You choose setup Interface $name ."
echo ""

#choose DHCP Configure
echo "You want to configure static or dhcp?"
PS3="Please, choose number: "
select ncf in "DHCP" "Static" "Exit....."
do
break
done
if [ "$ncf" = "Exit....." ]; then
echo "Goodbye!"
exit 1
fi
if [ "$ncf" = "" ]; then
echo "Error in entry."
exit 1
fi

#setup interface dhcp
if [ "$ncf" = "DHCP" ]; then
cat > /etc/sysconfig/network-scripts/ifcfg-$name << eof
DEVICE=$name
TYPE=Ethernet
ONBOOT=yes
NM_CONTROLLED=no
BOOTPROTO=dhcp
DNS1=8.8.8.8
DEFROUTE=yes
PEERDNS=no
PEERROUTES=yes
IPV4_FAILURE_FATAL=yes
IPV6INIT=no
NAME="System $name"
eof
echo "reset network interface"
echo "please waiting 3s ...."
ifdown $name && ifup $name
sh setup_interface.sh
exit 1
fi

#static ip address
echo ""
read -p"IP Address: " ipadds
echo ""
if [ "$ipadds" = "" ]; then

echo "IP Address not null"
exit $1
fi
echo ""
read -p"Subnet Mask: " subnetmask
if [ "$subnetmask" = "" ]; then
echo "Subnet Mask not null"
exit 1
fi
echo ""
echo "Default Gateway:"
read -p"(You can input Enter if you not set default gateway....): " dfw


if [ "$dfw" = "" ]; then
cat > /etc/sysconfig/network-scripts/ifcfg-$name << eof
DEVICE=$name
TYPE=Ethernet
ONBOOT=yes
NM_CONTROLLED=no
BOOTPROTO=none
IPADDR=$ipadds
NETMASK=$subnetmask
DNS1=8.8.8.8
DEFROUTE=yes
PEERDNS=no
PEERROUTES=yes
IPV4_FAILURE_FATAL=yes
IPV6INIT=no
NAME="System $name"
eof
echo "reset network interface"
echo "please waiting 3s ...."
ifdown $name && ifup $name
sh setup_interface.sh
exit 1
fi

cat > /etc/sysconfig/network-scripts/ifcfg-$name << eof
DEVICE=$name
TYPE=Ethernet
ONBOOT=yes
NM_CONTROLLED=no
BOOTPROTO=none
IPADDR=$ipadds
NETMASK=$subnetmask
GATEWAY=$dfw
DNS1=8.8.8.8
DEFROUTE=yes
PEERDNS=no
PEERROUTES=yes
IPV4_FAILURE_FATAL=yes
IPV6INIT=no
NAME="System $name"
eof
echo "reset network interface"
echo "please waiting 3s ...."
ifdown $name && ifup $name
sh setup_interface.sh
exit 1