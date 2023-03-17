#!/usr/bin/env bash

find -type f -name config | grep .git/config | grep -v Archived | xargs -n1 grep url | cut -d= -f2 | sort| sed -e 's@ssh://@@' -e 's@https://@@' -e 's@http://@@' -e 's@git://@@' -e 's/.*@//' -e 's/^\s//' -e 's@:@/@' -e 's/\.git$//' | sort -u
