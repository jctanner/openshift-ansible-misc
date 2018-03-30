#!/bin/bash

source nodes.sh
ANSIBLE_NODE="ose3-ansible.test.example.com"


RESDIR="results"
THISRESDIR="$RESDIR/$(date +%F-%T)"

if [[ ! -d $THISRESDIR ]]; then
    mkdir -p $THISRESDIR
fi

cp nodes.sh $THISRESDIR/.
#scp root@$ANSIBLE_NODE:/tmp/ansible.log $THISRESDIR/
#ssh root@$ANSIBLE_NODE 'sar -r' > $THISRESDIR/ansible_sar.txt

for NODE in $NODES; do
    NODEDIR="$THISRESDIR/$NODE"
    if [[ ! -d $NODEDIR ]]; then
        mkdir -p $NODEDIR
    fi
    if [[ ! -d $NODEDIR/var.log ]]; then
        mkdir -p $NODEDIR/var.log
    fi
    
    scp -r root@$NODE:/var/log/* $NODEDIR/var.log
    scp root@$NODE:/tmp/ansible.log $NODEDIR/.
    ssh root@$NODE 'sar -r' > $NODEDIR/sar.txt
    ssh root@$NODE 'ps aux' > $NODEDIR/ps_aux.txt
    ssh root@$NODE 'ps auxf' > $NODEDIR/ps_auxf.txt
    ssh root@$NODE 'pstree -a' > $NODEDIR/pstree_a.txt
    ssh root@$NODE 'docker images -a' > $NODEDIR/docker_images.txt
    ssh root@$NODE 'docker ps -a' > $NODEDIR/docker_ps.txt
done
