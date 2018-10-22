#!/bin/bash
# hacky fix
cat <<EOF > /tmp/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.122.251    overcloud0.example.com        overcloud0
192.168.122.250    overcloud1.example.com        overcloud1
192.168.122.249    overcloud2.example.com        overcloud2
EOF

for S in `echo overcloud{0,1,2}`; do
    scp /tmp/hosts root@$S:/etc/hosts;
    ssh root@$S "cat /etc/hosts";
done
