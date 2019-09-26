#!/usr/bin/env python

from json2html import *
from collections import OrderedDict
import json
import sys

with open(sys.argv[1], 'r') as f:
    d = json.load(f, object_pairs_hook=OrderedDict)
    print '''
<html>
<head>
<link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css" integrity="sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T" crossorigin="anonymous">
</head>
<body>
'''

    print json2html.convert(d, table_attributes="class=\"table table-condensed table-bordered table-hover\"")
    print '''
</body>
</html>
'''
