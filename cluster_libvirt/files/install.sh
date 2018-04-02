#!/bin/bash

COMMON_ARGS="-i inventory/hosts.example"
COMMON_ARGS="$COMMON_ARGS -e openshift_repos_enable_testing=true"
COMMON_ARGS="$COMMON_ARGS -e openshift_release=3.9"
COMMON_ARGS="$COMMON_ARGS -e openshift_disable_check=docker_storage,disk_availability,memory_availability"

if [[ ! -d openshift-ansible ]]; then
	git clone https://github.com/openshift/openshift-ansible
fi

cd openshift-ansible
git checkout release-3.9

# logging is not in by default
sed -i.bak 's/#log_path/log_path/' ansible.cfg

# bump the inventory
cp ~/nodes.sh .
cp ~/edit_os_inv.sh .
./edit_os_inv.sh
RC=$?
if [[ $RC != 0 ]]; then
	exit $RC
fi

ansible-playbook $COMMON_ARGS playbooks/prerequisites.yml | tee -a /var/log/os_prereqs.log
RC=$?
if [[ $RC != 0 ]]; then
	exit $RC
fi

ansible-playbook $COMMON_ARGS playbooks/deploy_cluster.yml | tee -a /var/log/os_deploy.log
RC=$?
if [[ $RC != 0 ]]; then
	exit $RC
fi
