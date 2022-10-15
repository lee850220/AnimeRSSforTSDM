#!/bin/bash
PATH="/usr/local/bin:$PATH"
ScriptDIR=/etc/aria2
Notice="[BDshare.sh]: "
filename_ext="${1##*/}"
UploadConfig="${1}.upload"
ConfigFile=${ScriptDIR}/aria2.conf
CurlTimeout=20
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
    resp=$(curl -m ${CurlTimeout} -sX POST "${Cancel_API}?bdstoken=${bdstoken}&channel=chunlei&web=1&app_id=${app_id}&logid=${logid}==&clienttype=0" --header 'Host: pan.baidu.com' --header "${UserAgent}" --header "${BD_Cookie}" --data-urlencode "shareid_list=[${shareid_list}]")
    chk=$(echo "${resp}"| grep -o "errno[^,]*" | grep -o "[0-9]*")
    if [ "$chk" = "0" ]; then
        echo ${Notice}"Success."
    else
        resp=$(echo "$resp"| grep -o "show_msg[^}]*" | tr -d "\"" | sed 's/show_msg://')
        echo ${Notice}"Failed to delete link(s). Reason: ${resp}"
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
    echo ${Notice}"Getting total share links..."
    while true
    do
        resp=$(curl -s -m ${CurlTimeout} -X POST "https://pan.baidu.com/share/record?channel=chunlei&clienttype=0&app_id=${app_id}&dp-logid=${logid}&num=100&page=${page}&web=1&order=ctime&desc=1" -H "Host: pan.baidu.com" -H "${UserAgent}" -H "${BD_Cookie}" -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "schannel=4" --data-urlencode "channel_list=[]" --data-urlencode "period=0"|grep -o "list[^,]*," | grep {} > /dev/null;echo $?)
        if [ $resp -eq 0 ]; then
            break
        fi
        (( page = page + 1 ))
    done
    (( page = page - 1 ))
    echo ${Notice}"Total ${page} page(s)."
fi

if [[ $MODE = "c" ]]; then

    if $SPEC; then

        if $SKIP; then
            #BaiduPCS-Go share c "${ARG2}"
            shareid_list="$ARG2"
            Cancel_Share
        else
            # clear share link of specific keyword
            for ((i=$page; i>=1; i--))
            do
                echo ${Notice}"Checking page ${i} of ${page}..."
                resp=$(curl -s -m ${CurlTimeout} -X POST "https://pan.baidu.com/share/record?channel=chunlei&clienttype=0&app_id=${app_id}&dp-logid=${logid}&num=100&page=${i}&web=1&order=ctime&desc=1" -H "Host: pan.baidu.com" -H "${UserAgent}" -H "${BD_Cookie}" -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "schannel=4" --data-urlencode "channel_list=[]" --data-urlencode "period=0"|jq -rc)
                
                result=$(echo "${resp}" | grep "${ARG2}" > /dev/null;echo $?)
                if [ $result -eq 0 ]; then
                    CLEAR=true
                    echo "${resp}"|grep -o "\{[^{}]*\}"| grep "${ARG2}"| grep -o "typicalPath[^,]*"| sed 's/.*\":\(.*\)/\1/g'
                    id=$(echo "${resp}"|grep -o "\{[^{}]*\}"| grep "${ARG2}"| grep -o "shareId[^,]*" | sed 's/.*\":\(.*\)/\1/g'|tr "\n" " ")
                    
                    echo
                    while true
                    do
                        read -r -p "${Notice}Share links of the files listed will be deleted. Are you sure? [Y/n] " response
                        if [[ "$response" = "Y" ]]; then
                            echo ${Notice}"delete $(echo $id | wc -w) link(s)."
                            #BaiduPCS-Go share c `echo ${id}`
                            shareid_list=$(echo ${id})
                            Cancel_Share
                            break
                        elif [[ "$response" = "n" ]]; then
                            echo ${Notice}"Canceled."
                            break
                        fi
                    done
                    
                fi
            done

            if ! $CLEAR; then
                echo ${Notice}"File not found."
            fi
        fi
    else
        # clear invalid share link
        for ((i=$page; i>=1; i--))
        do
            echo ${Notice}"Cleaning page ${i}..."
            resp=$(curl -s -m ${CurlTimeout} -X POST "https://pan.baidu.com/share/record?channel=chunlei&clienttype=0&app_id=${app_id}&dp-logid=${logid}&num=100&page=${i}&web=1&order=ctime&desc=1" -H "Host: pan.baidu.com" -H "${UserAgent}" -H "${BD_Cookie}" -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "schannel=4" --data-urlencode "channel_list=[]" --data-urlencode "period=0"| grep -o "\{[^{}]*\}" | grep -e "分享已过期" -e "分享的文件已被删除" | grep -o "shareId[^,]*," | tr -cd "0-9\n" | tr "\n" " ")
            if [[ "$resp" == "" ]]; then
                echo ${Notice}"No need to clean."
            else
                echo ${Notice}"delete $(echo $resp | wc -w) link(s)."
                #BaiduPCS-Go share c `echo ${resp}`
                shareid_list=$(echo ${resp})
                Cancel_Share
            fi
        done
    fi

elif [[ $MODE = "l" ]]; then

    if $SPEC; then
        # list specific share links
        echo "  shareId                         shareLink                             PATH"
        for ((i=$page; i>=1; i--))
        do
            curl -s -m ${CurlTimeout} -X POST "https://pan.baidu.com/share/record?channel=chunlei&clienttype=0&app_id=${app_id}&dp-logid=${logid}&num=100&page=${i}&web=1&order=ctime&desc=1" -H "Host: pan.baidu.com" -H "${UserAgent}" -H "${BD_Cookie}" -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "schannel=4" --data-urlencode "channel_list=[]" --data-urlencode "period=0"|jq -cr|grep -o "\{[^{}]*\}" | grep -o -e "typicalPath[^,]*" -e "shortlink[^,]*" -e "shareId[^,]*" | sed 's/.*\":\(.*\)/\1/g' | sed 's/\"\([^"]*\)\"/\1/g' | sed "N;N;s/\n/ \t/g" | grep "${ARG2}"
        done
    else
        # list all share links
        echo ${Notice}"list all share links ${i}..."
        echo "  shareId                         shareLink                             PATH"
        for ((i=$page; i>=1; i--))
        do
            curl -s -m ${CurlTimeout} -X POST "https://pan.baidu.com/share/record?channel=chunlei&clienttype=0&app_id=${app_id}&dp-logid=${logid}&num=100&page=${i}&web=1&order=ctime&desc=1" -H "Host: pan.baidu.com" -H "${UserAgent}" -H "${BD_Cookie}" -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "schannel=4" --data-urlencode "channel_list=[]" --data-urlencode "period=0"|jq -cr| grep -o "\{[^{}]*\}" | grep -o -e "typicalPath[^,]*" -e "shortlink[^,]*" -e "shareId[^,]*" | sed 's/.*\":\(.*\)/\1/g' | sed 's/\"\([^"]*\)\"/\1/g' | sed "N;N;s/\n/ \t/g"
        done
    fi

elif [[ $MODE = "s" ]]; then

    resp=$(curl -s -m ${CurlTimeout} -X POST "https://pan.baidu.com/share/set?channel=chunlei&web=1&app_id=${app_id}&logid=${logid}&clienttype=0" -H "Host: pan.baidu.com" -H "${UserAgent}" -H "${BD_Cookie}" -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "schannel=4" --data-urlencode "channel_list=[]" --data-urlencode "period=0" --data-urlencode "pwd=${sharePW}" --data-urlencode "fid_list=[${ARG2}]")
    errno=$(echo "$resp"|grep -o "errno[^,]*" | sed 's/.*\":\(.*\)/\1/g' | sed 's/\"\([^"]*\)\"/\1/g')
    if [ $errno -eq 0 ]; then
        echo
        echo "$resp" | jq -cr | grep -o "link[^,]*" | sed 's/.*\":\(.*\)/\1/g' | sed 's/\"\([^"]*\)\"/\1/g'
    else
        msg=$(echo "$resp"|grep -o "show_msg[^,]*" | sed 's/.*\":\(.*\)/\1/g')
        echo ${Notice}${msg}
    fi 

fi
echo