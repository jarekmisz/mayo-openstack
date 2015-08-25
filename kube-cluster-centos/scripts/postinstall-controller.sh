#!/bin/bash
source openrc demo demo
nova keypair-add heat_key > heat_key.priv
chmod 600 heat_key.priv
#neutron net-create demo-net
#neutron subnet-create --name demo-subnet --dns-nameservers list=true 192.168.1.2 129.176.199.5 demo-net 192.168.1.0/24
#neutron router-interface-add router1 admin-subnet
nova secgroup-add-rule default TCP 1 65535 0.0.0.0/0
nova secgroup-add-rule default UDP 1 65535 0.0.0.0/0
nova secgroup-add-rule default ICMP -1 -1 0.0.0.0/0
source openrc admin admin
neutron net-create admin-net
#Using built-in dnsmasq
neutron subnet-create --name admin-subnet --dns-nameserver 192.168.2.2 --dns-nameserver 129.176.171.5 admin-net 192.168.2.0/24
neutron router-interface-add router1 admin-subnet
nova secgroup-add-rule default TCP 1 65535 0.0.0.0/0
nova secgroup-add-rule default UDP 1 65535 0.0.0.0/0
nova secgroup-add-rule default ICMP -1 -1 0.0.0.0/0
# if additional private networks are created for example subnet 192.168.2.0/24
# need to make sure the gateway IP on the router is correct here it is 10.146.112.32
sudo ip route add 192.168.3.0/24 via 10.146.112.32 dev br-ex
# To increase the max of mysql connections (default is 151)
# mysql -u root -p
# mysql> show variables like "max_connections";
# set global max_connections = 300;