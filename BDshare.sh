#!/bin/bash
source /root/.bashrc
DEBUG=false
RESPONSE_FILE=bdshare_resp
TMP_FILE=bsdhare_tmp
CLEAR_LINE="\r\033[K"
PATH="/usr/local/bin:$PATH"
ScriptDIR=/etc/aria2
Notice="[BDshare.sh]: "
filename_ext="${1##*/}"
UploadConfig="${1}.upload"
ConfigFile=${ScriptDIR}/aria2.conf
CurlTimeout=60
CurlFlag="-g --connect-timeout 5 -m ${CurlTimeout} -sX"
MODE=
SPEC=false
SKIP=false
CLEAR=false
ARG1="$1"
ARG2="$2"
ARG3="$3"

# For Baidu
export BAIDUPCS_GO_CONFIG_DIR='/etc/aria2'
uploadDIR=/apps/bypy
app_id=250528
LIST_API=https://pan.baidu.com/api/list
SHARE_API=https://pan.baidu.com/share/set
Cancel_API=https://pan.baidu.com/share/cancel
bdstoken=$(cat ${ConfigFile} | grep bdstoken | sed 's/.*=//')
logid=$(cat ${ConfigFile} | grep logid | sed 's/.*=//')
BD_Cookie=$(cat ${ConfigFile} | grep BD_COOKIE | sed "s/.*'\(.*\)'/\1/")
UserAgent="User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.54 Safari/537.36"
sharePW=TSDM

###################################################### FUNCTION #########################################################
function Cancel_Share {
    
    shareid_list=$(echo ${shareid_list}|tr " " ","|sed 's/,$//')
    resp=$(curl ${CurlFlag} POST "${Cancel_API}?bdstoken=${bdstoken}&channel=chunlei&web=1&app_id=${app_id}&logid=${logid}==&clienttype=0" --header 'Host: pan.baidu.com' --header "${UserAgent}" --header "${BD_Cookie}" --data-urlencode "shareid_list=[${shareid_list}]")
    chk=$(echo "${resp}"| grep -o "errno[^,]*" | grep -o "[0-9]*")
    if [ "$chk" = "0" ]; then
        echo "Success."
    else
        resp=$(echo "$resp"| grep -o "show_msg[^}]*" | tr -d "\"" | sed 's/show_msg://')
        echo "Failed. Reason: ${resp}"
    fi

}

####################################################### MAIN ############################################################

if [[ $ARG1 = "" ]]; then
    echo ${Notice}"Illegal input."
    exit
else
    if ([[ $ARG1 = "s" ]] || [[ $ARG1 = "set" ]]); then
        MODE="s"
        SKIP=true
    elif ([[ $ARG1 = "l" ]] || [[ $ARG1 = "list" ]]); then
        MODE="l"
    elif ([[ $ARG1 = "c" ]] || [[ $ARG1 = "clear" ]]); then
        MODE="c"
    else
        echo ${Notice}"Illegal input."
        exit
    fi
fi

if [[ "$ARG2" != "" ]]; then
    echo ${Notice}"Specific mode..."
    SPEC=true
    if ([[ "$ARG2" =~ ^[0-9]+$ ]] && [[ $MODE = "c" ]]); then
        SKIP=true
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
            curl ${CurlFlag} POST "https://pan.baidu.com/share/record?channel=chunlei&clienttype=0&app_id=${app_id}&dp-logid=${logid}&num=100&page=${page}&web=1&order=ctime&desc=1" -H "Host: pan.baidu.com" -H "${UserAgent}" -H "${BD_Cookie}" -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "schannel=4" --data-urlencode "channel_list=[]" --data-urlencode "period=0" | jq -rc > ${TMP_FILE}
            if ${DEBUG}; then
                cat ${TMP_FILE}
            fi
            if [ "$(cat ${TMP_FILE})" = "" ]; then
                echo -ne "${CLEAR_LINE}${Notice}Getting page $page... Retry...$Retry"
                (( Retry = Retry + 1 ))
            else
                break
            fi
        done
        chk=$(cat ${TMP_FILE}| grep -o "count[^,]*" | grep -o "[0-9]*")
        if [ "$chk" = "0" ]; then
            cat ${TMP_FILE}_resp > ${RESPONSE_FILE}
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
            shareid_list="$ARG2"
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
                        echo -n ${Notice}"delete $(echo $id | wc -w) link(s)... "
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
            echo ${Notice}"delete $(echo $resp | wc -w) link(s)."
            shareid_list=$(echo ${resp})
            Cancel_Share
        fi
        Cancel_Share
    fi

elif [[ $MODE = "l" ]]; then

    if $SPEC; then
        # list specific share links
        echo "  shareId                         shareLink                             PATH"
        cat ${RESPONSE_FILE}|grep -o "\{[^{}]*\}" | grep -o -e "typicalPath[^,]*" -e "shortlink[^,]*" -e "shareId[^,]*" | sed 's/.*\":\(.*\)/\1/g' | sed 's/\"\([^"]*\)\"/\1/g' | sed "N;N;s/\n/ \t/g" | grep "${ARG2}"
    else
        # list all share links
        echo ${Notice}"list all share links ${i}..."
        echo "  shareId                         shareLink                             PATH"
        cat ${RESPONSE_FILE}| grep -o "\{[^{}]*\}" | grep -o -e "typicalPath[^,]*" -e "shortlink[^,]*" -e "shareId[^,]*" | sed 's/.*\":\(.*\)/\1/g' | sed 's/\"\([^"]*\)\"/\1/g' | sed "N;N;s/\n/ \t/g"
    fi

elif [[ $MODE = "s" ]]; then

    resp=$(curl ${CurlFlag} POST "https://pan.baidu.com/share/set?channel=chunlei&web=1&app_id=${app_id}&logid=${logid}&clienttype=0" -H "Host: pan.baidu.com" -H "${UserAgent}" -H "${BD_Cookie}" -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "schannel=4" --data-urlencode "channel_list=[]" --data-urlencode "period=0" --data-urlencode "pwd=${sharePW}" --data-urlencode "fid_list=[${ARG2}]")
    errno=$(echo "$resp"|grep -o "errno[^,]*" | sed 's/.*\":\(.*\)/\1/g' | sed 's/\"\([^"]*\)\"/\1/g')
    if [ $errno -eq 0 ]; then
        echo
        echo "$resp" | jq -cr | grep -o "link[^,]*" | sed 's/.*\":\(.*\)/\1/g' | sed 's/\"\([^"]*\)\"/\1/g'
    else
        msg=$(echo "$resp"|grep -o "show_msg[^,]*" | sed 's/.*\":\(.*\)/\1/g')
        echo ${Notice}${msg}
    fi 

fi
rm -f ${TMP_FILE}* ${RESPONSE_FILE}*
echo