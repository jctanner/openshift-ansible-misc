#!/bin/bash

source nodes.sh
ANSIBLE_NODE="ose3-ansible.test.example.com"
SSHARGS="-o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null"


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

    ssh-keygen -R $NODE 
    NODEIP=$(grep -m1 $NODE /etc/hosts | awk '{print $1}')
    ssh-keygen -R $NODEIP

    scp $SSHARGS -r root@$NODE:/etc $NODEDIR/etc
    scp $SSHARGS -r root@$NODE:/var/log/* $NODEDIR/var.log
    scp $SSHARGS root@$NODE:/tmp/ansible.log $NODEDIR/.
    scp $SSHARGS root@$NODE:/openshift-ansible/inventory/hosts.example $NODEDIR/.
    ssh $SSHARGS root@$NODE 'sar -r' > $NODEDIR/sar.txt
    ssh $SSHARGS root@$NODE 'ps aux' > $NODEDIR/ps_aux.txt
    ssh $SSHARGS root@$NODE 'ps auxf' > $NODEDIR/ps_auxf.txt
    ssh $SSHARGS root@$NODE 'pstree -a' > $NODEDIR/pstree_a.txt
    ssh $SSHARGS root@$NODE 'docker images -a' > $NODEDIR/docker_images.txt
    ssh $SSHARGS root@$NODE 'docker ps -a' > $NODEDIR/docker_ps.txt
    ssh $SSHARGS root@$NODE 'ansible --version' > $NODEDIR/ansible.version
    ssh $SSHARGS root@$NODE 'rpm -qa' > $NODEDIR/rpms.txt
    ssh $SSHARGS root@$NODE 'yum repolist' > $NODEDIR/yumrepos.txt

    ssh $SSHARGS root@$NODE 'cd openshift-ansible; git log' > $NODEDIR/commit_root.log
    ssh $SSHARGS root@$NODE 'cd /home/admin/openshift-ansible; git log' > $NODEDIR/commit_admin.log

    if [[ ! -d $NODEDIR/docker ]]; then
       mkdir $NODEDIR/docker
    fi 

    for CID in $(ssh $SSHARGS root@$NODE 'docker ps -a' | awk '{print $1}' | fgrep -v CONTAINER); do
        ssh $SSHARGS root@$NODE "docker inspect $CID 2>&1" | tee -a $NODEDIR/docker/$CID.json
        ssh $SSHARGS root@$NODE "docker logs $CID 2>&1" | tee -a  $NODEDIR/docker/$CID.log
    done

done
