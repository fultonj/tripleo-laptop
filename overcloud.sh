#!/usr/bin/env bash
# configure potential overcloud nodes to work with deployed-servers

if [[ ! -d ~/rpms ]]; then
    mkdir ~/rpms;
    url=https://trunk.rdoproject.org/centos7/current/
    rpm_name=$(curl $url | grep python2-tripleo-repos | sed -e 's/<[^>]*>//g' | awk 'BEGIN { FS = ".rpm" } ; { print $1 }')
    rpm=$rpm_name.rpm
    curl -f $url/$rpm -o ~/rpms/$rpm
fi

for OVER in $(grep overcloud /etc/hosts | grep -v \# | awk {'print $1'} ); do
    ssh $OVER -l root "hostname" || (echo "No ssh for root@$OVER; exiting."; exit 1)
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
	echo "DEFROUTE=yes" >> /tmp/eth0
	scp /tmp/eth0 root@$OVER:/etc/sysconfig/network-scripts/ifcfg-eth0
	ssh root@$OVER "chcon system_u:object_r:net_conf_t:s0 /etc/sysconfig/network-scripts/ifcfg-eth0"
	ssh root@$OVER "chmod 644 /etc/sysconfig/network-scripts/ifcfg-eth0"
	ssh root@$OVER "ifup eth0"
	ssh root@$OVER "sed -i '/DEFROUTE=yes.*/d' /etc/sysconfig/network-scripts/ifcfg-eth0"
	echo "overcloud default route should now be be 192.168.24.1 ..."
	ssh $OVER -l root "/sbin/ip route"
    fi

    echo  "Can overcloud reach undercloud Heat API and Swift Server?"
    ssh $OVER -l stack "curl -s 192.168.24.1:8000" | jq .  # should return json
    ssh $OVER -l stack "curl -s 192.168.24.1:8080" # should 404
    echo ""
    echo "404 above is expcted ^"
    echo ""

    scp -r ~/rpms/ stack@$OVER:/home/stack/
    ssh $OVER -l stack "sudo yum -y install rpms/*"
    ssh $OVER -l stack "sudo -E tripleo-repos current-tripleo-dev"
    ssh $OVER -l stack "sudo yum repolist"
    ssh $OVER -l stack "sudo yum -y install python-heat-agent*"
done
