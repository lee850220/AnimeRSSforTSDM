#!/bin/bash
#wget --server-response -q -O- "$1" 2>&1 | 
#    grep "Content-Disposition:" | tail -1 | 
#    sed 's/.*filename="\(.*\)".*/\1/'
url="$1"
filename=$(curl -vgJOL "$url" |& grep filename | sed 's/.*"\(.*\)".*/\1/g')
parse=$(python3 /etc/aria2/URLdecode.py "$filename")
echo "$parse"
rm -f /etc/aria2/$filename
