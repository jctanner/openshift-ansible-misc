#!/bin/bash -x

#  373  virt-clone --connect qemu:///system --original template_centos_7 --name EL7TEMPLATE --file /var/lib/libvirt/images/EL7TEMPLATE.qcow2
#  374  virsh list
#  375  virsh list --all
#  376  virt-sysprep -d EL7TEMPLATE

#NODES="ose3-master1.test.example.com ose3-master2.test.example.com ose3-master3.test.example.com"
#NODES="$NODES ose3-node1.test.example.com ose3-node2.test.example.com"
#NODES="$NODES ose3-infra1.test.example.com ose3-infra2.test.example.com"
#NODES="$NODES ose3-lb.test.example.com"
#NODES="$NODES ose3-nfs-ansible.test.example.com"
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


function create {
    echo "creating $1"
    virt-clone --connect qemu:///system --original $TEMPLATE --name $1 --file $IMAGE_DIR/$1.qcow2
    if [[ $string = *"master"* ]]; then
        virsh setmaxmem $1 12G --config
        virsh setmem $1 12G --config
    elif [[ $string = *"ansible"* ]]; then
        virsh setmaxmem $1 16G --config
        virsh setmem $1 16G --config
    else
        virsh setmaxmem $1 4G --config
        virsh setmem $1 4G --config
    fi
    virt-sysprep -d $1 --hostname $1 --root-password password:$IMAGE_PASSWORD
    virsh start $1
}


#function getvmip {
#    SHORT_NAME=$(echo $1 | cut -d\. -f1)
#    THISIP=$(virsh net-dhcp-leases default | fgrep $SHORT_NAME | awk '{print $5}' | cut -d\/ -f1)
#    echo $THISIP
#}


function getvmip {
    THISIP=$(virsh domifaddr $1 | fgrep 'ipv4' | awk '{print $NF}' | cut -d\/ -f1)
    echo $THISIP
}


function set_hostname_in_hosts {
    fgrep $1 /etc/hosts 
    RC=$?
    if [[ $RC != 0 ]]; then
        echo "$2 $1" >> /etc/hosts
    else
        sed -i.bak "s/.*${1}//" /etc/hosts
        echo "$2 $1" >> /etc/hosts
    fi
}

for NODE in $NODES; do
    echo $NODE
    deletenode $NODE
done


for NODE in $NODES; do
    echo $NODE
    create $NODE
done

for NODE in $NODES; do
    echo $NODE
    NODEIP=$(getvmip $NODE)
    while [[ $NODEIP == "" ]]; do
        echo "waiting for $NODE to obtain an ip ..."
        sleep 2
        NODEIP=$(getvmip $NODE)
    done
    echo "$NODE $NODEIP"
    set_hostname_in_hosts $NODE $NODEIP
done

# this forces libvirt's dnsmasq to pick up the hosts entries and make them resolvable
systemctl restart libvirtd

