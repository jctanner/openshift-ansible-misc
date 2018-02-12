#!/bin/bash

HOSTS=$(cat /etc/hosts | fgrep "ose3" | awk '{print $2}')

cat /dev/null > inventory.admin
for HOST in $HOSTS; do
    echo "$HOST ansible_ssh_pass=redhat1234" >> inventory.admin
done
