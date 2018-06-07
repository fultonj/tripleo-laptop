#!/usr/bin/env bash
# -------------------------------------------------------
DOM=example.com
SRC=centos
NUMBER=0
if [[ "$1" = "undercloud" ]]; then
    NUMBER=1
    echo "cloning one $1"
    IP=192.168.122.252
    RAM=8192
    CPU=1
fi
if [[ "$1" = "overcloud" ]]; then
    if [[ $2 =~ ^[0-9]+$ ]]; then
	NUMBER=$2
    else
	NUMBER=1
    fi
    echo "Cloning $NUMBER $1 VM(s)"
    IP=192.168.122.251
    RAM=8192
    CPU=1
fi
if [[ ! $NUMBER -gt 0 ]]; then
    echo "Usage: $0 <undercloud or overcloud> [<number of over nodes (default 1)>]"
    exit 1
fi
# -------------------------------------------------------
SSH_OPT="-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null"
for i in $(seq 0 $(( $NUMBER - 1 )) ); do
    if [[ $1 == "undercloud" ]]; then
	NAME=$1
    else
	NAME=$1$i
    fi
    IPDEC="IPADDR=$IP"
    if [[ -e /var/lib/libvirt/images/$NAME.qcow2 ]]; then
	echo "Destroying old $NAME"
	if [[ $(sudo virsh list | grep $NAME) ]]; then
	    sudo virsh destroy $NAME
	fi
	sudo virsh undefine $NAME
	sudo rm -f /var/lib/libvirt/images/$NAME.qcow2
	sudo sed -i "/$IP.*/d" /etc/hosts
    fi
    sudo virt-clone --original=$SRC --name=$NAME --file /var/lib/libvirt/images/$NAME.qcow2

    sudo virsh setmaxmem $NAME $RAM --config
    sudo virsh setmem $NAME $RAM --config
    sudo virsh setvcpus $NAME $CPU --config --maximum
    sudo virsh setvcpus $NAME $CPU --config

    sudo virt-customize -a /var/lib/libvirt/images/$NAME.qcow2 --run-command "SRC_IP=\$(grep IPADDR /etc/sysconfig/network-scripts/ifcfg-eth1) ; sed -i s/\$SRC_IP/$IPDEC/g /etc/sysconfig/network-scripts/ifcfg-eth1"
    if [[ ! $(sudo virsh list | grep $NAME) ]]; then
	sudo virsh start $NAME
    fi
    echo "Waiting for $NAME to boot and allow to SSH at $IP"
    while [[ ! $(ssh $SSH_OPT root@$IP "uname") ]]
    do
	echo "No route to host yet; sleeping 30 seconds"
	sleep 30
    done
    ssh $SSH_OPT root@$IP "hostname $NAME.$DOM ; echo HOSTNAME=$NAME.$DOM >> /etc/sysconfig/network"
    ssh $SSH_OPT root@$IP "echo \"$IP    $NAME.$DOM        $NAME\" >> /etc/hosts "
    sudo sh -c "echo $IP    $NAME.$DOM        $NAME >> /etc/hosts"

    echo "$NAME is ready"
    ssh stack@$NAME "uname -a"
    echo ""
    echo "ssh stack@$NAME"
    echo ""

    # decrement the IP by one for the next loop
    TAIL=$(echo $IP | awk -F  "." '/1/ {print $4}')
    HEAD=$(echo $IP | sed s/$TAIL//g)
    TAIL=$(( TAIL - 1))
    IP=$HEAD$TAIL
done

if [[ $NAME == "undercloud" ]]; then
    F="undercloud.conf undercloud.sh poll.sh"
    tar cvfz undercloud.tar.gz $F >/dev/null 2>&1
    scp $SSH_OPT undercloud.tar.gz stack@$NAME:/home/stack/
    rm undercloud.tar.gz
    ssh $SSH_OPT stack@$NAME "tar xf undercloud.tar.gz ; rm undercloud.tar.gz"
    ssh $SSH_OPT stack@$NAME "sudo yum install -y tmux emacs-nox vim"
fi
