#!/bin/bash

round() {
    printf "%.${2}f" "${1}"
}

unit=BKMGTPEZY
total=$(BaiduPCS-Go meta "$1/*" | grep 文件大小 | awk '{print $2}' | sed 's/.$//' | paste -sd+ | bc)
cnt=0
while (( $(echo "$total > 1024" |bc -l) )); do
    #echo "scale=2;$total/1024" | bc
    total=$(echo "scale=2;${total}/1024" | bc)
    cnt=$((cnt+1))
done
rm -f tmp
if [ $(echo ${unit:cnt:1}|grep [MB] >& /dev/null; echo -n $?) -eq 0 ]; then 
    echo $(round ${total} 0)${unit:cnt:1}
else 
    echo $(round ${total} 1)${unit:cnt:1}
fi


