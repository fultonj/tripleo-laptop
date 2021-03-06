#!/usr/bin/env bash
# configure potential overcloud nodes to work with deployed-servers

if [[ ! -d ~/rpms ]]; then
    mkdir ~/rpms;
    url=https://trunk.rdoproject.org/centos7/current/
    rpm_name=$(curl $url | grep python2-tripleo-repos | sed -e 's/<[^>]*>//g' | awk 'BEGIN { FS = ".rpm" } ; { print $1 }')
    rpm=$rpm_name.rpm
    curl -f $url/$rpm -o ~/rpms/$rpm
fi

KEY=$(ssh stack@undercloud "cat /home/stack/.ssh/id_rsa.pub")
if [[ ! $KEY ]]; then
    echo "Unable to retrieve stack@undercloud's public SSH key. Aborting."
    exit 1
fi

for OVER in $(grep overcloud /etc/hosts | grep -v \# | awk {'print $1'} ); do
    HOSTNAME=$(ssh $OVER -l root "hostname") || (echo "No ssh for root@$OVER; exiting."; exit 1)
    ETH0_UP=$(ssh root@$OVER "ip a s eth0 | grep 192.168.24 | wc -l")
    if [[ $ETH0_UP -eq 0 ]]; then
	IPADDR=$(ssh root@$OVER "grep IPADDR /etc/sysconfig/network-scripts/ifcfg-eth1 | sed s/122/24/g")
	echo $IPADDR
	echo "Bringing up eth0 and configuring it for default route"
	cat /dev/null > /tmp/eth0
	echo "DEVICE=eth0" >> /tmp/eth0
	echo "ONBOOT=yes" >> /tmp/eth0
	echo "TYPE=Ethernet" >> /tmp/eth0
	echo "$IPADDR" >> /tmp/eth0
	echo "PREFIX=24" >> /tmp/eth0
	echo "GATEWAY=192.168.24.1" >> /tmp/eth0
	echo "DEFROUTE=yes" >> /tmp/eth0
	scp /tmp/eth0 root@$OVER:/etc/sysconfig/network-scripts/ifcfg-eth0
	ssh root@$OVER "chcon system_u:object_r:net_conf_t:s0 /etc/sysconfig/network-scripts/ifcfg-eth0"
	ssh root@$OVER "chmod 644 /etc/sysconfig/network-scripts/ifcfg-eth0"
	ssh root@$OVER "ifup eth0"
	ssh root@$OVER "sed -i '/DEFROUTE=yes.*/d' /etc/sysconfig/network-scripts/ifcfg-eth1"
	ssh root@$OVER "sed -i '/GATEWAY.*/d' /etc/sysconfig/network-scripts/ifcfg-eth1"
	ssh $OVER -l root "echo HOSTNAME=$HOSTNAME >> /etc/sysconfig/network"
	echo "overcloud default route should now be be 192.168.24.1 ..."
	ssh $OVER -l root "/sbin/ip route"
    fi

    ssh root@$OVER 'useradd heat-admin'
    ssh root@$OVER 'echo "heat-admin ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/heat-admin'
    ssh root@$OVER 'chmod 0440 /etc/sudoers.d/heat-admin'
    ssh root@$OVER "mkdir /home/heat-admin/.ssh/; chmod 700 /home/heat-admin/.ssh/; echo $KEY > /home/heat-admin/.ssh/authorized_keys; chmod 600 /home/heat-admin/.ssh/authorized_keys; chcon system_u:object_r:ssh_home_t:s0 /home/heat-admin/.ssh ; chcon unconfined_u:object_r:ssh_home_t:s0 /home/heat-admin/.ssh/authorized_keys; chown -R heat-admin:heat-admin /home/heat-admin/.ssh/ "

    scp -r ~/rpms/ stack@$OVER:/home/stack/
    ssh $OVER -l stack "sudo yum -y install rpms/*"
    ssh $OVER -l stack "sudo -E tripleo-repos current-tripleo-dev"
    ssh $OVER -l stack "sudo yum repolist"
    ssh $OVER -l stack "sudo yum -y install python-heat-agent*"
done
