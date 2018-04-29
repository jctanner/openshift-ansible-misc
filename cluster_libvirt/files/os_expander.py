#!/usr/bin/env python

# EXPANDER
#
#   Take the fixtures created by an ansible-vcr recording and expand them
#   to a new arbitary hostcount.

import argparse
import glob
import os
import shutil
import subprocess
import sys


def run_command(cmd):
    p = subprocess.Popen(
        cmd,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )

    so, se = p.communicate()
    return (p.returncode, so, se)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--fixturedir', default='/tmp/fixtures')
    parser.add_argument('--hostcount', type=int)
    parser.add_argument('--dryrun', action='store_true', default=False)
    args = parser.parse_args()

    taskdirs = glob.glob('%s/*' % args.fixturedir)
    taskdirs = [x for x in taskdirs if x[-1].isdigit()]

    hostdirs = []
    for td in taskdirs:
        hostdirs += glob.glob('%s/*' % td)

    hosts = set()
    for hd in hostdirs:
        hostname = hd.split('/')[-1]
        hosts.add(hostname)

    # ose3-node1.test.example.com
    hosts = set([x for x in hosts if 'node' in x])
    prefix = 'ose3-node'
    suffix = '.test.example.com'

    counter = len(hosts) + 1
    while len(hosts) < args.hostcount:
        hn = prefix + str(counter) + suffix
        if hn not in hosts:
            hosts.add(hn)
        counter += 1

    for td in taskdirs:

        src_hn = prefix + '1' + suffix
        src_dir = os.path.join(td, src_hn)
        if not os.path.isdir(src_dir):
            continue

        for hn in hosts:
            hdir = os.path.join(td, hn)
            if not os.path.isdir(hdir):
                print('copying %s to %s' % (src_dir, hdir))
                if not args.dryrun:
                    shutil.copytree(src_dir, hdir)
                hdir_files = glob.glob('%s/*' % hdir)
                #if not hdir_files:
                #    import epdb; epdb.st()
                for hdf in hdir_files:
                    cmd = "sed -i.bak 's/%s/%s/g' %s" % (src_hn, hn, hdf)
                    print(cmd)
                    if not args.dryrun:
                        (rc, so, se) = run_command(cmd)

    # /home/admin/ansible/facts
    # ansible/facts/ose3-node1.test.example.com
    src_hn = 'ose3-node1.test.example.com'
    src = os.path.expanduser('~/ansible/facts/%s' % src_hn)
    for hn in hosts:
        newfile =  os.path.expanduser('~/ansible/facts/%s' % hn)
        if not os.path.isfile(newfile):
            print('cp %s %s' % (src, newfile))
            if not args.dryrun:
                shutil.copy(src, newfile)

            cmd = "sed -i.bak 's/%s/%s/g' %s" % (src_hn, hn, newfile)
            print(cmd)
            if not args.dryrun:
                (rc, so, se) = run_command(cmd)


    # NODES="$NODES ose3-node10.test.example.com"
    nodefile = os.path.expanduser('~/nodes.sh')
    with open(nodefile, 'r') as f:
        nodelines = f.readlines()
    for hn in hosts:
        expected = 'NODES="$NODES %s"' % hn
        if expected not in nodelines:
            nodelines.append(expected)
    with open(nodefile, 'w') as f:
        f.write('\n'.join(nodelines))


if __name__ == "__main__":
    main()
