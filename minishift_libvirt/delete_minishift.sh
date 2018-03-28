#!/bin/bash -x

NODES="ose3-master1.test.example.com"

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
