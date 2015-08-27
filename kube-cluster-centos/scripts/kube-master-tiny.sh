#!/bin/bash
set -x
echo $MINONIPS
echo $DNSSERVER
echo $DNSDOMAIN
cat <<EOF > /etc/openstack-vars.conf
DNSSERVER=$DNSSERVER
DNSDOMAIN=$DNSDOMAIN
MINIONIPS="$MINIONIPS"
EOF
