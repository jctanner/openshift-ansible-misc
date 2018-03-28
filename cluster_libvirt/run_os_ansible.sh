#!/bin/bash

UPSTREAM_INV="https://raw.githubusercontent.com/sdodson/openshift-ansible/e16158c2ec95ed4ccc3fa8888b78df2776c50649/inventory/hosts.example"

EXTRA_ARGS="-vvv"
#EXTRA_ARGS="$EXTRA_ARGS --forks=1"

if [ ! -d openshift-ansible ]; then
    git clone https://github.com/openshift/openshift-ansible
fi

cd openshift-ansible
cd inventory
mv hosts.example hosts.example.orig
wget https://raw.githubusercontent.com/sdodson/openshift-ansible/e16158c2ec95ed4ccc3fa8888b78df2776c50649/inventory/hosts.example
sed -i.bak 's/ose-lb/ose3-lb/g' hosts.example
sed -i.bak 's/openshift_master_cluster_hostname=ose3-lb.test.example./openshift_master_cluster_hostname=ose3-lb.test.example.com/g' hosts.example
echo 'openshift_disable_check=disk_availability,memory_availability,docker_storage' >> hosts.example
cd ..

#exit 0

ansible-playbook $EXTRA_ARGS -i inventory/hosts.example playbooks/prerequisites.yml
RC=$?
if [[ $RC != 0 ]]; then
    exit $RC
fi

#exit 0

ansible-playbook $EXTRA_ARGS -i inventory/hosts.example playbooks/deploy_cluster.yml
RC=$?
if [[ $RC != 0 ]]; then
    exit $RC
fi
