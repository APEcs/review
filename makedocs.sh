#!/bin/bash

# Get the latest tag annotation out of git.
VERS=`git tag -n1 | tail -n1 | perl -e '$tag = <STDIN>; $tag =~ s/^(.*?)\s\s+(.*)$/$1 - $2/; print $tag;'`

(cat Doxyfile; echo "PROJECT_NUMBER = \"$VERS\"") | doxygen -
