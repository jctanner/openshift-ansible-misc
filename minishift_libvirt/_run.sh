#!/bin/bash

export SSH_AUTH_SOCK=0

./delete_minishift.sh
sudo ./make_node.sh
./create_admin_inventory.sh
ansible-playbook -v -i inventory.admin prepare_vms.yml
