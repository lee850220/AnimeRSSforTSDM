#!/bin/bash
source /root/.bashrc
PATH="/usr/local/bin:$PATH"
WORK_DIR="/DATA/TSDM/"
ScriptDIR="/etc/aria2"
ConfigFile="${ScriptDIR}/aria2.conf"
TMP_FILE="${WORK_DIR}bsdhare_tmp"
RESPONSE_FILE="${WORK_DIR}bdshare_resp"

UploadConfig="${1}.upload"
filename_ext="${1##*/}"
ARG1="$1"
ARG2="$2"
ARG3="$3"

Notice="[BDshare.sh]: "
CLEAR_LINE="\r\033[K"
MODE=

CurlTimeout=120
ConnectTimeout=5
CurlFlag="-g --connect-timeout ${ConnectTimeout} -m ${CurlTimeout} -sX"

DEBUG=false
SPEC=false
SKIP=false
CLEAR=false
REVERSE=false

# For Baidu
export BAIDUPCS_GO_CONFIG_DIR="${ScriptDIR}"
uploadDIR="/apps/bypy"
app_id="250528"
LIST_API="https://pan.baidu.com/api/list"
SHARE_API="https://pan.baidu.com/share/set"
SHARE_REC_API="https://pan.baidu.com/share/record"
Cancel_API="https://pan.baidu.com/share/cancel"
bdstoken=$(cat ${ConfigFile} | grep bdstoken | sed 's/.*=//')
logid=$(cat ${ConfigFile} | grep logid | sed 's/.*=//')
BD_Cookie=$(cat ${ConfigFile} | grep BD_COOKIE | sed "s/.*'\(.*\)'/\1/")
Host="Host: pan.baidu.com"
ContentType="Content-Type: application/x-www-form-urlencoded"
UserAgent="User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.54 Safari/537.36"
sharePW="TSDM"

###################################################### FUNCTION #########################################################
function Cancel_Share {
    
    Retry=0
    shareid_list=$(echo ${shareid_list}|tr " " ","|sed 's/,$//')
    (( Count = $(echo $shareid_list|grep -o ","|wc -l) + 1 ))
    echo -ne ${CLEAR_LINE}${Notice}"Deleting $Count share link(s)... "
    while true
    do
        resp=$(curl ${CurlFlag} POST "${Cancel_API}?bdstoken=${bdstoken}&channel=chunlei&web=1&app_id=${app_id}&logid=${logid}==&clienttype=0" --header "${Host}" --header "${UserAgent}" --header "${BD_Cookie}" --data-urlencode "shareid_list=[${shareid_list}]")
        if [ "$resp" = "" ]; then
            (( Retry = Retry + 1 ))
            echo -ne ${CLEAR_LINE}${Notice}"Deleting $Count share link(s)... Failed. Retry...$Retry"
        else
            break
        fi
    done

    chk=$(echo "${resp}"| grep -o "errno[^,]*" | grep -o "[0-9]*")
    if [ "$chk" = "0" ]; then
        echo -ne ${CLEAR_LINE}${Notice}"Deleting $Count share link(s)... Success."
    else
        resp=$(echo "$resp"| grep -o "show_msg[^}]*" | tr -d "\"" | sed 's/show_msg://')
        echo -ne ${CLEAR_LINE}${Notice}"Deleting $Count share link(s)... Failed. Reason: ${resp}"
    fi

}

####################################################### MAIN ############################################################

if [[ $ARG1 = "" ]]; then
    echo ${Notice}"Illegal input."
    exit
else
    if ([[ $ARG1 = "s" ]] || [[ $ARG1 = "set" ]]); then
        MODE="s"
    elif ([[ $ARG1 = "l" ]] || [[ $ARG1 = "list" ]]); then
        MODE="l"
    elif ([[ $ARG1 = "lv" ]] || [[ $ARG1 = "listv" ]]); then
        MODE="l"
        REVERSE=true
    elif ([[ $ARG1 = "c" ]] || [[ $ARG1 = "clear" ]]); then
        MODE="c"
    else
        echo ${Notice}"Illegal input."
        exit
    fi
fi

if [[ "$ARG2" != "" ]]; then
    echo ${Notice}"Specific mode."
    SPEC=true
    Count=0
    if [[ "$ARG2" =~ ^[0-9]+$ ]]; then

        for ARGS in "$@"; do

            if [[ "$ARGS" =~ ^[0-9]+$ ]]; then
                (( Count = Count + 1 ))
                shareid_list="$ARGS,$shareid_list"
            fi

        done

        if ([[ $MODE = "c" ]] || ([[ $MODE = "s" ]] && [[ $Count -eq 1 ]])); then
            SKIP=true
        fi
    fi
else
    if ([[ $MODE = "r" ]] || [[ $MODE = "s" ]]); then
        echo ${Notice}"At least 2 arguments."
        exit
    fi
fi

# find total shares
if ! $SKIP; then
    page=1
    count=0
    first=true
    touch ${RESPONSE_FILE}
    echo ${Notice}"Getting total share links..."
    while true
    do
        Retry=0
        echo -ne ${CLEAR_LINE}${Notice}"Getting page $page... "
        while true
        do
            curl ${CurlFlag} POST "${SHARE_REC_API}?channel=chunlei&clienttype=0&app_id=${app_id}&dp-logid=${logid}&num=100&page=${page}&web=1&order=ctime&desc=1" -H "${Host}" -H "${UserAgent}" -H "${BD_Cookie}" -H "${ContentType}" --data-urlencode "schannel=4" --data-urlencode "channel_list=[]" --data-urlencode "period=0" > ${TMP_FILE}
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

        chk=$(cat ${TMP_FILE}| grep -o "count[^,]*" | grep -o "[0-9]*")
        if [ "$chk" = "0" ]; then
            cat ${TMP_FILE}_resp | jq -rc > ${RESPONSE_FILE}
            break
        else
            if $first; then
                first=false
                cat ${TMP_FILE} > ${TMP_FILE}_resp
            else
                cat ${TMP_FILE} | grep -o "list.*newno" | sed 's/list":\[//' | sed 's/\],"newno/,/' > ${TMP_FILE}2    
                cat ${TMP_FILE}_resp|sed "s%\(list\":\[\)%\1`cat ${TMP_FILE}2`%" > ${TMP_FILE}_resp2
                cat ${TMP_FILE}_resp2 > ${TMP_FILE}_resp
            fi
            (( count = count + chk ))
        fi
        (( page = page + 1 ))
    done
    echo -e ${CLEAR_LINE}${Notice}"Total $count link(s)."
fi

if [[ $MODE = "c" ]]; then

    if $SPEC; then

        if $SKIP; then
            Cancel_Share
        else
            # clear share link of specific keyword
            result=$(cat ${RESPONSE_FILE} | grep "${ARG2}" > /dev/null;echo $?)
            if [ $result -eq 0 ]; then
                cat ${RESPONSE_FILE}|grep -o "\{[^{}]*\}"| grep "${ARG2}"| grep -o "typicalPath[^,]*"| sed 's/.*\":\(.*\)/\1/g'
                id=$(cat ${RESPONSE_FILE}|grep -o "\{[^{}]*\}"| grep "${ARG2}"| grep -o "shareId[^,]*" | sed 's/.*\":\(.*\)/\1/g'|tr "\n" " ")
                
                echo
                while true
                do
                    read -r -p "${Notice}Share links of the files listed will be deleted. Are you sure? [Y/n] " response
                    if [[ "$response" = "Y" ]]; then
                        shareid_list=$(echo ${id})
                        Cancel_Share
                        break
                    elif [[ "$response" = "n" ]]; then
                        echo ${Notice}"Canceled."
                        break
                    fi
                done
                
            else
                echo ${Notice}"File not found."
            fi
        fi
    else
        # clear invalid share link
        resp=$(cat ${RESPONSE_FILE} | grep -o "\{[^{}]*\}" | grep -e "分享已过期" -e "分享的文件已被删除" | grep -o "shareId[^,]*," | tr -cd "0-9\n" | tr "\n" " ")
        if [[ "$resp" == "" ]]; then
            echo ${Notice}"No need to clean."
        else
            shareid_list=$(echo ${resp})
            Cancel_Share
        fi
    fi

elif [[ $MODE = "l" ]]; then

    echo
    if $SPEC; then
        # list specific share links
        echo "  shareId                         shareLink                             PATH"
        if $REVERSE; then
            Count=$(cat ${RESPONSE_FILE}|grep -o "\{[^{}]*\}" | grep -o -e "typicalPath[^,]*" -e "shortlink[^,]*" -e "shareId[^,]*" | sed 's/.*\":\(.*\)/\1/g' | sed 's/\"\([^"]*\)\"/\1/g' | sed "N;N;s/\n/ \t/g" | grep -v "${ARG2}"|wc -l)
            cat ${RESPONSE_FILE}|grep -o "\{[^{}]*\}" | grep -o -e "typicalPath[^,]*" -e "shortlink[^,]*" -e "shareId[^,]*" | sed 's/.*\":\(.*\)/\1/g' | sed 's/\"\([^"]*\)\"/\1/g' | sed "N;N;s/\n/ \t/g" | grep -v "${ARG2}"
        else
            Count=$(cat ${RESPONSE_FILE}|grep -o "\{[^{}]*\}" | grep -o -e "typicalPath[^,]*" -e "shortlink[^,]*" -e "shareId[^,]*" | sed 's/.*\":\(.*\)/\1/g' | sed 's/\"\([^"]*\)\"/\1/g' | sed "N;N;s/\n/ \t/g" | grep "${ARG2}"|wc -l)
            cat ${RESPONSE_FILE}|grep -o "\{[^{}]*\}" | grep -o -e "typicalPath[^,]*" -e "shortlink[^,]*" -e "shareId[^,]*" | sed 's/.*\":\(.*\)/\1/g' | sed 's/\"\([^"]*\)\"/\1/g' | sed "N;N;s/\n/ \t/g" | grep "${ARG2}"
        fi
        echo
        echo ${Notice}"Total $Count link(s) matched."
    else
        # list all share links
        echo ${Notice}"listing all share links..."
        echo "  shareId                         shareLink                             PATH"
        cat ${RESPONSE_FILE}| grep -o "\{[^{}]*\}" | grep -o -e "typicalPath[^,]*" -e "shortlink[^,]*" -e "shareId[^,]*" | sed 's/.*\":\(.*\)/\1/g' | sed 's/\"\([^"]*\)\"/\1/g' | sed "N;N;s/\n/ \t/g"
    fi

elif [[ $MODE = "s" ]]; then
    
    Retry=0
    echo -ne ${CLEAR_LINE}${Notice}"Creating share link(s)... "
    while true
    do
        resp=$(curl ${CurlFlag} POST "${SHARE_API}?channel=chunlei&web=1&app_id=${app_id}&logid=${logid}&clienttype=0" -H "${Host}" -H "${UserAgent}" -H "${BD_Cookie}" -H "${ContentType}" --data-urlencode "schannel=4" --data-urlencode "channel_list=[]" --data-urlencode "period=0" --data-urlencode "pwd=${sharePW}" --data-urlencode "fid_list=[${ARG2}]")
        if [ "$resp" = "" ]; then
            echo -ne ${CLEAR_LINE}${Notice}"Creating share link(s)... Failed. Retry...$Retry"
            (( Retry = Retry + 1 ))
        else
            break
        fi
    done

    errno=$(echo "$resp"|grep -o "errno[^,]*" | sed 's/.*\":\(.*\)/\1/g' | sed 's/\"\([^"]*\)\"/\1/g')
    if [ $errno -eq 0 ]; then
        echo -e ${CLEAR_LINE}${Notice}"Creating share link(s)... Success."
        echo
        echo "$resp" | jq -cr | grep -o "link[^,]*" | sed 's/.*\":\(.*\)/\1/g' | sed 's/\"\([^"]*\)\"/\1/g'
    else
        msg=$(echo "$resp"|grep -o "show_msg[^,]*" | sed 's/.*\":\(.*\)/\1/g')
        echo -ne ${CLEAR_LINE}${Notice}"Creating share link(s)... Failed. (reason: ${msg})"
    fi 

fi
rm -f ${TMP_FILE}* ${RESPONSE_FILE}
echo