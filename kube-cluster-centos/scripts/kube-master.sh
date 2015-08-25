#!/bin/bash
set -x
#DNSSERVER="129.176.199.5"
#DNSDOMAIN="mayo.edu"
export THISHOSTIP=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
#Set the hostname
HOSTNAME="host-$(echo $THISHOSTIP | sed 's/\./\-/g')"
hostname $HOSTNAME
hostnamectl set-hostname $HOSTNAME
# Fix the name resolution
if [[ -z $DNSSERVER ]]
then
    echo "DNS Server IP not set..."
else
    echo "nameserver $DNSSERVER" >> /etc/resolv.conf
fi

if [[ -z $DNSDOMAIN ]]
then
    echo "DNS Domain Name not set..."
else
    sed -i "/^search/{s/$/ $DNSDOMAIN/}" /etc/resolv.conf
fi
#When reboot happens
chmod +x /etc/rc.d/rc.local
cat <<EOF > /etc/openstack-nameserver.conf
DNSSERVER=$DNSSERVER
DNSDOMAIN=$DNSDOMAIN
HOSTNAME=$HOSTNAME
EOF

#To ensure idenpotance of this script
if [ -e /etc/rc.d/rc.local.original ] ; then
 cp /etc/rc.d/rc.local.original /etc/rc.d/rc.local
else
 cp /etc/rc.d/rc.local /etc/rc.d/rc.local.original
fi
#Fix the DNS server Ip on consecutive boots, note the quotes around EOF
cat <<'EOF' >> /etc/rc.d/rc.local
if [ -e /etc/openstack-nameserver.conf ]
then
    source /etc/openstack-nameserver.conf
    if [[ -z $DNSSERVER ]]
    then
        echo "DNS Server IP not set..."
    else
        echo "nameserver $DNSSERVER" >> /etc/resolv.conf
    fi
    if [[ -z $DNSDOMAIN ]]
    then
        echo "DNS Domain Name not set..."
    else
        sed -i "/^search/{s/$/ $DNSDOMAIN/}" /etc/resolv.conf
    fi
fi
EOF

echo "Done..."
