#!/bin/bash
set -x
source /etc/openstack-vars.conf
#exec 3>&1 4>&2 >minion.log 2>&1
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
# As of 10/2/15 a temporary fix is required since docker in the virt7 repos does not install. There missing dependencies.
yum -y install docker-1.7.1-108.el7.centos  docker-logrotate-1.7.1-108.el7.centos  docker-selinux-1.7.1-108.el7.centos
#yum -y install docker docker-logrotate 
yum -y install kubernetes flannel


echo $MASTERIP
MASTERIPS=$(echo $MASTERIP | sed 's/\"//g') 
echo $MASTERIP
MASTERNAME="host-$(echo $MASTERIP | sed 's/\./\-/g')"
				
sed -i "s/127.0.0.1:8080/$MASTERNAME:8080/g" /etc/kubernetes/config

sed -i "s/127.0.0.1:4001/$MASTERNAME:4001/g" /etc/sysconfig/flanneld
sed -i 's\^FLANNEL_ETCD_KEY=.*\FLANNEL_ETCD_KEY="/flannel/network"\g' /etc/sysconfig/flanneld

# Configure the Kubelet Service
sed -i 's/^KUBELET_ADDRESS=.*/KUBELET_ADDRESS="--address=0.0.0.0"/g' /etc/kubernetes/kubelet
sed -i 's/^KUBELET_HOSTNAME=.*/KUBELET_HOSTNAME=/g' /etc/kubernetes/kubelet
sed -i 's\^KUBELET_API_SERVER=.*\KUBELET_API_SERVER="--api_servers=http://'$MASTERNAME':8080"\g' /etc/kubernetes/kubelet

service=flanneld
systemctl enable $service
systemctl restart $service
systemctl status $service 

sleep 10

for service in kube-proxy kubelet docker; do
    systemctl enable $service
    systemctl restart $service
    systemctl status $service 
done


#restore stdout and stderr
#exec 1>&3 2>&4