#!/usr/bin/env bash
# configure potential overcloud nodes to work with deployed-servers
for OVER in $(grep overcloud /etc/hosts | grep -v \# | awk {'print $1'} ); do 
    ssh $OVER -l stack "hostname" || (echo "No ssh for stack@over; exiting."; exit 1)
    echo  "Can overcloud reach undercloud Heat API and Swift Server?"
    ssh $OVER -l stack "curl -s 192.168.24.1:8000" | jq .  # should return json
    ssh $OVER -l stack "curl -s 192.168.24.1:8080" # should 404
    echo ""
    echo "404 above is expcted ^"
    echo ""
    echo "overcloud default route should be 192.168.24.1 ..."
    echo ""
    ssh $OVER -l stack "/sbin/ip route | grep default"
    # echo "If necessary, fix with fix with..."
    # echo "ip route add default via 192.168.24.1"
    # ssh $OVER -l stack "echo GATEWAY='192.168.24.1' > /tmp/etc-sysconfig-network"
    # ssh $OVER -l stack "mv /tmp/etc-sysconfig-network /etc/sysconfig/network"
    # ssh $OVER -l stack "/sbin/ip route add default via 192.168.24.1"
    # ssh $OVER -l stack "/sbin/ip route"

    ssh $OVER -l stack "if [[ ! -d ~/rpms ]]; then mkdir ~/rpms; fi"
    ssh $OVER -l stack "url=https://trunk.rdoproject.org/centos7/current/ ; rpm_name=$(curl $url | grep python2-tripleo-repos | sed -e 's/<[^>]*>//g' | awk 'BEGIN { FS = \".rpm\" } ; { print $1 }') ; rpm=$rpm_name.rpm ; curl -f $url/$rpm -o ~/rpms/$rpm ; sudo yum install -y ~/rpms/$rpm"
    ssh $OVER -l stack "sudo -E tripleo-repos current-tripleo-dev"
    ssh $OVER -l stack "sudo yum repolist"
    ssh $OVER -l stack "sudo yum -y install python-heat-agent*"
done
