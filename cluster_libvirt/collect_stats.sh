#!/bin/bash

source nodes.sh
ANSIBLE_NODE="ose3-ansible.test.example.com"


RESDIR="results"
THISRESDIR="$RESDIR/$(date +%F-%T)"

if [[ ! -d $THISRESDIR ]]; then
    mkdir -p $THISRESDIR
fi

cp nodes.sh $THISRESDIR/.
cp inventory.admin $THISRESDIR/.

for NODE in $NODES; do
    NODEDIR="$THISRESDIR/$NODE"
    if [[ ! -d $NODEDIR ]]; then
        mkdir -p $NODEDIR
    fi
    if [[ ! -d $NODEDIR/var.log ]]; then
        mkdir -p $NODEDIR/var.log
    fi
    
    scp -r root@$NODE:/etc $NODEDIR/etc
    scp -r root@$NODE:/var/log/* $NODEDIR/var.log
    scp root@$NODE:/tmp/ansible.log $NODEDIR/.
    scp root@$NODE:/openshift-ansible/inventory/hosts.example $NODEDIR/.
    ssh root@$NODE 'sar -r' > $NODEDIR/sar.txt
    ssh root@$NODE 'ps aux' > $NODEDIR/ps_aux.txt
    ssh root@$NODE 'ps auxf' > $NODEDIR/ps_auxf.txt
    ssh root@$NODE 'pstree -a' > $NODEDIR/pstree_a.txt
    ssh root@$NODE 'docker images -a' > $NODEDIR/docker_images.txt
    ssh root@$NODE 'docker ps -a' > $NODEDIR/docker_ps.txt
    ssh root@$NODE 'ansible --version' > $NODEDIR/ansible.version
    ssh root@$NODE 'rpm -qa' > $NODEDIR/rpms.txt
    ssh root@$NODE 'yum repolist' > $NODEDIR/yumrepos.txt

    ssh root@$NODE 'cd openshift-ansible; git log' > $NODEDIR/commit_root.log
    ssh root@$NODE 'cd /home/admin/openshift-ansible; git log' > $NODEDIR/commit_admin.log

    if [[ ! -d $NODEDIR/docker ]]; then
       mkdir $NODEDIR/docker
    fi 

    for CID in $(ssh root@$NODE 'docker ps -a' | awk '{print $1}' | fgrep -v CONTAINER); do
        ssh root@$NODE "docker inspect $CID 2>&1" | tee -a $NODEDIR/docker/$CID.json
        ssh root@$NODE "docker logs $CID 2>&1" | tee -a  $NODEDIR/docker/$CID.log
    done

done
