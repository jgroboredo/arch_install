#!/bin/bash

#find . -type f | awk '{print "<a href=\""$1"\">"$1"</a><br>" }' > files.html
find . -type f | sort -h > files.html
