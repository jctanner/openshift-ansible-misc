#!/bin/bash

source nodes.sh
export NODES=$NODES

WORKERS_COUNT=$(echo $NODES | python -c 'import os; nodes=[x for x in os.environ["NODES"].split() if x.startswith("ose3-node")]; print(len(nodes));')

echo "setting inventory size to $WORKERS_COUNT"


# openshift-ansible/inventory/hosts.example
# ose3-node[1:2].test.example.com openshift_node_labels="{'region': 'primary', 'zone': 'default'}"
sed -i.bak "s/node\[1\:2\]/node\[1\:$WORKERS_COUNT\]/" inventory/hosts.example
