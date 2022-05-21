#!/bin/bash
wget --server-response -q -O - "$1" 2>&1 | 
    grep "Content-Disposition:" | tail -1 | 
    awk 'match($0, /filename=(.+)/, f){ print f[1] }'
