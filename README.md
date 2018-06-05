# tripleo-laptop

- [centos.sh](centos.sh)
  - download centos cloud image
  - minamally modify it (e.g. remove cloud init, install ssh key)

- [clone.sh](clone.sh)
  - clones VM from centos named $1
  - updates /etc/hosts on localhost and undercloud if it exists

- [undercloud.sh](undercloud.sh)
  - install undercloud

- [overcloud.sh](overcloud.sh)
  - configure overcloud for deployment with [deployed_servers](https://docs.openstack.org/tripleo-docs/latest/install/advanced_deployment/deployed_server.html)
