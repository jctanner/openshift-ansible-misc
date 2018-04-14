#!/usr/bin/env python

import datetime


def gitlogparser(log):

    commits = []

    thiscommit = {}
    lines = log.split('\n')
    for line in lines:
        #print(line)
        if line.startswith('commit '):
            commits.append(thiscommit.copy())
            thiscommit = {}

            thiscommit['hash'] = line.split()[-1]
        elif line.startswith('Author: '):
            thiscommit['author'] = line.replace('Author: ', '').strip()
        elif line.startswith('Date: '):
            # Fri Mar 16 13:46:35 2018 -0400
            _date = line.replace('Date:', '').strip()
            _date = ' '.join(_date.split()[0:-1])
            _date = datetime.datetime.strptime(_date, '%a %b %d %H:%M:%S %Y')
            thiscommit['date'] = _date.isoformat()
            #import epdb; epdb.st()

    if thiscommit:
        commits.append(thiscommit)
    commits = commits[1:]

    return commits
