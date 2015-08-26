#!/bin/bash
set -x
source /etc/openstack-vars.conf
#exec 3>&1 4>&2 >master.log 2>&1
export THISHOSTIP=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
#Set the hostname
export HOSTNAME="host-$(echo $THISHOSTIP | sed 's/\./\-/g')"
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



cat << EOF > /etc/yum.repos.d/virt7-docker-common-candidate.repo
[virt7-docker-common-candidate]
name=virt7-docker-common-candidate
baseurl=http://cbs.centos.org/repos/virt7-docker-common-candidate/x86_64/os/
gpgcheck=0
EOF

yum -y install docker docker-logrotate kubernetes etcd flannel
#Common config
	
sed -i "s/127.0.0.1:8080/$HOSTNAME:8080\g" /etc/kubernetes/config

sed -i "s/127.0.0.1:4001/$HOSTNAME:4001/g" /etc/sysconfig/flanneld
sed -i 's\^FLANNEL_ETCD_KEY=.*\FLANNEL_ETCD_KEY="/flannel/network"\g' /etc/sysconfig/flanneld

cp /etc/etcd/etcd.conf /etc/etcd/etcd.conf.orig
sed -i 's\^ETCD_NAME=.*\ETCD_NAME='$HOSTNAME'\g' /etc/etcd/etcd.conf
sed -i 's\^#ETCD_LISTEN_PEER_URLS=.*\ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"\g' /etc/etcd/etcd.conf
sed -i 's\^ETCD_LISTEN_CLIENT_URLS=.*\ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:4001"\g' /etc/etcd/etcd.conf
sed -i 's\^#ETCD_INITIAL_ADVERTISE_PEER_URLS=.*\ETCD_INITIAL_ADVERTISE_PEER_URLS="http://0.0.0.0:2380"\g' /etc/etcd/etcd.conf
sed -i 's\^#ETCD_INITIAL_CLUSTER=.*\ETCD_INITIAL_CLUSTER="'$HOSTNAME'=http://0.0.0.0:2380"\g' /etc/etcd/etcd.conf
sed -i 's\^ETCD_ADVERTISE_CLIENT_URLS=.*\ETCD_ADVERTISE_CLIENT_URLS="http://0.0.0.0:4001"\g' /etc/etcd/etcd.conf

sed -i 's/^KUBE_API_ADDRESS=.*/KUBE_API_ADDRESS="--address=0.0.0.0"/g' /etc/kubernetes/apiserver
sed -i 's\^KUBE_ETCD_SERVERS=.*\KUBE_ETCD_SERVERS="--etcd-servers=http://127.0.0.1:4001"\g' /etc/kubernetes/apiserver
sed -i 's/^KUBE_ADMISSION_CONTROL=.*/KUBE_ADMISSION_CONTROL="--admission-control=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ResourceQuota"/g' /etc/kubernetes/apiserver

# Using the list of minion IPs create a list of minion hostnames resolvable by dnsmasq  
echo $MINIONIPS
IPS=$(echo $MINIONIPS | sed "s/u'[0-9]*'://g" | sed -r "s/[{u',}]+//g")
echo $IPS
list=
for ip in $IPS
do 
MINIONHOSTNAME="host-$(echo $ip | sed 's/\./\-/g')"
list=$list$MINIONHOSTNAME','
done
# remove the trailing ,
list=$(echo $list | sed -e 's/,$//')
sed -i 's/^# defaults from config and apiserver.*/KUBELET_ADDRESSES="--machines='$list'"/g' /etc/kubernetes/controller-manager

for service in etcd kube-apiserver kube-controller-manager kube-scheduler; do 
    systemctl enable $service
    systemctl restart $service
    systemctl status $service 
done

cat << EOF > ./flannel-config.json
{
    "Network": "10.254.0.0/16",
    "SubnetLen": 24,
    "SubnetMin": "10.254.50.0",
    "SubnetMax": "10.254.199.0",
    "Backend": {
        "Type": "vxlan",
        "VNI": 1
    }
}
EOF

curl -L http://$HOSTNAME:4001/v2/keys/flannel/network/config -XPUT --data-urlencode value@./flannel-config.json

service=flanneld
systemctl enable $service
systemctl restart $service
systemctl status $service 
#restore stdout and stderr
#exec 1>&3 2>&4