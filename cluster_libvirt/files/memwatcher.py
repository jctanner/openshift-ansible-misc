#!/usr/bin/env python


import datetime
import json
import os
import psutil
import sys
import subprocess
import time

from pprint import pprint


def run_command(cmd):
    p = subprocess.Popen(
        cmd,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    (so, se) = p.communicate()
    return (p.returncode, so, se)


def get_ansible_pids():
    print('# finding ansible pids')
    ansible_pids = []
    for pid in psutil.pids():
        try:
            proc = psutil.Process(pid)
            cmd = proc.cmdline()
            cmdline = ' '.join(cmd)
            if 'ansible' in cmdline:
                ansible_pids.append(proc)
        except Exception as e:
            pass

    return ansible_pids


def get_python_pid_data(pid):
    print('# running gdb on pid %s' % pid)
    cmd = "gdb -p %s" % pid
    cmd += " -ex 'printf \"\n### BT\n\n\"' -ex bt"
    cmd += " -ex 'printf \"\n### PY-BT\n\n\"' -ex py-bt"
    cmd += " -ex 'printf \"\n### PY-LIST\n\n\"' -ex py-list"
    cmd += " -ex 'printf \"\n### PY-LOCALS\n\n\"' -ex py-locals"
    cmd += " -ex quit -batch"
    (rc, so, se) = run_command(cmd)

    #import epdb; epdb.st()
    return so.split('\n')


def get_memstats(average=False):
    #[root@ose3-ansible ~]# sar -r 1 1
    #Linux 3.10.0-693.17.1.el7.x86_64 (ose3-ansible.test.example.com)        04/03/2018      _x86_64_        (1 CPU)
    #01:19:22 PM kbmemfree kbmemused  %memused kbbuffers  kbcached  kbcommit   %commit  kbactive   kbinact   kbdirty
    #01:19:23 PM   3098636    947980     23.43         0    707840    369648      6.02    425808    357972        28
    #Average:      3098636    947980     23.43         0    707840    369648      6.02    425808    357972        28

    (rc, so, se) = run_command('sar -r 1 1')
    lines = so.split('\n')
    lines = [x.strip() for x in lines if x.strip()]

    header_line = lines[1]
    keys = header_line.split()[2:]

    if average:
        last_line = lines[-2]
        values = last_line.split()[1:]
    else:
        last_line = lines[-2]
        values = last_line.split()[2:]

    values = [float(x) for x in values]

    return dict(zip(keys,values))


def main():

    obs_key = '%memused'
    thresh_hold = 40.0
    logdir = '/var/log/memwatcher'
    if not os.path.isdir(logdir):
        os.makedirs(logdir)

    count = 0
    while True:

        print('# iteration %s' % count)
        count += 1

        memstats = get_memstats()
        pprint(memstats)

        if memstats[obs_key] > thresh_hold:

            print("# Threshold met (%s), fetching and recording data" % \
                    memstats[obs_key])

            jdata = {
                'memstats': memstats,
                'date': datetime.datetime.isoformat(datetime.datetime.now()),
                'pids': {}
            }
            pids = get_ansible_pids()
            for pid in pids:
                #import epdb; epdb.st()
                memory_percent = pid.memory_percent()

                pdata = None
                try:
                    pdata = get_python_pid_data(pid.pid)
                except:
                    pass

                parent = None
                try:
                    parent = pid.parent().pid
                except:
                    pass

                jdata['pids'][pid.pid] = {
                    'parent': parent,
                    'cmdline': pid.cmdline(),
                    'memory_percent': memory_percent,
                    'gdb': pdata
                }

            logfile = os.path.join(logdir, '%s.json' % jdata['date'])
            with open(logfile, 'w') as f:
                f.write(json.dumps(jdata, indent=2))

        time.sleep(30)


if __name__ == "__main__":
    main()
