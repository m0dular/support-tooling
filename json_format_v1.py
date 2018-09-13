#!/usr/bin/env python

from __future__ import print_function
import sys, json, traceback

"""
Parses several files related to database size and usage from the v1 support script and formats them as json
files: [resources/db_relation_sizes.txt, resources/db_sizes_from_du.txt]
"""

def format_relational_sizes(lines):
    """
    parse relational size data and add it to the main dict
    :param lines: an array of lines
    """
    names = list(set([x.split("|")[0] for x in lines]))
    for name in names:
        databases[name] = {}
        databases[name]['tables'] = []

    for line in lines:
        fields = line.split("|")
        db, table, size = fields[0], fields[1], int(fields[2])

        databases[db]['tables'].append({'name': table, 'size': size})

    for k in databases.keys():
        databases[k]['tables_total'] = sum([int(x['size']) for x in databases[k]['tables']])

def format_du_sizes(lines):
    """
    parse du size data and add it to the main dict
    :param lines: an array of lines
    """
    for line in lines:
        fields = line.split("|")
        db, size = fields[0], int(fields[1])

        databases[db]['du_size'] = size


def main(args):
    try:
        relation_sizes, du_sizes = args[1], args[2]
    except Exception as e:
        print("ERROR: Invalid arguments", file=sys.stderr)
        print(traceback.format_exc(), file=sys.stderr)
        exit(1)

    global databases
    databases = {}

    # Relational sizes
    try:
        with open(relation_sizes, 'r') as f:
            lines = f.read().splitlines()

        format_relational_sizes(lines)
    except Exception as e:
        print("ERROR: couldn't format relational sizes", file=sys.stderr)
        print(traceback.format_exc(), file=sys.stderr)
        exit(1)

    # `du` sizes
    try:
        with open(du_sizes, 'r') as f:
            lines = f.read().splitlines()

        format_du_sizes(lines)
    except Exception as e:
        print("ERROR: couldn't format du sizes", file=sys.stderr)
        print(traceback.format_exc(), file=sys.stderr)
        exit(1)

    # Serialize to json
    try:
        print(json.dumps(databases))
    except Exception as e:
        print("ERROR: couldn't serialize json", file=sys.stderr)
        print(traceback.format_exc(), file=sys.stderr)
        exit(1)


if __name__ == "__main__":
    main(sys.argv)
