#!/usr/bin/env bash
# -------------------------------------------------------
IP=192.168.122.253
NAME=centos
RAM=8192
CPU=1
PASSWD=redhat
DOM=example.com
# IMG=CentOS-7-x86_64-GenericCloud.qcow2
# URL=https://cloud.centos.org/centos/7/images/$IMG.xz
# OS=rhel7
# IMG=CentOS-Stream-GenericCloud-8-20210210.0.x86_64.qcow2
# URL=https://cloud.centos.org/centos/8-stream/x86_64/images/$IMG
# OS=centos-stream8
VERSION=9
IMG=CentOS-Stream-GenericCloud-9-20210830.0.x86_64.qcow2
URL=https://cloud.centos.org/centos/9-stream/x86_64/images/$IMG
OS=centos-stream9

# OS=rhel8.10
# OS=rhel9.4
# -------------------------------------------------------
if [[ ! -e ~/.ssh/id_rsa.pub ]]; then
    echo "Please run ssh-keygen"
    exit 1
else
    # KEY=$(cat ~/.ssh/id_ed25519.pub)
    KEY=$(cat ~/.ssh/id_rsa.pub)
fi
if [[ ! -e ~/.ssh/config ]]; then
    cat /dev/null > ~/.ssh/config
    echo "StrictHostKeyChecking no" >> ~/.ssh/config
    echo "UserKnownHostsFile=/dev/null" >> ~/.ssh/config
    echo "LogLevel ERROR" >> ~/.ssh/config
    chmod 0600 ~/.ssh/config
    chmod 0700 ~/.ssh
fi
SSH_OPT="-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null"
# -------------------------------------------------------
sudo yum install -y libguestfs-tools xz libvirt virt-install
if [[ ! $(sudo systemctl status libvirtd) ]]; then
   sudo systemctl start libvirtd
fi
# -------------------------------------------------------
if [[ ! $(sudo ls /var/lib/libvirt/images/$IMG) ]]; then
    echo "Downloading $URL"
    curl --remote-name --location --insecure $URL -o $IMG
    # unxz $IMG.xz
    sudo cp $IMG /var/lib/libvirt/images/
    # to download newer image run 'sudo rm /var/lib/libvirt/images/$IMG'
fi
# -------------------------------------------------------
if [[ ! $(sudo virsh net-list | grep ctlplane) ]]; then
    BR_NAME=ctlplane
    MAC=52:54:00:e5:01:42
    echo "Creating virtual bridge $BR_NAME"
    
    cat /dev/null > /tmp/net.xml
    echo "<network>" >> /tmp/net.xml
    echo "<name>$BR_NAME</name>" >> /tmp/net.xml
    echo "<bridge name='$BR_NAME' stp='off' delay='0'/>" >> /tmp/net.xml
    echo "<mac address='$MAC'/>" >> /tmp/net.xml
    echo "</network>" >> /tmp/net.xml
    
    sudo virsh net-define /tmp/net.xml
    sudo virsh net-start $BR_NAME
    sudo virsh net-autostart $BR_NAME
fi
# -------------------------------------------------------
if [[ -e /var/lib/libvirt/images/$NAME.qcow2 ]]; then
    echo "Destroying old $NAME"
    if [[ $(sudo virsh list | grep $NAME) ]]; then
	sudo virsh destroy $NAME
    fi
    sudo virsh undefine $NAME
    sudo rm -f /var/lib/libvirt/images/$NAME.qcow2
fi
# -------------------------------------------------------
echo "Building new $NAME"
pushd /var/lib/libvirt/images/
sudo qemu-img info $IMG
SIZE=$(sudo qemu-img info /var/lib/libvirt/images/$IMG | grep virtual | awk {'print $3'} | grep G | sed -e s/G// -e s/\.0//g)
if [[ $SIZE -lt 37 ]]; then  # if we have a new base cloud image grow the filesystem
    echo "Customizing base $IMG"
    sudo virt-filesystems --long -h --all -a $IMG
    sudo qemu-img resize $IMG +30G
    # -e:   Move backup GPT data structures to the end of the disk
    # -d 1: Delete the first partition
    # -N 1: Create a new partition using remainder of the disk
    sudo virt-customize -a $IMG --run-command 'sgdisk -e /dev/sda && sgdisk -d 1 /dev/sda && sgdisk -N 1 /dev/sda'
    # sudo virt-customize -a $IMG --run-command 'echo -e "d\nn\n\n\n\n\nw\n" | fdisk /dev/sda' 2> /dev/null
    sudo virt-customize -a $IMG --run-command 'xfs_growfs /'
    sudo virt-filesystems --long -h --all -a $IMG
    # sudo virt-customize -a $IMG --run-command 'cp /etc/sysconfig/network-scripts/ifcfg-eth{0,1} && sed -i s/DEVICE=.*/DEVICE=eth1/g /etc/sysconfig/network-scripts/ifcfg-eth1'
else
    echo "File system size: $SIZE, not growing base image"
fi
echo "Creating $NAME from base image $IMG"
sudo qemu-img create -f qcow2 -F qcow2 -b $IMG $NAME.qcow2
if [[ ! -e $NAME.qcow2 ]]; then
    echo "$NAME.qcow2 is missing. Exiting."
    exit 1
fi
sudo virt-customize -a $NAME.qcow2 --run-command 'dnf remove cloud-init* -y'
sudo virt-customize -a $NAME.qcow2 --root-password password:$PASSWD
sudo virt-customize -a $NAME.qcow2  --hostname $NAME.$DOM
sudo virt-customize -a $NAME.qcow2 --run-command "echo 'UseDNS no' >> /etc/ssh/sshd_config"
# sudo virt-customize -a $NAME.qcow2 --run-command 'sed -i -e "s/ONBOOT=.*/ONBOOT=no/g" /etc/sysconfig/network-scripts/ifcfg-eth0'
# sudo virt-customize -a $NAME.qcow2 --run-command 'sed -i -e "s/BOOTPROTO=.*/BOOTPROTO=none/g" -e "s/USERCTL=.*/IPADDR=THE_IP/g" -e "s/PEERDNS=.*/NETMASK=255.255.255.0/g" -e "s/IPV6INIT=.*/GATEWAY=192.168.122.1/g" -e "s/PERSISTENT_DHCLIENT=.*/DEFROUTE=yes/g" /etc/sysconfig/network-scripts/ifcfg-eth1'
# if [[ ! $VERSION -eq 9 ]]; then
#    sudo virt-customize -a $NAME.qcow2 --run-command 'sed -i -e "s/BOOTPROTOv6=.*/NM_CONTROLLED=no/g" /etc/sysconfig/network-scripts/ifcfg-eth1'
# fi

# sudo virt-customize -a $NAME.qcow2 --run-command "sed -i s/THE_IP/$IP/g /etc/sysconfig/network-scripts/ifcfg-eth1"
sudo virt-customize -a $NAME.qcow2 --run-command "mkdir /root/.ssh/; chmod 700 /root/.ssh/; echo $KEY > /root/.ssh/authorized_keys; chmod 600 /root/.ssh/authorized_keys; chcon system_u:object_r:ssh_home_t:s0 /root/.ssh ; chcon unconfined_u:object_r:ssh_home_t:s0 /root/.ssh/authorized_keys "
popd

# -------------------------------------------------------
sudo virt-install --ram $RAM --vcpus $CPU --os-variant $OS --disk path=/var/lib/libvirt/images/$NAME.qcow2,device=disk,bus=virtio,format=qcow2 --import --noautoconsole --vnc --network network:ctlplane --network network:default --name $NAME
sleep 10
if [[ ! $(sudo virsh list | grep $NAME) ]]; then
    echo "Cannot find new $NAME; Exiting."
    exit 1
fi
echo "Waiting for $NAME to boot and allow to SSH at $IP"
while [[ ! $(ssh $SSH_OPT root@$IP "uname") ]]
do
    echo "No route to host yet; sleeping 30 seconds"
    sleep 30
done
echo "SSH to $IP is working."
echo "Updating /etc/hosts"
ssh $SSH_OPT root@$IP 'echo "$IP    $NAME.$DOM        $NAME" >> /etc/hosts'
echo "Creating stack user"
ssh $SSH_OPT root@$IP 'useradd stack'
ssh $SSH_OPT root@$IP 'echo "stack ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/stack'
ssh $SSH_OPT root@$IP 'chmod 0440 /etc/sudoers.d/stack'
ssh $SSH_OPT root@$IP "mkdir /home/stack/.ssh/; chmod 700 /home/stack/.ssh/; echo $KEY > /home/stack/.ssh/authorized_keys; chmod 600 /home/stack/.ssh/authorized_keys; chcon system_u:object_r:ssh_home_t:s0 /home/stack/.ssh ; chcon unconfined_u:object_r:ssh_home_t:s0 /home/stack/.ssh/authorized_keys; chown -R stack:stack /home/stack/.ssh/ "
ssh $SSH_OPT root@$IP "echo nameserver 192.168.122.1 > /etc/resolv.conf"
echo "$IP is ready"
ssh $SSH_OPT stack@$IP "uname -a"
echo "Shutting $NAME down"
ssh $SSH_OPT root@$IP "init 0"
