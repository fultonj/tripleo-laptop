# tripleo-laptop

[Quickstart](https://docs.openstack.org/tripleo-quickstart/latest/getting-started.html)
is better, but doesn't work on my T460s Fedora laptop. These scripts
let me use [deployed servers](https://docs.openstack.org/tripleo-docs/latest/install/advanced_deployment/deployed_server.html) while traveling.

- [centos.sh](centos.sh)
  - download centos cloud image
  - minamally modify it (e.g. remove cloud init, install ssh key)
  - (5 minutes or less)

- [clone.sh](clone.sh)
  - clones VM from centos named $1
  - updates /etc/hosts on localhost and undercloud if it exists
  - (5 minutes or less)
  
- [undercloud.sh](undercloud.sh) 
  - install undercloud (run on undercloud VM)
  - (20 minutes to install undercloud + 35 minutes to mirror docker repos)

- [overcloud.sh](overcloud.sh)
  - configure overcloud for deployment with [deployed_servers](https://docs.openstack.org/tripleo-docs/latest/install/advanced_deployment/deployed_server.html)
  - (5 minutes or less)

- [deploy.sh](deploy.sh)
  - deploy simple overcloud (run on undercloud VM)
  - snapshot VMs before running and return to snapshot to redeploy
  - (deployed overcloud in 48 minutes)
