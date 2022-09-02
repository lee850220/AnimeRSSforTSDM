#!/bin/bash
PATH="/usr/local/bin:$PATH"
ScriptDIR=/etc/aria2
Notice="[RAR_TSDM.sh]: "
filename_ext="${1##*/}"
UploadConfig="${1}.upload"
ConfigFile=${ScriptDIR}/aria2.conf
CurlTimeout=15
ARG1="$1"
ARG2="$2"
ARG3="$3"
path=

# Check target file
if [[ ! -f "$1" ]] && [[ ! -d "$1" ]]; then
    echo "${Notice}${1} does not exist. Exit..."
    exit
fi

# Check target file is folder
if [ "${ARG2}" = "F" ]; then
    path=$1
else
    path="${1%/*}"
fi

# Get filepath
if [ "$path" = "$filename_ext" ]; then
    path=$(pwd)
else
    path="${path}/"
fi

# For RAR
header=[Inanity緋雪@TSDM]
PW=Inanity緋雪@僅分享於TSDM
CommentFile=${ScriptDIR}/comment.txt
filename="${filename_ext%.*}"
targetFile=${header}${filename}.rar
printf "DEBUG_LOGGER\n\$ConfigFile=${ConfigFile}\n\$1=${ARG1}\n\$2=${ARG2}\n\$path=${path}\n\$filename_ext=${filename_ext}\n\$filename=${filename}\n\$targetFile=${targetFile}\n"

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
FID=8  #動漫下載
TSDM_Cookie=$(cat ${ConfigFile} | grep TSDM_COOKIE | sed "s/.*'\(.*\)'/\1/")
FORMHASH=83cb7be3
MUTEX=/etc/aria2/TSDM.lock

############################################ FUNCTION DEFINITION #################################################

function CHECK_SEASON {

    if [ $FID -eq 8 ]; then
        season=$(head -4 "${UploadConfig}" | tail -1)
        if [ $season == "1" ]; then
            TYPE=50
        elif [ $season == "4" ]; then
            TYPE=51
        elif [ $season == "7" ]; then
            TYPE=52
        elif [ $season == "10" ]; then
            TYPE=53
        fi
    elif [ $FID -eq 405 ]; then
        TYPE=3142   # 4月
    fi

}

function RCUP {

    BREAK=0
	echo "${Notice}${pmtitle} Enter Critical Section, Taking Mutex..."
    while [ $BREAK -eq 0 ]; do
        if [ -e ${MUTEX} ]; then
            echo "${Notice}${pmtitle} Failed to enter CS. sleep 5 sec."
            sleep 5
        else
            touch ${MUTEX}
            echo "${Notice}${pmtitle} Succeed to enter CS."
            BREAK=1
        fi
    done
	
}

function RCDOWN {

    echo "${Notice}${pmtitle} Wait for 10 sec to release Mutex..."
    sleep 10
    rm -f ${MUTEX}
    echo "${Notice}${pmtitle} Mutex has been released."

}

function CHECK_UPLOAD {

    resp=$(BaiduPCS-Go meta "${uploadDIR}/${targetFile}" | grep "\[0\]" > /dev/null;echo $?)
    if [ $resp -ne 0 ]; then
        echo ${Notice}"File upload failed. Exit..."
        exit
    fi
    
}

function GET_FILEID {

    #fileID=$(curl -sX GET "${LIST_API}?app_id=${app_id}&bdstoken=${bdstoken}&channel=chunlei&clienttype=0&desc=0&dir=${uploadDIR}&logid=${logid}==&num=100&order=name&page=1&showempty=0&web=1" --header 'Host: pan.baidu.com' --header "${UserAgent}" --header "${BD_Cookie}" | jq '.' | fgrep -B 13 "${targetFile}" | grep "fs_id" | sed 's/[^0-9]//g')
    if [ "${ARG2}" = "F" ] && ! ${SINGLE_EP}; then
        if ${MOVED}; then
            cmd="BaiduPCS-Go meta "${FILELIST}
            fileID=$(${cmd} | grep fs_id | awk '{print $2}' | tr "\n" "," | sed "s/.$//")
        else
            fileID=$(BaiduPCS-Go meta "${uploadDIR}/${targetFile}/*" | grep fs_id | awk '{print $2}' | tr "\n" "," | sed "s/.$//")
        fi
    else
        if ${MOVED}; then
            fileID=$(BaiduPCS-Go meta "${DEST}/${targetFile}" | grep fs_id | awk '{print $2}')
        else
            fileID=$(BaiduPCS-Go meta "${uploadDIR}/${targetFile}" | grep fs_id | awk '{print $2}')
        fi
    fi

}

function GET_FILEID_FAIL {

echo " Failed."
curl -m ${CurlTimeout} -sX POST ${LINE_API} --header 'Content-Type: application/x-www-form-urlencoded' --header "Authorization: Bearer ${LINE_TOKEN}" --data-urlencode \
"Message=     Task failed. (reason: cannot get fileID)
[Task]：     ${targetFile}";echo
exit

}

function CSHARE {

    Response=$(curl -m ${CurlTimeout} -sX POST "${SHARE_API}?bdstoken=${bdstoken}&channel=chunlei&web=1&app_id=${app_id}&logid=${logid}==&clienttype=0" --header 'Host: pan.baidu.com' --header "${UserAgent}" --header "${BD_Cookie}" --data-urlencode 'schannel=4' --data-urlencode 'channel_list=[]' --data-urlencode 'period=0' --data-urlencode "pwd=${sharePW}" --data-urlencode "fid_list=[${fileID}]")
    LINK=$(echo $Response | jq '.link' | sed 's/.*"\(.*\)".*/\1/')

}

function CSHARE_FAIL {

echo " Failed."
curl -m ${CurlTimeout} -sX POST ${LINE_API} --header 'Content-Type: application/x-www-form-urlencoded' --header "Authorization: Bearer ${LINE_TOKEN}" --data-urlencode \
"Message=     Task failed. (reason: cannot get share link)
[Task]：     ${NEW}";echo
exit

}

function FILENAME_PARSE {

    NEW=$(echo "${ORIGIN}"| sed 's/\(\\\)\{0,1\},//g')

}

function CHECK_INTERNET {
    resp=$(curl -m ${CurlTimeout} -s google.com >& /dev/null; echo $?)
    if [ $resp -ne 0 ]; then
        echo "${Notice}${filename_ext} Internet connection lost...Stop task."
        exit
    fi
}

function CLEAN_FILES {
    if [ "${ARG2}" = "F" ] && ! ${SINGLE_EP}; then
        rm -rfv "${NEW}/*.rar"
    else
        rm -rfv "${NEW}"
    fi
}

function GET_EPISODE {

    resp=$(echo "${filename}"|grep "\[[0-9]\{2,4\}\-[0-9]\{2,4\}\]" > /dev/null;echo $?)
    if [ $resp -eq 0 ]; then
        # multiple episode (bracket)
        episode=$(echo "${filename}"|grep -o "\[[0-9]\{2,4\}\-[0-9]\{2,4\}\]"|tr -d "[]")
    else
        resp=$(echo "${filename}"|grep "\[\(SP\)\{0,1\}[0-9]\{2,3\}\(v[1-9]\)\{0,1\}\]" > /dev/null;echo $?)
        if [ $resp -eq 0 ]; then
            # single episode (bracket)
            episode=$(echo "${filename}"|grep -o "\[\(SP\)\{0,1\}[0-9]\{2,3\}\(v[1-9]\)\{0,1\}\]"|tr -d "[]")
            resp=$(echo "${filename}"|grep "\[v[1-9]\]" > /dev/null;echo $?)
            if [[ $resp -eq 0 ]]; then
                episode=${episode}$(echo "${filename}"|sed "s/.*\[\(v[1-9]\)\].*/\1/")
            fi
            resp=$(echo "${filename}"|grep "\[SP\]" > /dev/null;echo $?)
            if [[ $resp -eq 0 ]]; then
                episode="SP"${episode}
            fi
        else
            # single episode (no bracket)
            episode=$(echo "${filename}"|grep -o "\ \(SP\)\{0,1\}[0-9]\{2,3\}\(v[1-9]\)\{0,1\}[^.0-9A-Za-z[]]\{0,1\}"|tr -d " ")
            if [[ $episode == "" ]]; then
                episode=$(echo "${filename}"|grep -o "\ \(SP\)\{0,1\}[0-9]\{2,3\}\(v[1-9]\)\{0,1\}$"|tr -d " ")
            fi
        fi
    fi
    
}

function CHECK_FOLDER {
    
    resp=$(echo ${episode}|grep "[0-9]\-[0-9]" > /dev/null;echo $?)
    if [[ $resp -eq 0 ]]; then
        SINGLE_EP=false
        echo ${Notice}"[Folder Mode] Multiple!!"
    else
        SINGLE_EP=true
        echo ${Notice}"[Folder Mode] Single!"
    fi

}

function GET_FILESIZE {
    
    if [ "${ARG2}" = "F" ] && ! ${SINGLE_EP}; then
        filesize=$(find "${NEW}" -type f -name "*.m[kp][4v]" -exec du -ch {} + | grep total$ | awk '{print $1}')
    else
        filesize=$(stat -c %s "${NEW}"|numfmt --to=iec)
    fi

}

####################################################### MAIN ############################################################

if [[ ! -f ${UploadConfig} ]]; then 
    echo "${Notice}\"${filename_ext}\" no need to upload. Exit..."
    exit
fi
GET_EPISODE

# Package file by RAR
if [ "${ARG2}" = "F" ]; then
    CHECK_FOLDER
    SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")

    if ${SINGLE_EP}; then
        echo "${Notice}Packaging \"${filename_ext}\" with RAR..."
        ORIGIN="${path}${targetFile}"
        FILENAME_PARSE
        rar a -ep -hp"${PW}" -rr3 -idcdn -k -t -htb -c- -c -z"${CommentFile}" "${NEW}" "${path}"
        MD5=$(md5sum "${NEW}" | awk '{print $1}')
        SHA1=$(sha1sum "${NEW}" | awk '{print $1}')
    else
        echo "MD5        SHA1        FILENAME" > "${path}checksum.txt"
        for file in $(ls "${path}"*.m[kp][4v]|sed 's/.*\///'); do
            ORIGIN="${path}${header}${file%.*}"
            FILENAME_PARSE
            rar a -ep -hp"${PW}" -rr3 -idcdn -k -t -htb -c- -c -z"${CommentFile}" "${NEW}.rar" "${path}${file}"
            MD5=$(md5sum "${NEW}.rar" | awk '{print $1}')
            SHA1=$(sha1sum "${NEW}.rar" | awk '{print $1}')
            echo ${MD5} ${SHA1} "${header}${file%.*}.rar" >> "${path}checksum.txt"
        done
        MD5="參見鏈接內的checksum.txt (非完結合集不提供)"
        SHA1="參見鏈接內的checksum.txt (非完結合集不提供)"
    fi
    IFS=$SAVEIFS
else
    echo "${Notice}Packaging \"${filename_ext}\" with RAR..."
    ORIGIN="${path}${targetFile}"
    FILENAME_PARSE
    rar a -ep -hp"${PW}" -rr3 -idcdn -k -t -htb -c- -c -z"${CommentFile}" "${NEW}" "${path}${filename_ext}"
    MD5=$(md5sum "${NEW}" | awk '{print $1}')
    SHA1=$(sha1sum "${NEW}" | awk '{print $1}')
fi

# Upload to Baidu
CHECK_INTERNET
UL_START=$(date +%s)
if [ "${ARG2}" = "F" ] && ! ${SINGLE_EP}; then
    echo "${Notice}Uploading files in \"${path}\" via BaiduPCS-Go..."
    BaiduPCS-Go mkdir "${uploadDIR}/${filename}"
    for file in $(ls "${path}"*.m[kp][4v]|sed 's/.*\///'); do
        ORIGIN="${path}${header}${file%.*}"
        FILENAME_PARSE
        BaiduPCS-Go upload "${NEW}.rar" "${uploadDIR}/${filename}"
    done
    BaiduPCS-Go upload "${path}checksum.txt" "${uploadDIR}/${filename}"
    NEW="${path}"
    targetFile="${filename}"
else
    echo "${Notice}Uploading \"${targetFile}\" via BaiduPCS-Go..."
    ORIGIN="${path}${targetFile}"
    FILENAME_PARSE
    BaiduPCS-Go upload "${NEW}" ${uploadDIR}
fi
UL_FINISH=$(date +%s)
echo "${Notice}Upload process terminated."
targetFile=$(echo ${targetFile}|tr -d ",")
CHECK_UPLOAD

if [ "${ARG2}" == "NP" ] || [ "${ARG3}" == "NP" ]; then 
    exit
fi

# Moving file to specific directory
CHECK_INTERNET
ptitle=$(head -1 "${UploadConfig}"|perl -pe 's/\xe2\x80\x8b\x0a//')
pmtitle=$(echo "${ptitle}" | sed "s/\(.*\)\(\[[0-9]\{0,4\}P.*\].*\)/\1[${episode}]\2/")
EPISODE_NAME=$(echo ${ptitle}|sed 's/[][]/ /g' | awk '{print $2}'| opencc -c s2twp)
SRC="${uploadDIR}/${targetFile}"
DEST="/TSDM/${EPISODE_NAME}/${ptitle}"
echo "${Notice}Moving \"${targetFile}\" to \"${DEST}\"..."

# Check destination (share folder)
resp=$(BaiduPCS-Go meta "${DEST}")
check=$(echo ${resp}|grep "\[0\]" >& /dev/null;echo $?)
if [ $check -ne 0 ]; then
    echo "${Notice}Destination not found."
    curl -m ${CurlTimeout} -sX POST ${LINE_API} --header 'Content-Type: application/x-www-form-urlencoded' --header "Authorization: Bearer ${LINE_TOKEN}" --data-urlencode \
"Message=     Moving file failed. Destination not found.
[Task]：      ${pmtitle}"; echo
    MOVED=false
else
    # Check exist
    if [ "${ARG2}" = "F" ] && ! ${SINGLE_EP}; then
        FILELIST=
        for file in $(ls "${path}"*.rar|sed 's/.*\///'); do
            resp=$(BaiduPCS-Go meta \"${DEST}/${file}\"|grep "\[0\]" >& /dev/null;echo $?)
            if [ $resp -eq 0 ]; then
                echo "${Notice}\"${file}\" already exist."
                BaiduPCS-Go rm "${uploadDIR}/${filename}/${file}"
            else
                BaiduPCS-Go mv "${uploadDIR}/${filename}/${file}" "${DEST}"
            fi
            FILELIST="${DEST}/${file} ${FILELIST}"
        done
        BaiduPCS-Go rm "${uploadDIR}/${filename}"
    else
        resp=$(BaiduPCS-Go meta \"${DEST}/${targetFile}\"|grep "\[0\]" >& /dev/null;echo $?)
        if [ $resp -eq 0 ]; then
            echo "${Notice}\"${targetFile}\" already exist."
            BaiduPCS-Go rm "${SRC}"
        else
            BaiduPCS-Go mv "${SRC}" "${DEST}"
        fi
    fi
    MOVED=true
fi

# Get file ID
CHECK_INTERNET
echo "${Notice}Getting file ID..."
Retry=0
while true
do
    GET_FILEID
    if ([ "${fileID}" = "null" ] || [ "${fileID}" = "" ]); then
        if (( $Retry == 5 )); then
            GET_FILEID_FAIL
        else
            (( Retry = Retry + 1 ))
            echo "Failed. Sleep 10 sec and retry. Retry ${Retry}/5..."
            sleep 10
        fi
    else
        echo " Success."
        break
    fi
done

# Create share link
CHECK_INTERNET
echo -n "${Notice}Creating share link of ${fileID}..."
Retry=0
while true
do
    CSHARE
    if ([ "${LINK}" = "null" ] || [ "${LINK}" = "" ]); then
        if (( $Retry == 5 )); then
            CSHARE_FAIL
        else
            (( Retry = Retry + 1 ))
            echo "Failed. Sleep 10 sec and retry. Retry ${Retry}/5..."
            sleep 10
        fi
    else
        echo " Success."
        echo "${Notice}Your link is \"${LINK}\" with password \"${sharePW}\""
        break
    fi
done

# Auto post to TSDM
CHECK_INTERNET
echo "${Notice}Posting main post on TSDM..."
pubURL=$(head -2 "${UploadConfig}" | tail -1)
pubDate=$(head -3 "${UploadConfig}" | tail -1)
post=$(tail -n +5 "${UploadConfig}" | sed '$ d')
GET_FILESIZE
CHECK_SEASON
RCUP
echo "curl -m ${CurlTimeout} -sX POST \"https://www.tsdm39.net/forum.php?mod=post&action=newthread&fid=${FID}&topicsubmit=yes\" --header \"${TSDM_Cookie}\" --form \"formhash=${FORMHASH}\" --form \"typeid=${TYPE}\" --form \"subject=${pmtitle}[${filesize}]\" --form 'usesig=\"1\"' --form 'allownoticeauthor=\"1\"' --form 'addfeed=\"1\"' --form 'wysiwyg=\"0\"' --form \"message=[align=center][b]*****This post is generated by script wrote by Inanity緋雪, 
if you find any problems please contact me ASAP, thanks.*****[/align][/b]
[table=98%]
[tr][td]鏈接[/td][td=90%] [url=${LINK}]${LINK}[/url][/td][/tr]
[tr][td]提取碼[/td][td]${sharePW}[/td][/tr]
[tr][td]解壓碼[/td][td] [b][color=Red][size=6]${PW}[/size][/color][/b][/td][/tr]
[tr][td]發佈源[/td][td][url=${pubURL}]${pubURL}[/url][/td][/tr]
[tr][td]發佈時間[/td][td]${pubDate}[/td][/tr]
[tr][td]MD5[/td][td]${MD5}[/td][/tr]
[tr][td]SHA1[/td][td]${SHA1}[/td][/tr]
[tr][td]備註[/td][td]壓縮包皆含[color=DarkOrange]3%[/color]紀錄，若有壞檔請自行嘗試修復。[/td][/tr]
[/table]\""
response=$(curl -m ${CurlTimeout} -sX POST "https://www.tsdm39.net/forum.php?mod=post&action=newthread&fid=${FID}&topicsubmit=yes" --header "${TSDM_Cookie}" --form "formhash=${FORMHASH}" --form "typeid=${TYPE}" --form "subject=${pmtitle}[${filesize}]" --form 'usesig="1"' --form 'allownoticeauthor="1"' --form 'addfeed="1"' --form 'wysiwyg="0"' --form "message=[align=center][b]*****This post is generated by script wrote by Inanity緋雪, 
if you find any problems please contact me ASAP, thanks.*****[/align][/b]
[table=98%]
[tr][td]鏈接[/td][td=90%] [url=${LINK}]${LINK}[/url][/td][/tr]
[tr][td]提取碼[/td][td]${sharePW}[/td][/tr]
[tr][td]解壓碼[/td][td] [b][color=Red][size=6]${PW}[/size][/color][/b][/td][/tr]
[tr][td]發佈源[/td][td][url=${pubURL}]${pubURL}[/url][/td][/tr]
[tr][td]發佈時間[/td][td]${pubDate}[/td][/tr]
[tr][td]MD5[/td][td]${MD5}[/td][/tr]
[tr][td]SHA1[/td][td]${SHA1}[/td][/tr]
[tr][td]備註[/td][td]壓縮包皆含[color=DarkOrange]3%[/color]紀錄，若有壞檔請自行嘗試修復。[/td][/tr]
[/table]")
echo $response; echo
RCDOWN
TID=$(echo ${response}|sed "s/.*tid=\([0-9]*\)&.*/\1/")
echo "${Notice}Posting sub-post on TSDM..."
RCUP
curl -m ${CurlTimeout} -sX POST "https://www.tsdm39.net/forum.php?mod=post&action=reply&fid=${FID}&tid=${TID}&replysubmit=yes" --header "${TSDM_Cookie}" --form "formhash=${FORMHASH}" --form "typeid=${TYPE}" --form 'usesig="1"' --form "message=${post}"; echo
RCDOWN

# Push notify
CHECK_INTERNET
echo "${Notice}Push notification to LINE..."
DL_START=$(tail -1 "${UploadConfig}"|awk '{print $1}')
DL_FINISH=$(tail -1 "${UploadConfig}"|awk '{print $2}')

if [ -z "${DL_START}" ] || [ -z "${DL_FINISH}" ]; then
    SKIP=true
    echo ${Notice}"Skipping push notification."
else
    SKIP=false
fi

if ! ${SKIP}; then
    echo calculating...
    DLTIME=$(${ScriptDIR}/convertime.sh $((${DL_FINISH}-${DL_START})))
else
    DLTIME='No Record.'
fi
ULTIME=$(${ScriptDIR}/convertime.sh $((${UL_FINISH}-${UL_START})))

curl -m ${CurlTimeout} -sX POST ${LINE_API} --header 'Content-Type: application/x-www-form-urlencoded' --header "Authorization: Bearer ${LINE_TOKEN}" --data-urlencode \
"Message=     Task has been completed.
[Task]：      ${pmtitle}
[TSDM]：   https://www.tsdm39.net/forum.php?mod=viewthread&tid=${TID}
[Baidu]：    ${LINK}
[PW]：       ${sharePW}
[DLTime]： ${DLTIME}
[ULTime]： ${ULTIME}"; echo

CLEAN_FILES

#echo "${Notice}Editing index post on TSDM..."
##group=$(echo ${ptitle} | sed 's/.*【\(.*\)】.*/\1/')
#group="爱恋&漫猫字幕组"
#group=$(echo $group | sed 's/&/&amp;/g')
#TID=1103066
#PID=66072107
#response=$(curl -sX GET "https://www.tsdm39.net/forum.php?mod=post&action=edit&fid=${FID}&tid=${TID}&pid=${PID}&page=1" --header "${TSDM_Cookie}")
#echo $response | grep -o \<textarea.*\</textarea\> | tr '\n' '!' | sed 's/\r/\n/g' | sed 's/[\>\<]/\n/g' | sed '1,2d' | head -n -2 | tr '\n' '\r' | tr '!' '\n' > res
##| grep -o \<textarea.*\</textarea\> | tr '\r' '\n' | sed 's/[\>\<]/\n/g' | sed '1,2d' | head -n -2 > res
