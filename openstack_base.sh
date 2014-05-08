#!/bin/sh

#  controller.sh
#
#
#  Created by HSP SI Viet Nam on 5/7/14.
#
#setting system
service NetworkManager stop
service network start
chkconfig NetworkManager off
chkconfig network on
service firewalld stop
service iptables stop
chkconfig firewalld off
chkconfig iptables off
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
yum -y install mysql MySQL-python wget mlocate
clear
echo "Install Openstack Packet"
sleep 3
wget http://repos.fedorapeople.org/repos/openstack/openstack-icehouse/rdo-release-icehouse-3.noarch.rpm
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum -y install rdo-release-icehouse-3.noarch.rpm epel-release-6-8.noarch.rpm
yum -y install openstack-utils
yum -y install openstack-selinux
yum -y upgrade
echo "Basic Setting Openstack Success"
echo "Server reboot ....."
echo "GoodBye"
sleep 3
reboot
