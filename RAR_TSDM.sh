#!/bin/bash
export PYTHONIOENCODING=utf8
path="${1%/*}/"
filename_ext="${1##*/}"
head="\[Inanity\\\\u7dcb\\\\u96ea@TSDM\]"
uploadDIR="/apps/bypy"
Cookie=''

if [ "$2" = "F" ]; then 
    filename="${filename_ext}"
else
    filename="${filename_ext%.*}"
fi


rar a -hp"Inanity緋雪@僅分享於TSDM" -rr3 -k -t -htb -c -z"/etc/aria2/comment.txt" "${path}[Inanity緋雪@TSDM]${filename}.rar" "$1"
bypy upload "${path}[Inanity緋雪@TSDM]${filename}.rar" -v
rm -rfv "${path}[Inanity緋雪@TSDM]${filename}.rar"

# get file ID
#fileID=$(
#curl -sX GET -H 'Content-type:application/json' "https://pan.baidu.com/api/list?app_id=250528&bdstoken=810326db0487dc2ded7efdffb61019cc&channel=chunlei&clienttype=0&desc=0&dir=${uploadDIR}&logid=MTUzNDM4NDk3MjYzNDAuNTAyODg4NzM4MTQyNDE0Nw==&num=100&order=name&page=1&showempty=0&web=1" --header 'Host: pan.baidu.com' --header 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.54 Safari/537.36' --header "${Cookie}" | jq '.'



#echo $fileID
# create share link
#| tail -n +2 | head -n -2 | jq | grep fs_id | awk '{print $2}' | sed 's/.$//')
