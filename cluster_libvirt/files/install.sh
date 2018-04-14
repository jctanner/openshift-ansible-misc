#!/bin/bash

COMMON_ARGS="-i inventory/hosts.example"
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

#CBURL="https://gist.githubusercontent.com/sivel/2b0bc0c715fe8d341af195cf0f39849c/raw/ceec3140450bf6fbf16cd7283fb279dd8477b744/cgroup_memory_recap.py"
#CBURL="https://gist.githubusercontent.com/jctanner/bfc00e7a2b4fb0693a2b9617fed6326f/raw/3e045f099c92a0a193aa37e33d674df5c07e45f6/cgroup_memory_recap.py"
CBURL="https://raw.githubusercontent.com/sivel/ansible/cgroup-memory-profile-callback/lib/ansible/plugins/callback/cgroup_memory_recap.py"

curl -o callback_plugins/cgroup_memory_recap.py $CBURL
curl -o playbooks/callback_plugins/cgroup_memory_recap.py $CBURL

sed -i.bak 's/profile_tasks/profile_tasks, cgroup_memory_recap/' ansible.cfg
#sed -i.bak 's/profile_tasks/cgroup_memory_recap/' ansible.cfg
#exit 1

CGEXPORTS="ANSIBLE_CALLBACK_WHITELIST=cgroup_memory_recap"
CGEXPORTS="$CGEXPORTS CGROUP_MAX_MEM_FILE=/sys/fs/cgroup/memory/ansible_profile/memory.max_usage_in_bytes"
CGEXPORTS="$CGEXPORTS CGROUP_CUR_MEM_FILE=/sys/fs/cgroup/memory/ansible_profile/memory.usage_in_bytes"

export ANSIBLE_CALLBACK_WHITELIST=cgroup_memory_recap
export CGROUP_MAX_MEM_FILE=/sys/fs/cgroup/memory/ansible_profile/memory.max_usage_in_bytes
export CGROUP_CUR_MEM_FILE=/sys/fs/cgroup/memory/ansible_profile/memory.usage_in_bytes


cgexec -g memory:ansible_profile ansible-playbook $COMMON_ARGS playbooks/prerequisites.yml | tee -a /var/log/os_prereqs.log
RC=$?
if [[ $RC != 0 ]]; then
	exit $RC
fi

cgexec -g memory:ansible_profile ansible-playbook $COMMON_ARGS playbooks/deploy_cluster.yml | tee -a /var/log/os_deploy.log
RC=$?
if [[ $RC != 0 ]]; then
	exit $RC
fi
