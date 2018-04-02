#!/bin/bash -x

#  373  virt-clone --connect qemu:///system --original template_centos_7 --name EL7TEMPLATE --file /var/lib/libvirt/images/EL7TEMPLATE.qcow2
#  374  virsh list
#  375  virsh list --all
#  376  virt-sysprep -d EL7TEMPLATE

#NODES="ose3-master1.test.example.com ose3-master2.test.example.com ose3-master3.test.example.com"
#NODES="$NODES ose3-node1.test.example.com ose3-node2.test.example.com"
#NODES="$NODES ose3-infra1.test.example.com ose3-infra2.test.example.com"
#NODES="$NODES ose3-lb.test.example.com"
#NODES="$NODES ose3-ansible.test.example.com"
source nodes.sh

TEMPLATE="template_centos_7"
IMAGE_DIR="/var/lib/libvirt/images"
IMAGE_PASSWORD="redhat1234"

function deletenode {
    echo "deleting $1"
    virsh dumpxml --domain $1 | fgrep 'source file'
    RC=$?
    if [[ $RC == 0 ]]; then
        SOURCE_FILE=$(virsh dumpxml --domain $1 | fgrep 'source file' | cut -d\' -f2)
        virsh shutdown --domain $1
        virsh destroy --domain $1
        virsh undefine --domain $1
        rm -f $SOURCE_FILE
    fi
}


for NODE in $NODES; do
    echo $NODE
    deletenode $NODE
done

rm inventory.admin
