# tripleo-laptop

- [centos.sh](centos.sh)
  - download centos cloud image
  - minamally modify it (e.g. remove cloud init, install ssh key)

- [undercloud.sh](undercloud.sh)
  - clone centos.sh to undercloud vm
  - install undercloud
  - snapshot undercloud

- [overcloud.sh](overcloud.sh)
  - clone centos.sh to overcloud vm
  - configure overcloud for deployment with [deployed_servers](https://docs.openstack.org/tripleo-docs/latest/install/advanced_deployment/deployed_server.html)
  - snapshot overcloud

