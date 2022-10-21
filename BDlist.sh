#!/bin/bash
source /root/.bashrc
DEBUG=false
CLEAR_LINE="\r\033[K"
PATH="/usr/local/bin:$PATH"
ScriptDIR=/etc/aria2
Notice="[BDlist.sh]: "
filename_ext="${1##*/}"
UploadConfig="${1}.upload"
ConfigFile=${ScriptDIR}/aria2.conf
CurlTimeout=5
MODE=
SPEC=false
ARG1=$(urlencode $1)
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
RETRY=0
while true
do

    if [[ $ARG1 = "" ]]; then
        resp=$(curl -s -m $CurlTimeout -g -X GET "https://pan.baidu.com/api/list?app_id=250528&bdstoken=810326db0487dc2ded7efdffb61019cc&channel=chunlei&clienttype=0&desc=0&dir=/&logid=${logid}&num=100&order=name&page=1&showempty=0&web=1" -H "Host: pan.baidu.com" -H "${UserAgent}" -H "${BD_Cookie}" --data-raw "")
    else
        resp=$(curl -s -m $CurlTimeout -g -X GET "https://pan.baidu.com/api/list?app_id=250528&bdstoken=810326db0487dc2ded7efdffb61019cc&channel=chunlei&clienttype=0&desc=0&dir=${ARG1}&logid=${logid}&num=100&order=name&page=1&showempty=0&web=1" -H "Host: pan.baidu.com" -H "${UserAgent}" -H "${BD_Cookie}" --data-raw "")
    fi

    if [ ! "$resp" = "" ]; then
        SAVEIFS=$IFS
	    IFS=$(echo -en "\n\b")
        echo -e ${CLEAR_LINE}"     fs_id                      PATH"
        resp=$(echo $resp|jq -cr|grep -o "\{[^{}]*\}" | grep -o -e "fs_id[^,]*" -e "path[^,]*" | sed 's/.*\":\(.*\)/\1/g'| sed 's/\"\([^"]*\)\"/\1/g' )
        #| sed "N;s/\n/ \t/g"
        even=false
        for line in ${resp};
        do
            if ! (( ${even})); then
                echo -n $line
                cnt=$(echo $line | wc -m)
            else                
                #echo;echo "$cnt"
                if [ $cnt -lt 16 ]; then
                    echo -e " \\t\\t$line"
                else
                    echo -e " \\t$line"
                fi
            fi
            even=$(( 1 - even ))
        done
        break
        IFS=$SAVEIFS
    else
        echo -ne "${CLEAR_LINE}Retrying...$Retry"
    fi
    (( Retry = Retry + 1 ))
    
done
echo