#!/bin/bash

export SSH_AUTH_SOCK=0

#NODES="ose3-master1.test.example.com ose3-master2.test.example.com ose3-master3.test.example.com"
#NODES="$NODES ose3-node1.test.example.com ose3-node2.test.example.com" 
#NODES="$NODES ose3-infra1.test.example.com ose3-infra2.test.example.com"
#NODES="$NODES ose3-lb.test.example.com"
#NODES="$NODES ose3-nfs-ansible.test.example.com"
source nodes.sh

sudo ./delete_openshift_cluster.sh
RC=$?
if [[ $RC != 0 ]]; then
    exit $RC
fi

sudo ./make_openshift_cluster.sh
RC=$?
if [[ $RC != 0 ]]; then
    exit $RC
fi

for NODE in $NODES; do
	ssh-keygen -R $NODE
done

./create_admin_inventory.sh
RC=$?
if [[ $RC != 0 ]]; then
    exit $RC
fi

ansible-playbook -v -i inventory.admin prepare_vms.yml
RC=$?
if [[ $RC != 0 ]]; then
    exit $RC
fi

ssh admin@ose3-ansible.test.example.com '/home/admin/install.sh'

./collect_stats.sh
