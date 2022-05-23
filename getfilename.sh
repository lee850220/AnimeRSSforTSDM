#!/bin/bash
#wget --server-response -q -O- "$1" 2>&1 | 
#    grep "Content-Disposition:" | tail -1 | 
#    sed 's/.*filename="\(.*\)".*/\1/'
url="$1"
filename=$(curl -gO -J -L "$url" 2> /dev/null | sed "s/.*'\(.*\)'.*/\1/")
echo $filename
rm -f $filename