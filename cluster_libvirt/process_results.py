#!/usr/bin/env python

import glob
import os
import subprocess
import sys
import re

import numpy as np
from scipy.stats import linregress
from operator import itemgetter


def run_command(cmd):
    p = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        shell=True
    )

    (so, se) = p.communicate()
    return (p.returncode, so, se)


class ResultsProcessor(object):
    def __init__(self, results_directory):
        self.results_directory = results_directory
        self.index_data()

    def index_data(self):

        idata = {}

        timedirs = glob.glob('%s/*' % self.results_directory)
        timedirs = sorted(timedirs)

        for td in timedirs:
            ansible_version = self.get_ansible_version(td)
            cluster_uuid = self.get_cluster_uuid(td)
            cluster_nodes = self.get_cluster_nodes(td)
            cluster_commit = self.get_cluster_commit_info(td)
            install_success = self.get_install_result(td)
            if not install_success:
                failure_message = self.get_failure_info(td)
            else:
                failure_message = {}
            (emax, pdata) = self.get_profiler_data(td)
            if not pdata:
                continue

            sardata = self.get_sar_data(td)

            idata[td] = {
                'ansible_version': ansible_version,
                'cluster_uuid': cluster_uuid,
                'cluster_size': len(list(cluster_nodes)),
                'ose_commit': cluster_commit.copy(),
                'install_success': install_success,
                'failure_message': failure_message,
                'execution_maximum': emax,
                'profiler_data': pdata[:],
                'sardata': sardata.copy(),
            }

            # compute the task with the highest mem usage
            if not pdata:
                idata[td]['peak_task'] = {}
            else:
                idata[td]['peak_task'] = sorted(pdata, key=itemgetter('mem'))[-1]

            # compute peak kbmemused
            if not sardata:
                idata[td]['peak_sar'] = {}
            else:
                idata[td]['peak_sar'] = self.get_sar_peak(sardata)

        self.idata = idata.copy()

    ###########################################################################
    #   ANALYZERS
    ###########################################################################

    def compare_task_sequence(self):

        task_data = {}

        for k,v in self.idata.items():
            tasks = v['profiler_data'][:]

            for idx,x in enumerate(tasks):
                tn = '%s|%s' % (x['role'], x['task'])
                if tn not in task_data:
                    task_data[tn] = {
                        'observations': []
                    }
                # the 9 node results skew the data
                if v['cluster_size'] == 9:
                    continue
                task_data[tn]['observations'].append((v['cluster_size'], x['mem']))

        # capture the mean mem per node for each task
        mean_ratios = []

        # divide total mem by the number of nodes
        for k,v in task_data.items():
            obs = v['observations'][:]
            obs_ratios = [x[1] / x[0] for x in obs]
            obs_mean = np.mean(obs_ratios)
            mean_ratios.append(obs_mean)

        # make some baseline stats
        mem_med = np.median(mean_ratios)
        mem_mean = np.mean(mean_ratios)
        mem_std = np.std(mean_ratios)

        for k,v in task_data.items():
            obs = v['observations'][:]
            obs = sorted(obs, key=itemgetter(0))
            obs_ratios = [x[1] / x[0] for x in obs]

            if np.mean(obs_ratios) >= (mem_std * 3):

                print('###################################')
                print('task: ' + k)
                print('nodecount+memused observations: ' + str(obs))
                print('nodecount+memused ratio: ' + str(obs_ratios))

                xvals = [0 for x in obs_ratios]

                import epdb; epdb.st()

        import epdb; epdb.st()

    ###########################################################################
    #   FETCHERS
    ###########################################################################

    def get_sar_peak(self, sardata, key='kbmemused'):
        peak = None
        for k,v in sardata.items():
            if not peak:
                peak = v
                continue
            if peak[key] < v[key]:
                peak = v
        #import epdb; epdb.st()
        return peak

    def get_ansible_version(self, timedir):
        # results/2018-04-08-18:46:19/ose3-ansible.test.example.com/ansible.version
        (rc, so, se) = run_command('find %s/*ansible* -type f -name "ansible.version"' % timedir)
        files = [x.strip() for x in so.split('\n') if x.strip()]
        if len(files) > 1:
            print('too many ansible.version files: %s' % files)
            sys.exit(1)

        if not files:
            return None

        with open(files[0], 'r') as f:
            loglines = f.readlines()

        version = loglines[0].strip()
        version = version.split()[1:]
        version = ' '.join(version)
        return version

    def get_cluster_uuid(self, timedir):
        # results/2018-04-08-12:41:10/ose3-infra1.test.example.com/var.log/cluster.uuid
        (rc, so, se) = run_command('find %s -type f -name "cluster.uuid"' % timedir)
        uuid_files = [x.strip() for x in so.split('\n') if x.strip()]

        uuids = []
        for uuid_file in uuid_files:
            with open(uuid_file, 'r') as f:
                uuids.append(f.read().strip())
        uuids = sorted(set(uuids))

        if len(uuids) == 1:
            return uuids[0]

        #import epdb; epdb.st()
        return None

    def get_cluster_nodes(self, timedir):
        # ose3-ansible.test.example.com/ansible.log
        # ok: [localhost] => (item=ose3-master1.test.example.com)
        (rc, so, se) = run_command('find %s/*ansible* -type f -name "ansible.log"' % timedir)
        files = [x.strip() for x in so.split('\n') if x.strip()]
        if len(files) > 1:
            print('too many ansible.log files: %s' % files)
            sys.exit(1)

        if not files:
            print('no ansible.log in %s' % timedir)
            nodefile = os.path.join(timedir, 'inventory.admin')
            with open(nodefile, 'r') as f:
                lines = f.readlines()

            nodes = []
            for line in lines:
                node = line.split()[0]
                nodes.append(node)
            return nodes

        with open(files[0], 'r') as f:
            loglines = f.readlines()

        _loglines = [x for x in loglines if 'ok: ' in x]
        _loglines = sorted(set(_loglines))

        nodenames = set()

        for ll in _loglines:
            try:
                nodename = re.match('.*\[(.*)\]\n', ll).group(1)
                if '->' not in nodename and nodename != 'localhost':
                    nodenames.add(nodename)
            except Exception as e:
                pass

        return nodenames

    def get_install_result(self, timedir):
        (rc, so, se) = run_command('find %s/*ansible* -type f -name "ansible.log"' % timedir)
        files = [x.strip() for x in so.split('\n') if x.strip()]
        if not files:
            print('no ansible.log in %s' % timedir)
            return False

        with open(files[0], 'r') as f:
            loglines = f.readlines()

        if 'Message' in loglines[-1]:
            return False

        return True

    def get_failure_info(self, timedir):
        #'  1. Hosts:    ose3-master1.test.example.com\n',
        #'     Play:     Web Console\n',
        #'     Task:     Report console errors\n',
        #'     Message:  Console install failed.\n']

        (rc, so, se) = run_command('find %s/*ansible* -type f -name "ansible.log"' % timedir)
        files = [x.strip() for x in so.split('\n') if x.strip()]
        if not files:
            print('no ansible.log in %s' % timedir)
            return {}

        with open(files[0], 'r') as f:
            loglines = f.readlines()

        if 'Message' not in loglines[-1]:
            return {}

        data = {}
        for ll in loglines[-4:]:
            ll = ll.strip()
            parts = ll.split(':', 1)
            parts = [x.strip() for x in parts if x.strip()]

            key = parts[0]
            if ' ' in key:
                key = key.split()[-1]

            val = parts[-1]
            data[key] = val

        #import epdb; epdb.st()
        return data

    def get_profiler_data(self, timedir):
        #'  1. Hosts:    ose3-master1.test.example.com\n',
        #'     Play:     Web Console\n',
        #'     Task:     Report console errors\n',
        #'     Message:  Console install failed.\n']

        (rc, so, se) = run_command('find %s/*ansible* -type f -name "ansible.log"' % timedir)
        files = [x.strip() for x in so.split('\n') if x.strip()]
        if not files:
            print('no ansible.log in %s' % timedir)
            return (None, [])

        with open(files[0], 'r') as f:
            loglines = f.readlines()

        data = []
        loglines = [x.strip() for x in loglines if x.strip() and x.strip().endswith('MB')]
        if not loglines:
            return (None, [])

        execution_maximum = None
        data = []
        for li,ll in enumerate(loglines):
            _ll = ll[:]
            tdata = {}

            ismax = False
            if 'execution maximum' in ll.lower():
                ismax = True

            ll = ll.split('|', 1)[-1]
            mem = ll.split()[-1].replace('MB', '')
            mem = float(mem)

            parts = ll.split(':', 2)
            parts = [x.strip() for x in parts if x.strip()]

            if parts[0] == 'Execution Maximum':
                execution_maximum = mem
                continue

            #if ismax and not execution_maximum:
            #    import epdb; epdb.st()

            if len(parts) == 2:
                tdata['role'] = None
                tdata['task'] = parts[0]
                tdata['mem'] = mem
                data.append(tdata)
                continue

            elif len(parts) == 3:
                tdata['role'] = parts[0]
                tdata['task'] = parts[1]
                tdata['mem'] = mem
                data.append(tdata)
                continue

            import epdb; epdb.st()

        return (execution_maximum, data)

    def get_cluster_commit_info(self, timedir):
        # results/2018-04-08-18:41:33/ose3-ansible.test.example.com/commit.log
        (rc, so, se) = run_command('find %s/*ansible* -type f -name "commit*.log"' % timedir)
        files = [x.strip() for x in so.split('\n') if x.strip()]

        cinfo = {}

        for filen in files:
            with open(filen, 'r') as f:
                loglines = f.readlines()

            if not loglines:
                continue

            import epdb; epdb.st()

        return cinfo

    def get_sar_data(self, timedir):
        (rc, so, se) = run_command('find %s/*ansible* -type f -name "sar.txt"' % timedir)
        files = [x.strip() for x in so.split('\n') if x.strip()]
        if not files:
            return {}
        with open(files[0], 'r') as f:
            flines = f.readlines()

        sdata = {}
        keys = []
        inphase = False
        for idx,x in enumerate(flines):
            x = x.strip()
            if 'kbmemfree' in x:
                inphase = True
                keys = x.split()
                keys[0] = 'time'
                keys[1] = 'AM/PM'
                continue
            if x.startswith('Average:'):
                break
            if inphase:
                ldata = {}
                cols = x.split()
                for idk,key in enumerate(keys):
                    if idk == 0:
                        continue
                    if not cols[idk].isalpha():
                        ldata[key] = float(cols[idk])
                sdata[cols[0]+cols[1]] = ldata.copy()
                sdata[cols[0]+cols[1]]['time'] = cols[0]+cols[1]

        return sdata


def main():

    resdir = '_results'
    RP = ResultsProcessor(resdir)
    RP.compare_task_sequence()
    import epdb; epdb.st()


if __name__ == "__main__":
    main()
