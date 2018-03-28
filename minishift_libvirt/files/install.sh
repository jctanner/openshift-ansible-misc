#!/bin/bash

COMMON_ARGS="-i inventory/hosts.localhost"
COMMON_ARGS="$COMMON_ARGS -e openshift_repos_enable_testing=true"
COMMON_ARGS="$COMMON_ARGS -e openshift_release=3.9"
COMMON_ARGS="$COMMON_ARGS -e openshift_disable_check=docker_storage,disk_availability,memory_availability"

if [[ ! -d openshift-ansible ]]; then
	git clone https://github.com/openshift/openshift-ansible
fi

cd openshift-ansible
git checkout release-3.9

ansible-playbook $COMMON_ARGS playbooks/prerequisites.yml
RC=$?
if [[ $RC != 0 ]]; then
	exit $RC
fi

ansible-playbook $COMMON_ARGS playbooks/deploy_cluster.yml
RC=$?
if [[ $RC != 0 ]]; then
	exit $RC
fi
