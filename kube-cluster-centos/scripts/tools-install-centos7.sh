#!/bin/bash

# This script installs in-instance tools that are necessary for Heat software
# config into a CentOS 6.5 base image. It is assumed that the image already
# includes cloud-init.

set -eux

#yum -y install epel-release
#sed -i "s/https/http/g" /etc/yum.repos.d/epel.repo
#sed -i "s/https/http/g" /etc/yum.repos.d/epel-testing.repo

# install rpm as in tools-install-centos.sh
yum -y install gcc
yum -y install python-pip python-devel #build-essential
yum -y groupinstall "Development Tools"
pip install --upgrade pip
pip install --upgrade virtualenv
yum -y install git libxml2-devel libxslt-devel zlib-devel #lib32z1-dev - looks like rhel uses 64-bit libz
yum -y install libyaml-devel # added by Thomas

# required by os-* tools; TODO: ok to install here or do this in vens of the 3 os-* tools?
pip install dib-utils

# temp dir for clones git repos
mkdir -p /tmp/git

# dir for virtual envs
mkdir -p /opt/stack/venvs

#################################
# install os-apply-config
# from tripleo-image-elements/elements/os-apply-config/install.d/os-apply-config-source-install/10-os-apply-config
#################################
virtualenv --setuptools /opt/stack/venvs/os-apply-config
set +u
source /opt/stack/venvs/os-apply-config/bin/activate
set -u

/opt/stack/venvs/os-apply-config/bin/pip install -U 'setuptools>=1.0'
/opt/stack/venvs/os-apply-config/bin/pip install -U 'pbr>=0.6,<1.0'
/opt/stack/venvs/os-apply-config/bin/pip install --pre -U os-apply-config

ln -s /opt/stack/venvs/os-apply-config/bin/os-apply-config /usr/local/bin/os-apply-config

set +u
deactivate
set -u

#################################
# install os-collect-config
# from tripleo-image-elements/elements/os-collect-config/install.d/os-collect-config-source-install/10-os-collect-config
#################################
virtualenv --setuptools /opt/stack/venvs/os-collect-config
set +u
source /opt/stack/venvs/os-collect-config/bin/activate
set -u

/opt/stack/venvs/os-collect-config/bin/pip install -U 'setuptools>=1.0'
/opt/stack/venvs/os-collect-config/bin/pip install -U 'pbr>=0.6,<1.0'
/opt/stack/venvs/os-collect-config/bin/pip install --pre -U os-collect-config

ln -s /opt/stack/venvs/os-collect-config/bin/os-collect-config /usr/local/bin/os-collect-config

# Minimal static config for bootstrapping
cat > /etc/os-collect-config.conf <<eof
[DEFAULT]
command=os-refresh-config
eof
chmod 600 /etc/os-collect-config.conf

cat > /lib/systemd/system/os-collect-config.service <<eof
[Unit]
Description=Collect metadata and run hook commands.
After=cloud-final.service
Before=crond.service
[Service]
ExecStart=/usr/local/bin/os-collect-config
Restart=on-failure
[Install]
WantedBy=multi-user.target
eof

# install os-apply-config templates
cd /tmp/git
git clone https://git.openstack.org/openstack/tripleo-image-elements.git
install -D -o root -g root -m 0600 \
/tmp/git/tripleo-image-elements/elements/os-collect-config/os-apply-config/etc/os-collect-config.conf \
/usr/libexec/os-apply-config/templates/etc/os-collect-config.conf

# os-svc-enable -n os-collect-config # TODO: this kicks us out of the venv - verify if really needed!

set +u
deactivate
set -u


#################################
# install os-refresh-config
# from tripleo-image-elements/elements/os-refresh-config/install.d/os-refresh-config-source-install/10-os-refresh-config
#################################
virtualenv --setuptools /opt/stack/venvs/os-refresh-config
set +u
source /opt/stack/venvs/os-refresh-config/bin/activate
set -u

/opt/stack/venvs/os-refresh-config/bin/pip install -U pip
/opt/stack/venvs/os-refresh-config/bin/pip install -U 'setuptools>=1.0'
/opt/stack/venvs/os-refresh-config/bin/pip install -U 'pbr>=0.5.21,<1.0'
/opt/stack/venvs/os-refresh-config/bin/pip install --pre -U os-refresh-config

ln -s /opt/stack/venvs/os-refresh-config/bin/os-refresh-config /usr/local/bin/os-refresh-config

for d in pre-configure.d configure.d migration.d post-configure.d; do
    install -m 0755 -o root -g root -d /opt/stack/os-config-refresh/$d
done

# install 50-os-config-applier
tee  50-os-config-applier << EOF
#!/bin/bash
exec os-apply-config
EOF

install -D -g root -o root -m 0755 50-os-config-applier /opt/stack/os-config-refresh/configure.d/50-os-config-applier

set +u
deactivate
set -u


#################################
# install heat-config and hooks
#################################

pip install python-heatclient

# clone heat-templates repo which contains all necessary files
cd /tmp/git
git clone https://git.openstack.org/openstack/heat-templates.git

# heat-config -> initial heat config data
install -D -o root -g root -m 0600 \
/tmp/git/heat-templates/hot/software-config/elements/heat-config/install.d/heat-config \
/var/run/heat-config/heat-config

# os-apply-config template
install -D -o root -g root -m 0600 \
/tmp/git/heat-templates/hot/software-config/elements/heat-config/os-apply-config/var/run/heat-config/heat-config \
/usr/libexec/os-apply-config/templates/var/run/heat-config/heat-config

# 55-heat-config -> central hook
install -D -o root -g root -m 0755 \
/tmp/git/heat-templates/hot/software-config/elements/heat-config/os-refresh-config/configure.d/55-heat-config \
/opt/stack/os-config-refresh/configure.d/55-heat-config

# install heat-config-notify command
install -D -o root -g root -m 0755 \
/tmp/git/heat-templates/hot/software-config/elements/heat-config/bin/heat-config-notify \
/usr/local/bin/heat-config-notify


# puppet hook
echo "WARNING: puppet hook currently not installed!"
# yum -y install puppet
# install -D -o root -g root -m 0755 \
# /tmp/git/heat-templates/hot/software-config/elements/heat-config-puppet/install.d/hook-puppet.py \
# /var/lib/heat-config/hooks/puppet

# salt hook
echo "WARNING: salt hook currently not installed!"
# yum -y install salt-minion
# install -D -o root -g root -m 0755 \
# /tmp/git/heat-templates/hot/software-config/elements/heat-config-salt/install.d/hook-salt.py \
# /var/lib/heat-config/hooks/salt

# script hook
install -D -o root -g root -m 0755 \
/tmp/git/heat-templates/hot/software-config/elements/heat-config-script/install.d/hook-script.py \
/var/lib/heat-config/hooks/script

# cfn-init hook
install -D -o root -g root -m 0755 \
/tmp/git/heat-templates/hot/software-config/elements/heat-config-cfn-init/install.d/hook-cfn-init.py \
/var/lib/heat-config/hooks/cfn-init

#################################
# clean up
#################################

systemctl enable os-collect-config.service
#systemctl restart os-collect-config.service

rm -rf /tmp/git
#rm -rf /var/lib/cloud/instances
#rm -rf /var/lib/cloud/instance
#rm -rf /var/log/cloud-init.log
#rm -rf ~/.ssh/*
