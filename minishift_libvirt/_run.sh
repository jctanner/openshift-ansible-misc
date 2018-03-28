#!/bin/bash

./delete_minishift.sh
./make_node.sh
./create_admin_inventory.sh
ansible-playbook -v -i inventory.admin prepare_vms.yml
