#!/bin/bash

#HOSTS=$(cat /etc/hosts | fgrep "ose3" | awk '{print $2}')
source nodes.sh

cat /dev/null > inventory.admin
for HOST in $NODES; do
    echo "$HOST ansible_ssh_pass=redhat1234" >> inventory.admin
done
