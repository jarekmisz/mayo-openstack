#!/bin/bash
set -x
echo $MASTERIP
echo $DNSSERVER
echo $DNSDOMAIN
cat <<EOF > /etc/openstack-vars.conf
DNSSERVER=$DNSSERVER
DNSDOMAIN=$DNSDOMAIN
MASTERIP=$MASTERIP
EOF
