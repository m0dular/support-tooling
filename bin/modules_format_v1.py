#!/usr/bin/env python

"""
Script to create a json string containing a list of environments and their modules
input: the name of a file containing the name of the environment and a pipe delimited list of modules
    e.g. production:ntp|stdlib|foo
output: a json string of the format:
    [
      { "name": <environment>,
        "modules: [
            { "name": <module>,
              "version": <version>
            }
      }
    ]
"""

from __future__ import print_function
import json, sys, traceback

def main(filename):
    envs = []
    with open(filename, 'r') as f:
        lines = f.read().splitlines()

    for line in lines:
        env = {}
        env_name, env_modules = line.split(':')

        env['name'] = env_name
        env['modules'] = []
        for mod in env_modules.split('|'):
            env['modules'].append({'name': mod, 'version': ''})

        env['total_modules'] = int(len(env['modules']))

        envs.append(env)

    print(json.dumps(envs))

if __name__ == '__main__':
    try:
        main(sys.argv[1])
    except Exception as e:
        print("ERROR: couldn't create json", file=sys.stderr)
        print(traceback.format_exc(), file=sys.stderr)
        exit(1)
