#!/bin/bash

source ~/stackrc 
export OVERCLOUD_ROLES="Controller"
export Controller_hosts="192.168.24.2"
/usr/share/openstack-tripleo-heat-templates/deployed-server/scripts/get-occ-config.sh

OVER=$Controller_hosts
ssh $OVER -l stack "sudo ls -lhtr /var/lib/heat-config/heat-config-script/"
