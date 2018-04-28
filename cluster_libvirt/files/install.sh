#!/bin/bash

function enable_memrecap {
    CBURL="https://raw.githubusercontent.com/sivel/ansible/cgroup-memory-profile-callback/lib/ansible/plugins/callback/cgroup_memory_recap.py"
    curl -o callback_plugins/cgroup_memory_recap.py $CBURL
    curl -o playbooks/callback_plugins/cgroup_memory_recap.py $CBURL
    export CGROUP_MAX_MEM_FILE=/sys/fs/cgroup/memory/ansible_profile/memory.max_usage_in_bytes
    export CGROUP_CUR_MEM_FILE=/sys/fs/cgroup/memory/ansible_profile/memory.usage_in_bytes
    PREFIX="$PREFIX cgexec -g memory:ansible_profile"

    if [[ -z $CALLBACKS ]]; then
        CALLBACKS="cgroup_memory_recap"
    else
        CALLBACKS="$CALLBACKS,cgroup_memory_recap"
    fi
}

function enable_vcr {
    # VCR
    VCRURL="https://raw.githubusercontent.com/jctanner/ansible-vcr/master"
    mkdir -p playbooks/connection_plugins
    touch playbooks/connection_plugins/__init__.py
    curl -o playbooks/callback_plugins/vcr.py $VCRURL/callback_plugins/vcr.py
    curl -o playbooks/connection_plugins/ansible_vcr.py $VCRURL/connection_plugins/ansible_vcr.py
    curl -o playbooks/connection_plugins/ssh.py $VCRURL/connection_plugins/ssh.py
    curl -o playbooks/connection_plugins/local.py $VCRURL/connection_plugins/local.py

    mkdir -p connection_plugins
    touch connection_plugins/__init__.py
    curl -o callback_plugins/vcr.py $VCRURL/callback_plugins/vcr.py
    curl -o connection_plugins/ansible_vcr.py $VCRURL/connection_plugins/ansible_vcr.py
    curl -o connection_plugins/local.py $VCRURL/connection_plugins/local.py
    curl -o connection_plugins/ssh.py $VCRURL/connection_plugins/ssh.py

    rm -rf /tmp/fixtures
    export ANSIBLE_RECORDER_MODE="record"

    if [[ -z $CALLBACKS ]]; then
        CALLBACKS="vcr"
    else
        CALLBACKS="$CALLBACKS,vcr"
    fi
}

ANSIBLE_CALLBACK_WHITELIST=cgroup_memory_recap
PREFIX=""
COMMON_ARGS="-i inventory/hosts.example"
COMMON_ARGS="$COMMON_ARGS -vvvv"
COMMON_ARGS="$COMMON_ARGS --user=root"
COMMON_ARGS="$COMMON_ARGS -e openshift_repos_enable_testing=true"
COMMON_ARGS="$COMMON_ARGS -e openshift_release=3.9"
COMMON_ARGS="$COMMON_ARGS -e openshift_disable_check=docker_storage,disk_availability,memory_availability"

#if [[ ! -d openshift-ansible ]]; then
#	git clone https://github.com/openshift/openshift-ansible
#fi

rm -rf openshift-ansible
git clone https://github.com/openshift/openshift-ansible

cd openshift-ansible
git checkout release-3.9

# FIX: c62bc3471a1aec6d407b3870fcb27fb8dc7bbb3b
# GOTO: 0fc46503be158b68502890598a4ee3e31c0e3bf0
#git checkout 0fc46503be158b68502890598a4ee3e31c0e3bf0
#git checkout 9e0f2db4fe181aa55677142de69a95155fc77e9e #Fri Apr 13 15:07:25 2018 -0500

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

# add the callback
mkdir callback_plugins
mkdir -p playbooks/callback_plugins

#enable_vcr
#enable_memrecap

if [[ ! -z $CALLBACKS ]]; then
    export ANSIBLE_CALLBACK_WHITELIST=$CALLBACKS
    sed -i.bak "s/profile_tasks/profile_tasks,$CALLBACKS/" ansible.cfg
fi

$PREFIX ansible-playbook $COMMON_ARGS playbooks/prerequisites.yml | tee -a /var/log/os_prereqs.log
RC=$?
if [[ $RC != 0 ]]; then
	exit $RC
fi

exit 1

$PREFIX ansible-playbook $COMMON_ARGS playbooks/deploy_cluster.yml | tee -a /var/log/os_deploy.log
RC=$?
if [[ $RC != 0 ]]; then
	exit $RC
fi
