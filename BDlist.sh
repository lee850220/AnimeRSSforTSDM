#!/bin/bash
PATH="/usr/local/bin:$PATH"
ScriptDIR=/etc/aria2
Notice="[BDlist.sh]: "
filename_ext="${1##*/}"
UploadConfig="${1}.upload"
ConfigFile=${ScriptDIR}/aria2.conf
CurlTimeout=15
MODE=
SPEC=false
ARG1="$1"
ARG2="$2"
ARG3="$3"

# For Baidu
export BAIDUPCS_GO_CONFIG_DIR='/etc/aria2'
uploadDIR=/apps/bypy
app_id=250528
LIST_API=https://pan.baidu.com/api/list
SHARE_API=https://pan.baidu.com/share/set
bdstoken=$(cat ${ConfigFile} | grep bdstoken | sed 's/.*=//')
logid=$(cat ${ConfigFile} | grep logid | sed 's/.*=//')
BD_Cookie=$(cat ${ConfigFile} | grep BD_COOKIE | sed "s/.*'\(.*\)'/\1/")
UserAgent="User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.54 Safari/537.36"
sharePW=TSDM


####################################################### MAIN ############################################################
echo
echo "     fs_id                      PATH"
if [[ $ARG1 = "" ]]; then
    curl -s -m 180 -X GET "https://pan.baidu.com/api/list?app_id=250528&bdstoken=810326db0487dc2ded7efdffb61019cc&channel=chunlei&clienttype=0&desc=0&dir=/&logid=${logid}&num=100&order=name&page=1&showempty=0&web=1" -H "Host: pan.baidu.com" -H "${UserAgent}" -H "${BD_Cookie}" --data-raw ""|jq -cr|grep -o "\{[^{}]*\}" | grep -o -e "fs_id[^,]*" -e "path[^,]*" | sed 's/.*\":\(.*\)/\1/g' | sed 's/\"\([^"]*\)\"/\1/g' | sed "N;s/\n/ \t/g"
else
    curl -s -m 180 -X GET "https://pan.baidu.com/api/list?app_id=250528&bdstoken=810326db0487dc2ded7efdffb61019cc&channel=chunlei&clienttype=0&desc=0&dir=${ARG1}&logid=${logid}&num=100&order=name&page=1&showempty=0&web=1" -H "Host: pan.baidu.com" -H "${UserAgent}" -H "${BD_Cookie}" --data-raw ""|jq -cr|grep -o "\{[^{}]*\}" | grep -o -e "fs_id[^,]*" -e "path[^,]*" | sed 's/.*\":\(.*\)/\1/g' | sed 's/\"\([^"]*\)\"/\1/g' | sed "N;s/\n/  \t\t/g"
fi
echo