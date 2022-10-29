#!/bin/bash
source /root/.bashrc
PATH="/usr/local/bin:$PATH"
WORK_DIR="/DATA/TSDM/"
ScriptDIR="/etc/aria2"
TMP_FILE="${WORK_DIR}bdlist_tmp"
RESPONSE_FILE="${WORK_DIR}bdlist_resp"
ConfigFile="${ScriptDIR}/aria2.conf"

filename_ext="${1##*/}"
UploadConfig="${1}.upload"
ARG1=$(urlencode $1)
ARG2="$2"

Notice="[BDlist.sh]: "
CLEAR_LINE="\r\033[K"
MODE=


CurlTimeout=120
ConnectTimeout=5
CurlFlag="-g --connect-timeout ${ConnectTimeout} -m ${CurlTimeout} -sX"

DEBUG=false
SPEC=false

# For Baidu
export BAIDUPCS_GO_CONFIG_DIR="${ScriptDIR}"
uploadDIR="/apps/bypy"
app_id="250528"
LIST_API="https://pan.baidu.com/api/list"
SHARE_API="https://pan.baidu.com/share/set"
bdstoken=$(cat ${ConfigFile} | grep bdstoken | sed 's/.*=//')
logid=$(cat ${ConfigFile} | grep logid | sed 's/.*=//')
BD_Cookie=$(cat ${ConfigFile} | grep BD_COOKIE | sed "s/.*'\(.*\)'/\1/")
Host="Host: pan.baidu.com"
UserAgent="User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.54 Safari/537.36"
sharePW="TSDM"

####################################################### MAIN ############################################################
if [ "$ARG1" = "" ]; then
    ARG1="/"
fi

# find total files
page=1
first=true
rm -f ${TMP_FILE}* ${RESPONSE_FILE}
touch ${RESPONSE_FILE}
echo ${Notice}"Getting file list..."
while true
do
    Retry=0
    echo -ne ${CLEAR_LINE}${Notice}"Getting page $page... "
    while true
    do
        curl ${CurlFlag} GET "${LIST_API}?app_id=${app_id}&bdstoken=${bdstoken}&channel=chunlei&clienttype=0&desc=0&dir=${ARG1}&logid=${logid}&num=100&order=name&page=${page}&showempty=0&web=1" -H "${Host}" -H "${UserAgent}" -H "${BD_Cookie}" --data-raw "" > ${TMP_FILE}
        if ${DEBUG}; then
            cat ${TMP_FILE}
        fi
        if [ "$(cat ${TMP_FILE})" = "" ]; then
            (( Retry = Retry + 1 ))
            echo -ne "${CLEAR_LINE}${Notice}Getting page $page... Retry...$Retry"
        else
            break
        fi
    done

    cat ${TMP_FILE} | jq -rc | sed 's/"thumbs":{[^{}]*},"wpfile/"wpfile/g' | grep -o "\{[^{}]*\}" | grep -o -e "fs_id[^,]*" -e "path[^,]*" | sed 's/.*\":\(.*\)/\1/g'| sed 's/\"\([^"]*\)\"/\1/g' > ${TMP_FILE}2
    if [ "$(cat ${TMP_FILE}2)" = "" ]; then
        break
    else
        cat ${TMP_FILE}2 >> ${RESPONSE_FILE}
    fi
    (( page = page + 1 ))
done

if [ "$ARG2" = "" ]; then
    (( Count = $(cat ${RESPONSE_FILE}|wc -l) / 2 ))
    TARGET="cat ${RESPONSE_FILE}"
else
    (( Count = $(cat ${RESPONSE_FILE} | grep -B1 "$ARG2" | grep -v "\-\-"|wc -l) / 2 ))
    TARGET="cat ${RESPONSE_FILE} | grep -B1 \"$ARG2\" | grep -v \"\-\-\""
fi

# print list
even=false
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")
echo -e ${CLEAR_LINE}
echo "     fs_id              PATH"
for line in $(bash -c $TARGET);
do
    if ! (( ${even})); then
        echo -n $line
        cnt=$(echo $line | wc -m)
    else                
        if [ $cnt -lt 16 ]; then
            echo -e " \\t\\t$line"
        else
            echo -e " \\t$line"
        fi
    fi
    even=$(( 1 - even ))
done
IFS=$SAVEIFS

rm -f ${TMP_FILE}* ${RESPONSE_FILE}
echo
echo ${Notice}"Total $Count item(s)."
echo