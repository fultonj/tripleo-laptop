#!/usr/bin/env bash

source ~/stackrc

if [[ ! -d ~/templates ]]; then
    ln -s /usr/share/openstack-tripleo-heat-templates templates
fi

time openstack overcloud deploy --templates ~/templates \
     -r ~/tht/all_in_one.yaml \
     -e ~/templates/environments/low-memory-usage.yaml \
     -e ~/templates/environments/disable-telemetry.yaml \
     -e ~/templates/environments/deployed-server-environment.yaml \
     -e ~/templates/environments/docker.yaml \
     -e ~/docker_registry.yaml \
     -e ~/templates/environments/deployed-server-bootstrap-environment-centos.yaml \
     -e ~/tht/ctlplane-assignments.yaml \
     --disable-validations
