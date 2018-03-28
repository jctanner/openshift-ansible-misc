#!/bin/bash

export SSH_AUTH_SOCK=0

sudo ./delete_minishift.sh
RC=$?
if [[ $RC != 0 ]]; then
    exit $RC
fi

sudo ./make_node.sh
RC=$?
if [[ $RC != 0 ]]; then
    exit $RC
fi

ssh-keygen -R ose3-master1.test.example.com

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

