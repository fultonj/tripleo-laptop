#!/usr/bin/env bash
# Does the work from the following document:
#  http://docs.openstack.org/developer/tripleo-docs/installation/installation.html
# -------------------------------------------------------
PRE_UNDERCLOUD=1
REPO=1
INSTALL=1
POST_UNDERCLOUD=1
CONTAINERS_EXT=1
CONTAINERS_LOC=0
# -------------------------------------------------------
test "$(whoami)" != 'stack' \
    && (echo "This must be run by the stack user on the undercloud"; exit 1)
# -------------------------------------------------------
if [ $PRE_UNDERCLOUD -eq 1 ]; then
    echo "Creating SSH config"
    if [[ ! -f ~/.ssh/config ]]; then
	echo StrictHostKeyChecking no > ~/.ssh/config
	chmod 0600 ~/.ssh/config
	rm -f ~/.ssh/known_hosts 2> /dev/null
	ln -s /dev/null ~/.ssh/known_hosts
    fi

    echo "Verifying hostname is set for undercloud install"
    if sudo hostnamectl --static ; then
        echo "hostnamectl is working"
    else
        # workaround for "message recipient disconnected from message"
        echo "hostnamectl is not working; trying workaround"
        sudo setenforce 0
        sudo hostnamectl set-hostname $(hostname)
        sudo hostnamectl --static
        sudo setenforce 1
        echo "SELinux is enabled"
    fi

    if [[ $(ip a s eth0 | grep 192.168.24 | wc -l) -eq 0 ]]; then
	echo "Bringing up eth0"
	cat /dev/null > /tmp/eth0
	echo "DEVICE=eth0" >> /tmp/eth0
	echo "ONBOOT=yes" >> /tmp/eth0
	echo "TYPE=Ethernet" >> /tmp/eth0
	echo "IPADDR=192.168.24.1" >> /tmp/eth0
	echo "PREFIX=24" >> /tmp/eth0
	sudo mv /tmp/eth0 /etc/sysconfig/network-scripts/ifcfg-eth0
	sudo chcon system_u:object_r:net_conf_t:s0 /etc/sysconfig/network-scripts/ifcfg-eth0
	sudo ifdown eth0
	sudo ifup eth0
	ip a s eth0
    fi
fi
# -------------------------------------------------------
if [ $REPO -eq 1 ]; then
    if [[ ! -d ~/rpms ]]; then mkdir ~/rpms; fi
    url=https://trunk.rdoproject.org/centos7/current/
    rpm_name=$(curl $url | grep python2-tripleo-repos | sed -e 's/<[^>]*>//g' | awk 'BEGIN { FS = ".rpm" } ; { print $1 }')
    rpm=$rpm_name.rpm
    curl -f $url/$rpm -o ~/rpms/$rpm
    if [[ -f ~/rpms/$rpm ]]; then
	sudo yum install -y ~/rpms/$rpm
	sudo -E tripleo-repos current-tripleo-dev
	sudo yum repolist
	sudo yum update -y
    else
	echo "$rpm is missing. Aborting."
	exit 1
    fi
fi
# -------------------------------------------------------
if [ $INSTALL -eq 1 ]; then
    if [[ ! -f ~/undercloud.conf ]]; then
	echo "unable to find ~/undercloud.conf"
	exit 1
    fi

    echo "Installing python-tripleoclient from yum"
    sudo yum install -y python-tripleoclient
    
    echo "Installing undercloud"
    time openstack undercloud install
fi
# -------------------------------------------------------
if [ ! -f /home/stack/stackrc ]; then 
    echo "/home/stack/stackrc does not exist. Exiting. "
    exit 1
fi
# -------------------------------------------------------
if [ $POST_UNDERCLOUD -eq 1 ]; then
    echo "Authenticating to undercloud"
    source ~/stackrc

    # Setting this up to happen automatically
    if [[ ! $(grep strackrc ~/.bashrc) ]]; then 
	echo "source /home/stack/stackrc" >> ~/.bashrc
    fi

    echo "Setting DNS Server"
    openstack subnet list 
    SNET=$(openstack subnet list | awk '/192/ {print $2}')
    openstack subnet show $SNET
    # https://www.opendns.com/
    openstack subnet set $SNET --dns-nameserver 208.67.222.123 --dns-nameserver 208.67.220.123
    openstack subnet show $SNET
fi
# -------------------------------------------------------
if [ $CONTAINERS_EXT -eq 1 ]; then
    tag="current-tripleo-rdo"
    openstack overcloud container image prepare \
	--namespace trunk.registry.rdoproject.org/master \
	--tag $tag \
	--env-file ~/docker_registry.yaml
fi
# -------------------------------------------------------
if [ $CONTAINERS_LOC -eq 1 ]; then
    # broken
    tag="current-tripleo-rdo"
    cp ~/tht/overcloud_containers.yaml .
    if [[ -f overcloud_containers.yaml ]] ; then
	echo "uploading container registry based on overcloud_containers.yaml"
	sudo openstack overcloud container image upload --config-file overcloud_containers.yaml --verbose
	echo $?
	echo "Note the error code above ^ (is it not 0?)"
	
	echo "The following images are now in the local registry"
	curl -s http://192.168.24.1:8787/v2/_catalog | jq "."

	attempted=$(cat overcloud_containers.yaml | grep -v container_images | wc -l)
	uploaded=$(curl -s http://192.168.24.1:8787/v2/_catalog | jq "." | egrep "master|ceph" | wc -l)
	echo "Of the $attempted docker images, only $uploaded were uploaded"
	echo "Look for a pattern of the ones that did not make it in the following: "
	
	for l in $(cat overcloud_containers.yaml | awk {'print $3'} | awk 'BEGIN { FS="/" } { print $3 }' | sed s/:current-tripleo-rdo//g ); do
	    echo $l
	    curl -s http://192.168.24.1:8787/v2/_catalog | jq "." | grep -n $l ;
	done	

	echo "Considering re-running 'openstack overcloud container image upload' if missing iamges are necessary"
	echo ""
	
	echo "Creating ~/docker_registry.yaml with references to local registry"
	openstack overcloud container image prepare \
              --namespace=192.168.24.1:8787/master \
              --tag=$tag \
              --set ceph_namespace=192.168.24.1:8787 \
              --set ceph_image=ceph/daemon \
              --set ceph_tag=tag-stable-3.0-luminous-centos-7 \
              --env-file=/home/stack/docker_registry.yaml

	echo "Workaround missing current-tripleo-rdo for centos-binary-keepalived"
	grep keepalived /home/stack/docker_registry.yaml
	sed -i s/centos-binary-keepalived:current-tripleo-rdo/centos-binary-keepalived:tripleo-ci-testing/g /home/stack/docker_registry.yaml

	echo "~/docker_registry.yaml has had the following centos-binary-keepalived update"
	grep keepalived /home/stack/docker_registry.yaml
    else
	echo "overcloud_containers.yaml is not in current directory"
    fi
fi
