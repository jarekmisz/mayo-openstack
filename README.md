#Deploy kubernetes cluster with skydns on OpenStack using Heat
<a href="https://raw.githubusercontent.com/jarekmisz/mayo-openstack/master/kube-cluster-centos/templates/kube-cluster.yaml" target="_blank">
    See the template source code
</a>



This template deploys a kubernetes cluster that consists of a master and 2-n nodes (minions). The deployment has been tested on CentOS 7.1. It utilizes systemd and etcd. There is just one instance of etcd that runs on the kubernetes master. The master constitues a single point of failure so it really doesn't matter if etcd is highly available.
The naming convention:

* kube-master
* kube-minion0 .. kube-minion9

These names will appear in OpenStack dashboard and on OpenStack CLI output. Note that the hostnames will be assigned by dnsmasq at the deployment time. See the discussion below.


Couple comments on networking:
There are several layers of networking:

1. Physical network, on which the OpenStack nodes reside.
The IP addresses of the physical nodes depend on the specific installation.

2. The OpenStack virtual network, on which the VMs reside.

One possible configuration is shown below:

| Network Name | Provider Network Type | Subnet Name | IP Addresses | Allocation Pools | 
|:--- |:---|:---|:---|:---|
| private | vxlan | private-subnet |  172.27.1.0/24 | "start": "172.27.1.2", "end": "172.27.1.254" |
| public | vxlan | public-subnet | 10.146.112.0/22 | "start": "10.146.112.16", "end": "10.146.112.31" |


The VMs get dynamic IP addresses on private-subnet using dnsmasq. Consequently, the IP addresses assigned to the cluster's VMs are unknown until the cluster gets fully deployed. Therefore, the dnsmasq is also used to provide the DNS name resolution service. The dnsmasq assigns the DSN name to a dispensed IP address using the following pattern:

* sample IP: 172.27.1.10 - corresponding hostname: host-172-27-1-10

These names assigned by dnsmasq are used by the scripts invoked at cluster deployment time to set up the kube-master/kube-minions hostnames and then to configure the kubernetes components.
 

3. Ovelay network managed by flannel that is used by docker containers. The flannel network definition is shown below:

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

Flannel will asign one of the subnets to a node in the kubernetes cluster. Something like: 10.254.x.0. Consequently, the docker containers that get spinned up on that node will get IP addresses on that subnet. Flannel will route between the subnets so that a solution may consist of multiple pods that reside on multiple nodes (minions).

The template expects the following parameters:
  key_name:
    type: string
    description: keypair to enable SSH access to the instance.
    default: heat_key
  image:
    type: string
    description: ID of the image to use for the instance to be created.
    default: centos7-software-config-v3
  flavor:
    type: string
    description: Type of the instance to be created.
    default: m1.small
  private_net:
    type: string
    description: private network name into which servers get deployed
    default: private
  public_net:
    type: string
    description: public network name for which floating IP addresses will be allocated
    default: public
  minion_count:
    type: number
    default: 2


| Name   | Description | Default Value |
|:--- |:---|:---|
| key_name  | keypair to enable SSH access to the instance  | heat_key |
| image  | ID of the image to use for the instance to be created  | centos7-software-config-v3 |
| flavor | Type of the instance to be created | m1.small |
| private_net | Private network name into which servers get deployed | private |
| public_net | Spublic network name for which floating IP addresses will be allocated | public |
| minion_count | Number of minions to be created | 2 |



