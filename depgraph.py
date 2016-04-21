#!/usr/bin/env python

import sys
import subprocess
import shlex
from collections import defaultdict
import os.path
import tarjan

def to_dotfile(dictionary, filename):
    with open(filename, 'w') as f:
        f.write('digraph depgraph {\n')
        for k, s in dictionary.items():
            for d in s:
                f.write('{} -> {}\n'.format(k, d))
        f.write('}\n')


file_to_deps = {}
syms_to_files = {}

print('collecting symbols...')

for file in sys.argv[1:]:
    file_syms = set()
    file_deps = set()
    bfile = os.path.splitext(os.path.basename(file))[0]
    bfile = bfile.replace('.', '_')

    command_str = 'nm -g -C ' + file
    command = shlex.split(command_str)
    deps = subprocess.check_output(command).split('\n')

    for line in deps:
        if not line:
            continue

        addr = line[:16]
        type = line[17]
        sym = line[19:]

        if 'virtual thunk' in sym:
            continue

        if type=='T':
            file_syms.add(sym)
        elif type=='U':
            file_deps.add(sym)

    for sym in file_syms:
        if sym in syms_to_files:
            print('sym ' + sym + ' found in ' + bfile + ' but already present in ' + syms_to_files[sym])
            sys.exit(1)
        else:
            syms_to_files[sym] = bfile

    file_to_deps[bfile] = file_deps

print('constructing depgraph...')

depgraph = defaultdict(set)

for file, deps in file_to_deps.items():
    for dep in deps:
        if dep in syms_to_files:
            depgraph[file].add(syms_to_files[dep])

#to_dotfile(depgraph, 'depgraph.dot')

depgraph_lists = {}
for k, s in depgraph.items():
    depgraph_lists[k] = list(s)

td = tarjan.tarjan(depgraph_lists)
print('len(td) = {}'.format(len(td)))
print([len(l) for l in td])
