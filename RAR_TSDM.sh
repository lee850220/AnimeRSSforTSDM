#!/bin/bash
PATH="/usr/local/bin:$PATH"
ScriptDIR=/etc/aria2
Notice="[RAR_TSDM.sh] "
path="${1%/*}/"
filename_ext="${1##*/}"
UploadConfig="${1}.upload"
ConfigFile=${ScriptDIR}/aria2.conf

if [ "$2" = "F" ]; then 
    path=$1
else
    path="${1%/*}/"
fi

# For RAR
header=[Inanity緋雪@TSDM]
PW=Inanity緋雪@僅分享於TSDM
CommentFile=${ScriptDIR}/comment.txt
filename="${filename_ext%.*}"
targetFile=${header}${filename}.rar

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

# For LINE
LINE_API=https://notify-api.line.me/api/notify
LINE_TOKEN=$(cat ${ConfigFile} | grep LINE= | sed 's/.*=//' | sed 's/[^0-9A-Za-z]//')

# For TSDM
#FID=405 #吸血貓
#TYPE=3142 #4月
FID=8
TYPE=51
TSDM_Cookie=$(cat ${ConfigFile} | grep TSDM_COOKIE | sed "s/.*'\(.*\)'/\1/")
FORMHASH=eee3130b
MUTEX=/etc/aria2/TSDM.lock

function RCUP {

    BREAK=0
	echo "${Notice}${ptitle} Enter Critical Section, Taking Mutex..."
    while [ $BREAK -eq 0 ]; do
        if [ -e ${MUTEX} ]; then
            echo "${Notice}${ptitle} Failed to enter CS. sleep 5 sec."
            sleep 5
        else
            touch ${MUTEX}
            echo "${Notice}${ptitle} Succeed to enter CS."
            BREAK=1
        fi
    done
	
}

function RCDOWN {

    echo "${Notice}${ptitle} Wait for 10 sec to release Mutex..."
    sleep 10
    rm -f ${MUTEX}
    echo "${Notice}${ptitle} Mutex has been released."

}

if [ ! -e ${UploadConfig} ]; then 
    echo "${Notice}${filename_ext} no need to upload. Exit..."
    exit
fi

# Package file by RAR
if [ "$2" = "F" ]; then
    echo "${Notice}Packaging files in \"${filename_ext}\" with RAR seperately..."
    SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
    for file in $(ls "${path}"/*.m[kp][4v]|sed 's/.*\///'); do
        echo
        rar a -ep -hp"${PW}" -rr3 -idcdn -k -t -htb -c- -c -z"${CommentFile}" "${path}/${header}${file%.*}.rar" "${path}/${file}"
	done
    IFS=$SAVEIFS
    
else
    echo "${Notice}Packaging \"${filename_ext}\" with RAR..."
    rar a -ep -hp"${PW}" -rr3 -idcdn -k -t -htb -c- -c -z"${CommentFile}" "${path}${targetFile}" "$1"
fi

# Upload to Baidu
UL_START=$(date +%s)
if [ "$2" = "F" ]; then
    echo "${Notice}Uploading files in \"${path}\" via BaiduPCS-Go..."
    BaiduPCS-Go upload "${path}" ${uploadDIR}
    targetFile=${path}
else
    echo "${Notice}Uploading \"${targetFile}\" via BaiduPCS-Go..."
    BaiduPCS-Go upload "${path}${targetFile}" ${uploadDIR}
fi
UL_FINISH=$(date +%s)
echo "${Notice}Upload process terminated."

if [ "$2" == "NP" ] || [ "$3" == "NP" ]; then 
    exit
fi

# get file ID
echo "${Notice}Getting file ID..."
fileID=$(curl -sX GET "${LIST_API}?app_id=${app_id}&bdstoken=${bdstoken}&channel=chunlei&clienttype=0&desc=0&dir=${uploadDIR}&logid=${logid}==&num=100&order=name&page=1&showempty=0&web=1" --header 'Host: pan.baidu.com' --header "${UserAgent}" --header "${BD_Cookie}" | jq '.' | fgrep -B 13 "${targetFile}" | grep "fs_id" | sed 's/[^0-9]//g')
if [ "${fileID}" = "" ]; then

echo " Failed."
curl -sX POST ${LINE_API} --header 'Content-Type: application/x-www-form-urlencoded' --header "Authorization: Bearer ${LINE_TOKEN}" --data-urlencode \
"Message=     Task failed. (reason: cannot get fileID)
[Task]：     ${pmtitle}";echo
exit

else
    echo " Success."
fi

# create share link
echo -n "${Notice}Creating share link of ${fileID}..."
Response=$(curl -sX POST "${SHARE_API}?bdstoken=${bdstoken}&channel=chunlei&web=1&app_id=${app_id}&logid=${logid}==&clienttype=0" --header 'Host: pan.baidu.com' --header "${UserAgent}" --header "${BD_Cookie}" --data-urlencode 'schannel=4' --data-urlencode 'channel_list=[]' --data-urlencode 'period=0' --data-urlencode "pwd=${sharePW}" --data-urlencode "fid_list=[${fileID}]")
LINK=$(echo $Response | jq '.link' | sed 's/.*"\(.*\)".*/\1/')
if [ "${LINK}" = "null" ]; then

echo " Failed."
curl -sX POST ${LINE_API} --header 'Content-Type: application/x-www-form-urlencoded' --header "Authorization: Bearer ${LINE_TOKEN}" --data-urlencode \
"Message=     Task failed. (reason: cannot get share link)
[Task]：     ${pmtitle}";echo
exit

else
    echo " Success."
fi
echo "${Notice}Your link is \"${LINK}\" with password \"${sharePW}\""

# auto post to TSDM
echo "${Notice}Posting main post on TSDM..."
episode=$(echo ${filename}|sed "s/.*[ []E\{0,1\}\([0-2][0-9]\)[] ].*/\1/")
ptitle=$(head -1 "${UploadConfig}")
pmtitle=$(echo "${ptitle}" | sed "s/\(.*\)\(\[1080P\].*\)/\1[${episode}]\2/")
post=$(tail -n +2 "${UploadConfig}" | sed '$ d')
filesize=$(stat -c %s "${path}${targetFile}"|numfmt --to=iec)
RCUP
response=$(curl -sX POST "https://www.tsdm39.net/forum.php?mod=post&action=newthread&fid=${FID}&topicsubmit=yes" --header "${TSDM_Cookie}" --form "formhash=${FORMHASH}" --form "typeid=${TYPE}" --form "subject=${pmtitle}[${filesize}]" --form 'usesig="1"' --form 'allownoticeauthor="1"' --form 'addfeed="1"' --form 'wysiwyg="0"' --form "message=[align=center][b]This is a post generated by script wrote by Inanity緋雪, 
if you find any problem please contact me ASAP, thanks.[/align][/b]
[table=98%]
[tr][td]鏈接[/td][td=90%] [url=${LINK}]${LINK}[/url][/td][/tr]
[tr][td]提取碼[/td][td]${sharePW}[/td][/tr]
[tr][td]解壓碼[/td][td] [b][color=Red][size=6]${PW}[/size][/color][/b][/td][/tr]
[tr][td]備註[/td][td]壓縮包皆含[color=DarkOrange]3%[/color]紀錄，若有壞檔請自行嘗試修復。[/td][/tr]
[/table]")
echo $response; echo
RCDOWN
TID=$(echo ${response}|sed "s/.*tid=\([0-9]*\)&.*/\1/")
echo "${Notice}Posting sub-post on TSDM..."
RCUP
curl -sX POST "https://www.tsdm39.net/forum.php?mod=post&action=reply&fid=${FID}&tid=${TID}&replysubmit=yes" --header "${TSDM_Cookie}" --form "formhash=${FORMHASH}" --form "typeid=${TYPE}" --form 'usesig="1"' --form "message=${post}"; echo
RCDOWN

# push notify
echo "${Notice}Push notification to LINE..."
DL_START=$(tail -1 "${UploadConfig}"|awk '{print $1}')
DL_FINISH=$(tail -1 "${UploadConfig}"|awk '{print $2}')
DLTIME=$(${ScriptDIR}/convertime.sh $((${DL_FINISH}-${DL_START})))
ULTIME=$(${ScriptDIR}/convertime.sh $((${UL_FINISH}-${UL_START})))
curl -sX POST ${LINE_API} --header 'Content-Type: application/x-www-form-urlencoded' --header "Authorization: Bearer ${LINE_TOKEN}" --data-urlencode \
"Message=     Task has been completed.
[Task]：      ${pmtitle}
[TSDM]：   https://www.tsdm39.net/forum.php?mod=viewthread&tid=${TID}
[Baidu]：    ${LINK}
[PW]：       ${sharePW}
[DLTime]： ${DLTIME}
[ULTime]： ${ULTIME}"; echo

rm -rfv "${path}${targetFile}"

# moving file to specific directory
EPISODE_NAME=$(echo ${ptitle}|sed 's/[][]/ /g' | awk '{print $2}')
echo "${Notice}Moving ${targetFile} to /TSDM/${EPISODE_NAME}/${ptitle}..."
BaiduPCS-Go mv "${uploadDIR}/${targetFile}" "/TSDM/${EPISODE_NAME}/${ptitle}/"


#echo "${Notice}Editing index post on TSDM..."
##group=$(echo ${ptitle} | sed 's/.*【\(.*\)】.*/\1/')
#group="爱恋&漫猫字幕组"
#group=$(echo $group | sed 's/&/&amp;/g')
#TID=1103066
#PID=66072107
#response=$(curl -sX GET "https://www.tsdm39.net/forum.php?mod=post&action=edit&fid=${FID}&tid=${TID}&pid=${PID}&page=1" --header "${TSDM_Cookie}")
#echo $response | grep -o \<textarea.*\</textarea\> | tr '\n' '!' | sed 's/\r/\n/g' | sed 's/[\>\<]/\n/g' | sed '1,2d' | head -n -2 | tr '\n' '\r' | tr '!' '\n' > res
##| grep -o \<textarea.*\</textarea\> | tr '\r' '\n' | sed 's/[\>\<]/\n/g' | sed '1,2d' | head -n -2 > res
