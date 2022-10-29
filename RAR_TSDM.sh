#!/bin/bash
source /root/.bashrc
PATH="/usr/local/bin:$PATH"
ScriptDIR="/etc/aria2"

filename_ext="${1##*/}"
UploadConfig="${1}.upload"
ConfigFile="${ScriptDIR}/aria2.conf"
ARG1="$1"
ARG2="$2"
ARG3="$3"

Notice="[RAR_TSDM.sh]: "
CLEAR_LINE="\r\033[K"
path=
RAPIDLIST=
FILELIST=

CurlTimeout=120
ConnectTimeout=5
RetryTimeout=5
MAX_RETRY=10
CurlFlag="-g --connect-timeout ${ConnectTimeout} -m ${CurlTimeout} -sX"
ContentType="Content-Type: application/x-www-form-urlencoded"

DEBUG=false
NP=false
FIN=false
NOUP=false
NO_CLEAN=false
FAILSHARE=false
FAILSHARE_SKIP=true

if ${DEBUG}; then
    echo ${Notice}"Debug mode enabled!"
fi

# Check target file
if [[ ! -f "$1" ]] && [[ ! -d "$1" ]]; then
    echo "${Notice}${1} does not exist. Exit..."
    exit
fi

# Check target file is folder
if [ "${ARG2}" = "F" ]; then
    path=$1/
else
    path="${1%/*}"
fi

# Get filepath
if [ "$path" = "$filename_ext" ]; then
    path=$(pwd)/
else
    path="${path}/"
fi

path=$(echo $path|sed 's,\/\/,/,g')

if [ "${ARG2}" == "NOUP" ]; then
    NOUP=true
fi

if ([ "${ARG2}" == "NP" ] || [ "${ARG3}" == "NP" ] || [ "${ARG2}" == "FIN" ]); then
    NP=true
    if [ "${ARG2}" == "FIN" ]; then
        FIN=true
    fi
fi

# For RAR
RAR_RECOVERY=5
header="[Inanity緋雪@TSDM]"
PW="InanitySnow@TSDM"
CommentFile="${ScriptDIR}/comment.txt"
filename="${filename_ext%.*}"
targetFile="${header}${filename}.rar"
printf "DEBUG_LOGGER\n\$ConfigFile=${ConfigFile}\n\$1=${ARG1}\n\$2=${ARG2}\n\$path=${path}\n\$filename_ext=${filename_ext}\n\$filename=${filename}\n\$targetFile=${targetFile}\n"

# For Baidu
export BAIDUPCS_GO_CONFIG_DIR="${ScriptDIR}"
uploadDIR="/apps/bypy"
app_id="250528"
LIST_API="https://pan.baidu.com/api/list"
SHARE_API="https://pan.baidu.com/share/set"
bdstoken=$(cat ${ConfigFile} | grep bdstoken | sed 's/.*=//')
logid=$(cat ${ConfigFile} | grep logid | sed 's/.*=//')
BD_Cookie=$(cat ${ConfigFile} | grep BD_COOKIE | sed "s/.*'\(.*\)'/\1/")
UserAgent="User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.54 Safari/537.36"
sharePW="TSDM"

# For LINE
LINE_API="https://notify-api.line.me/api/notify"
LINE_TOKEN=$(cat ${ConfigFile} | grep LINE= | sed 's/.*=//' | sed 's/[^0-9A-Za-z]//')

# For TSDM
FID=405 #吸血貓
FID=8   #動漫下載
TSDM_Cookie=$(cat ${ConfigFile} | grep TSDM_COOKIE | sed "s/.*'\(.*\)'/\1/")
FORMHASH="8114d641"
MUTEX="${ScriptDIR}/TSDM.lock"

############################################ FUNCTION DEFINITION #################################################

function CHECK_SEASON {

    season=$(head -4 "${UploadConfig}" | tail -1)
    if [ $FID -eq 8 ]; then
        if [ $season == "1" ]; then
            TYPE=50
        elif [ $season == "4" ]; then
            TYPE=51
        elif [ $season == "7" ]; then
            TYPE=52
        elif [ $season == "10" ]; then
            TYPE=45
        fi
    elif [ $FID -eq 405 ]; then
        if [ $season == "1" ]; then
            TYPE=3143
        elif [ $season == "4" ]; then
            TYPE=3142
        elif [ $season == "7" ]; then
            TYPE=3141
        elif [ $season == "10" ]; then
            TYPE=3140
        fi
    fi

}

function RCUP {

    BREAK=0
	echo -n "${Notice}${pmtitle} Enter Critical Section, Taking Mutex... "
    while [ $BREAK -eq 0 ]; do
        if [ -e ${MUTEX} ]; then
            echo "Failed. sleep 5 sec."
            sleep 5
        else
            touch ${MUTEX}
            echo "Success."
            BREAK=1
        fi
    done
	
}

function RCDOWN {

    echo -n "${Notice}${pmtitle} Wait for 10 sec to release Mutex... "
    sleep 10
    rm -f ${MUTEX}
    echo "OK"

}

function UPLOAD_FAILED {

    echo ${Notice}"File upload failed. Exit..."
    curl ${CurlFlag} POST ${LINE_API} --header "${ContentType}" --header "Authorization: Bearer ${LINE_TOKEN}" --data-urlencode \
"Message=     Task failed. (reason: File upload failed)
[Task]：     ${targetFile}";echo
    exit

}

function GET_FILEID {

    echo -n "${Notice}Getting file ID... "
    while true
    do
        if [ "${ARG2}" = "F" ] && ! ${SINGLE_EP}; then
            if ${MOVED}; then
                for file in ${FILELIST}; do
                    file=$(echo $file|tr "%" " ")
                    fileID=$(BaiduPCS-Go meta "$file"| grep fs_id | awk '{print $2}' | tr "\n" ",")"$fileID"
                done
                fileID=$(echo $fileID|sed 's/,$//')
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

        if ([ "${fileID}" = "null" ] || [ "${fileID}" = "" ]); then
            if (( $Retry == 5 )); then

                echo "Failed."
                echo -n ${Notice}"Get fileID failed. Push notification to LINE & Exit..."
                resp=$(curl ${CurlFlag} POST ${LINE_API} --header "${ContentType}" --header "Authorization: Bearer ${LINE_TOKEN}" --data-urlencode \
"Message=     Task failed. (reason: Cannot get fileID)
[Task]：     ${targetFile}")

                chk=$(echo "${resp}"| grep -o "status[^,]*" | grep -o "[0-9]*")
                if [ "$chk" = "200" ]; then
                    echo "Success."
                else
                    resp=$(echo $resp| grep -o "message[^}]*" | tr -d "\"" | sed 's/message://')
                    echo "Failed. (reason: ${resp})"
                fi
                exit

            else

                (( Retry = Retry + 1 ))
                echo "Failed. Sleep 10 sec and retry. Retry ${Retry}/5..."
                sleep 10

            fi
        else
            echo "Success."
            break
        fi
    done
    #fileID=$(curl ${CurlFlag} GET "${LIST_API}?app_id=${app_id}&bdstoken=${bdstoken}&channel=chunlei&clienttype=0&desc=0&dir=${uploadDIR}&logid=${logid}==&num=100&order=name&page=1&showempty=0&web=1" --header 'Host: pan.baidu.com' --header "${UserAgent}" --header "${BD_Cookie}" | jq '.' | fgrep -B 13 "${targetFile}" | grep "fs_id" | sed 's/[^0-9]//g')

}

function CSHARE {

    Retry=0
    while true
    do
        echo -n "${Notice}Creating share link of ${fileID}... "
        resp=$(curl ${CurlFlag} POST "${SHARE_API}?bdstoken=${bdstoken}&channel=chunlei&web=1&app_id=${app_id}&logid=${logid}==&clienttype=0" --header 'Host: pan.baidu.com' --header "${UserAgent}" --header "${BD_Cookie}" --data-urlencode 'schannel=4' --data-urlencode 'channel_list=[]' --data-urlencode 'period=0' --data-urlencode "pwd=${sharePW}" --data-urlencode "fid_list=[${fileID}]")
        chk=$(echo "${resp}"| grep -o "errno[^,]*" | grep -o "[0-9]*")
        if [ "$chk" = "0" ]; then

            echo "Success."
            LINK=$(echo $resp | jq '.link' | sed 's/.*"\(.*\)".*/\1/')
            echo "${Notice}Your link is \"${LINK}\" with password \"${sharePW}\""
            break

        else

            (( Retry = Retry + 1 ))
            if ${DEBUG}; then
                echo $resp
            fi
            if [ "$resp" = "" ]; then
                echo "Failed. (reason: Empty response.)"
            else
                resp=$(echo $resp| grep -o "show_msg[^}]*" | tr -d "\"" | sed 's/show_msg://')
                echo "Failed. (reason: ${resp})"
            fi

            if ( (( $Retry == $MAX_RETRY )) || [ "$resp" = "您好，由于系统升级，分享功能暂不可用，升级完成后恢复正常" ] ); then
                
                if ! $FAILSHARE_SKIP; then

                    if (( $Retry == $MAX_RETRY )); then
                        echo ${Notice}"Reach Max Retry. Get share link failed. Exit..."
                        reason="Reach max retry, cannot get share link"
                    else
                        echo ${Notice}"Baidu blocked share function. Get share link failed. Exit..."
                        reason="Baidu blocked share function, cannot get share link"
                    fi

                    resp=$(curl ${CurlFlag} POST ${LINE_API} --header "${ContentType}" --header "Authorization: Bearer ${LINE_TOKEN}" --data-urlencode \
"Message=     Task failed. (reason: ${reason})
[Task]：     ${filename_ext}")
                    exit

                else

                    if (( $Retry == $MAX_RETRY )); then
                        echo ${Notice}"Reach Max Retry. Get share link failed. Can skip..."
                    else
                        echo ${Notice}"Baidu blocked share function. Get share link failed. Can skip..."
                    fi
                    LINK="${resp}"
                    FAILSHARE=true
                    break

                fi

            fi
            
            echo "${Notice}Sleep ${RetryTimeout} sec and retry. Retry ${Retry}/${MAX_RETRY}..."
            sleep ${RetryTimeout}
            

        fi
    done

}

function FILENAME_PARSE {

    NEW=$(echo "${ORIGIN}"| sed 's/\(\\\)\{0,1\},//g')

}

function CHECK_INTERNET {
    resp=$(curl -g -m ${CurlTimeout} -s google.com >& /dev/null; echo $?)
    if [ $resp -ne 0 ]; then
        echo "${Notice}${filename_ext} Internet connection lost...Stop task."
        exit
    fi
}

function GET_EPISODE {

    resp=$(echo "${filename}"|grep "[^0-9A-Za-z][0-9]\{2,4\}\-[0-9]\{2,4\}\(End\)\{0,1\}\(END\)\{0,1\}\(Fin\)\{0,1\}\(FIN\)\{0,1\}\(Fin\)\{0,1\}[^0-9A-Za-z]*" > /dev/null;echo $?)
    if [ $resp -eq 0 ]; then
        # multiple episode (bracket)
        episode=$(echo "${filename}"|grep -o "[^0-9A-Za-z][0-9]\{2,4\}\-[0-9]\{2,4\}\(End\)\{0,1\}\(END\)\{0,1\}\(Fin\)\{0,1\}\(FIN\)\{0,1\}\(Fin\)\{0,1\}[^0-9A-Za-z]*"|tr -d " []()")
        resp=$(echo "$episode"|grep -e "FIN" -e "Fin" -e "fin" -e "END" -e "End" > /dev/null;echo $?)
        if [ $resp -eq 0 ]; then
            episode=$(echo $episode|tr -d "A-Za-z")
            start_ep=$(echo $episode | awk -F'-' '{print $1}')
            end_ep=$(echo $episode | awk -F'-' '{print $2}')
            (( epis = end_ep - start_ep + 1 ))
            if [ $epis -ge 12 ]; then
                echo ${Notice}"Finish Episodes!!! Do NOT post."
                FIN=true
                NP=true
            fi
        else
            start_ep=$(echo $episode | awk -F'-' '{print $1}')
            end_ep=$(echo $episode | awk -F'-' '{print $2}')
            (( epis = end_ep - start_ep + 1 ))
            if [ $epis -ge 12 ]; then
                echo ${Notice}"Finish Episodes!!! Do NOT post."
                FIN=true
                NP=true
            fi
        fi
        SINGLE_EP=false
    elif ${FIN}; then
        # finish episode
        SINGLE_EP=false
    else
        resp=$(echo "${filename}"|grep "\[\(SP\)\{0,1\}\(Q\)\{0,1\}[0-9]\{2,3\}\(v[1-9]\)\{0,1\}集\{0,1\}\]" > /dev/null;echo $?)
        if [ $resp -eq 0 ]; then
            # single episode (bracket)
            episode=$(echo "${filename}"|grep -o "\[\(SP\)\{0,1\}\(Q\)\{0,1\}[0-9]\{2,3\}\(v[1-9]\)\{0,1\}集\{0,1\}\]"|tr -d "[]Q集")
            resp=$(echo "${filename}"|grep "\[[Vv][1-9]\]" > /dev/null;echo $?)
            if [[ $resp -eq 0 ]]; then
                episode=${episode}$(echo "${filename}"|sed "s/.*\[[Vv]\([1-9]\)\].*/v\1/")
            fi
            resp=$(echo "${filename}"|grep "\[SP\]" > /dev/null;echo $?)
            if [[ $resp -eq 0 ]]; then
                episode="SP"${episode}
            fi
        else
            # single episode (no bracket)
            episode=$(echo "${filename}"|grep -o "\ \(SP\)\{0,1\}\(Q\)\{0,1\}[0-9]\{2,3\}\([Vv][1-9]\)\{0,1\}[^.0-9A-Za-z[]]\{0,1\}"|tr -d " ")
            if [[ $episode == "" ]]; then
                episode=$(echo "${filename}"|grep -o "\ \(SP\)\{0,1\}[0-9]\{2,3\}\([Vv][1-9]\)\{0,1\}$"|tr -d " "|sed "s/.*[Vv]\([1-9]\)\].*/v\1/")
            fi
        fi
        SINGLE_EP=true
    fi

    if [[ $episode == "" ]]; then
        echo ${Notice}"Cannot find any episode info. Maybe finish episode. Do NOT post."
        curl ${CurlFlag} POST ${LINE_API} --header "${ContentType}" --header "Authorization: Bearer ${LINE_TOKEN}" --data-urlencode \
"Message=     [Warning]: Cannot find any episode info. Maybe finish episode. Do NOT post.
[Task]：     ${filename_ext}";echo
        FIN=true
        NP=true
    fi

}

function GET_FILESIZE {
    
    if [ "${ARG2}" = "F" ] && ! ${SINGLE_EP}; then
        filesize=$(find "${NEW}" -type f -name "*.m[kp][4v]" -exec du -ch {} + | grep total$ | awk '{print $1}')
    else
        filesize=$(stat -c %s "${NEW}"|numfmt --to=iec)
    fi

}

function CLEAN_FILES {

    if ! ${NO_CLEAN}; then

        if [ "${ARG2}" = "F" ] && ! ${SINGLE_EP}; then
            rm -rfv "${path}*.rar"
        else    
            rm -rfv "${NEW}"
        fi
        rm -fv "${NEW}.NP"

    fi

}
####################################################### MAIN ############################################################

if [[ ! -f ${UploadConfig} ]]; then 
    NOUP=true
fi
GET_EPISODE

# Package file by RAR
if ([ "${ARG2}" = "F" ] || ${FIN}); then
    SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
    if ${SINGLE_EP}; then
        echo ${Notice}"[Folder Mode] Single!"
        echo "${Notice}Packaging \"${filename_ext}\" with RAR..."
        ORIGIN="${path}${targetFile}"
        FILENAME_PARSE
        echo "rar a -ep -hp"${PW}" -rr${RAR_RECOVERY} -idcdn -k -t -htb -c- -c -z"${CommentFile}" "${NEW}" "${path}""
        rar a -ep -hp"${PW}" -rr${RAR_RECOVERY} -idcdn -k -t -htb -c- -c -z"${CommentFile}" "${NEW}" "${path}"
        MD5=$(md5sum "${NEW}" | awk '{print $1}')
        SHA1=$(sha1sum "${NEW}" | awk '{print $1}')
        tail -c256 "${NEW}" > "${path}tmp"
        MD5tmp=$(md5sum "${path}tmp" | awk '{print $1}')
        FILESIZE=$(stat -c %s "${NEW}")
        rm -f "${path}tmp"
        RAPIDLIST="${MD5}#${MD5tmp}#${FILESIZE}#${NEW##*/}"
    else
        echo ${Notice}"[Folder Mode] Multiple!!"
        for file in $(ls "${path}"*.m[kp][4v]|sed 's/.*\///'); do
            ORIGIN="${path}${header}${file%.*}"
            FILENAME_PARSE
            echo "rar a -ep -hp"${PW}" -rr${RAR_RECOVERY} -idcdn -k -t -htb -c- -c -z"${CommentFile}" "${NEW}.rar" "${path}${file}""
            rar a -ep -hp"${PW}" -rr${RAR_RECOVERY} -idcdn -k -t -htb -c- -c -z"${CommentFile}" "${NEW}.rar" "${path}${file}"
            MD5=$(md5sum "${NEW}.rar" | awk '{print $1}')
            tail -c256 "${NEW}.rar" > "${path}tmp"
            MD5tmp=$(md5sum "${path}tmp" | awk '{print $1}')
            FILESIZE=$(stat -c %s "${NEW}.rar")
            rm -f "${path}tmp"
            rapid="${MD5}#${MD5tmp}#${FILESIZE}#${NEW##*/}.rar"
            RAPIDLIST=$(printf ${rapid}\\n)"${RAPIDLIST}"
        done
        MD5="參見鏈接內的checksum.txt (非完結合集不提供)"
        SHA1="參見鏈接內的checksum.txt (非完結合集不提供)"
    fi
    IFS=$SAVEIFS
else
    echo "${Notice}Packaging \"${filename_ext}\" with RAR..."
    ORIGIN="${path}${targetFile}"
    FILENAME_PARSE
    rar a -ep -hp"${PW}" -rr${RAR_RECOVERY} -idcdn -k -t -htb -c- -c -z"${CommentFile}" "${NEW}" "${path}${filename_ext}"
    MD5=$(md5sum "${NEW}" | awk '{print $1}')
    SHA1=$(sha1sum "${NEW}" | awk '{print $1}')
    tail -c256 "${NEW}" > "${path}tmp"
    MD5tmp=$(md5sum "${path}tmp" | awk '{print $1}')
    FILESIZE=$(stat -c %s "${NEW}")
    rm -f "${path}tmp"
    RAPIDLIST="${MD5}#${MD5tmp}#${FILESIZE}#${NEW##*/}"
fi

if ${FIN}; then
    SAVEIFS=$IFS
    IFS=$(echo -en "\n\b")
    echo "${Notice}Calculating checksum..."
    echo "MD5                              SHA1                                      FILENAME" > "${path}checksum.txt"
    echo $path
    for file in $(ls "${path}"*.rar); do
        MD5=$(md5sum "${file}" | awk '{print $1}')
        SHA1=$(sha1sum "${file}" | awk '{print $1}')
        echo ${MD5} ${SHA1} "${file##*/}"
        echo ${MD5} ${SHA1} "${file##*/}" >> "${path}checksum.txt"
    done
    IFS=$SAVEIFS
    echo $RAPIDLIST > "${path}rapidlist.txt"
fi

if ${NOUP}; then
    echo $RAPIDLIST
    echo "${Notice}\"${filename_ext}\" no need to upload. Exit..."
    exit
fi

# Upload to Baidu
CHECK_INTERNET
Retry=0
while true
do
    UL_START=$(date +%s)
    if [ "${ARG2}" = "F" ] && ! ${SINGLE_EP}; then
        echo -n "${Notice}Uploading files in \"${path}\" via BaiduPCS-Go..."
        BaiduPCS-Go mkdir "${uploadDIR}/${filename}"
        SAVEIFS=$IFS
	    IFS=$(echo -en "\n\b")        
        for file in $(ls "${path}"*.m[kp][4v]|sed 's/.*\///'); do
            ORIGIN="${path}${header}${file%.*}"
            FILENAME_PARSE
            BaiduPCS-Go upload "${NEW}.rar" "${uploadDIR}/${filename}"
        done
        IFS=$SAVEIFS
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

    # Check Upload
    targetFile=$(echo ${targetFile}|tr -d ",")
    resp=$(BaiduPCS-Go meta "${uploadDIR}/${targetFile}" | grep "\[0\]" > /dev/null;echo $?)
    if [ $resp -ne 0 ]; then
        (( Retry = Retry + 1 ))
        if (( $Retry == 3 )); then
            UPLOAD_FAILED
        fi
        echo "Failed. Sleep 60 sec and retry. Retry ${Retry}/3..."
        sleep 60
    else
        echo "${Notice}Upload successed."
        break
    fi
done

# Moving file to specific directory
CHECK_INTERNET
ptitle=$(head -1 "${UploadConfig}"|perl -pe 's/\xe2\x80\x8b\x0a//')
pmtitle=$(echo "${ptitle}" | sed "s/\(.*\)\(\[[0-9]\{0,4\}P.*\].*\)/\1[${episode}]\2/")
EPISODE_NAME=$(echo ${ptitle}|sed 's/[][]/ /g' | awk '{print $2}'| opencc -c s2twp)
SRC="${uploadDIR}/${targetFile}"
DEST="/TSDM/${EPISODE_NAME}/${ptitle}"
echo "${Notice}Moving \"${targetFile}\" to \"${DEST}\"..."

# Check destination (share folder)
Retry=0
resp=$(BaiduPCS-Go meta "${DEST}")
check=$(echo ${resp}|grep "\[0\]" >& /dev/null;echo $?)
if [ $check -ne 0 ]; then
    echo -n "${Notice}Destination not found. Push notification to LINE... "
    resp=$(curl ${CurlFlag} POST ${LINE_API} --header "${ContentType}" --header "Authorization: Bearer ${LINE_TOKEN}" --data-urlencode \
"Message=     Moving file failed. Destination not found.
[Task]：      ${pmtitle}")
    
    chk=$(echo "${resp}"| grep -o "status[^,]*" | grep -o "[0-9]*")
    if [ "$chk" = "200" ]; then
        echo "Success."
    else
        resp=$(echo $resp| grep -o "message[^}]*" | tr -d "\"" | sed 's/message://')
        echo "Failed. (reason: ${resp})"
    fi

#    while true
#    do
#        resp=$(BaiduPCS-Go export --link --stdout "${SRC}"|head -n -1)
#        chk=$(echo "$resp"|grep "导出失败" >& /dev/null;echo $?)
#        if [ $chk -eq 0 ]; then
#            if (( $Retry == $MAX_RETRY )); then
#                NO_CLEAN=true
#                RAPIDLIST="Failed to get rapid link."
#                curl ${CurlFlag} POST ${LINE_API} --header "${ContentType}" --header "Authorization: Bearer ${LINE_TOKEN}" --data-urlencode \
#"Message=     Failed to get rapid link.
#[Task]：      ${SRC}"
#                break
#            fi
#            echo -ne ${CLEAR_LINE}${Notice}"Failed to get rapid link. Sleep 60 sec and retry...$Retry/$MAX_RETRY"
#            (( Retry = Retry + 1 ))
#            sleep 60
#        else
#            echo -e ${CLEAR_LINE}${Notice}"Success to get rapid link."
#            RAPIDLIST="$resp"
#            break
#        fi
#    done    
    MOVED=false
else
    # Check exist
    if [ "${ARG2}" = "F" ] && ! ${SINGLE_EP}; then
        SAVEIFS=$IFS
	    IFS=$(echo -en "\n\b")
        for file in $(ls "${path}"*.rar|sed 's/.*\///'); do
            resp=$(BaiduPCS-Go meta \"${DEST}/${file}\"|grep "\[0\]" >& /dev/null;echo $?)
            if [ $resp -eq 0 ]; then
                echo "${Notice}\"${file}\" already exist."
                BaiduPCS-Go rm "${uploadDIR}/${filename}/${file}"
            else
                BaiduPCS-Go mv "${uploadDIR}/${filename}/${file}" "${DEST}"
            fi
            FILELIST=$(echo "${DEST}/${file}"|tr " " "%")" ${FILELIST}"
            
#            while true
#            do
#                rapid=$(BaiduPCS-Go export --link --stdout "${DEST}/${file}"|head -1)
#                chk=$(echo "$rapid"|grep "导出失败" >& /dev/null;echo $?)
#                if [ $chk -eq 0 ]; then
#                    if (( $Retry == $MAX_RETRY )); then
#                        NO_CLEAN=true
#                        RAPIDLIST=$(printf ${file} Failed to get rapid link.\n)"${RAPIDLIST}"
#                        curl ${CurlFlag} POST ${LINE_API} --header "${ContentType}" --header "Authorization: Bearer ${LINE_TOKEN}" --data-urlencode \
#"Message=     Failed to get rapid link.
#[Task]：      ${DEST}/${file}"
#                        break
#                    fi
#                    echo -ne ${CLEAR_LINE}${Notice}"Failed to get rapid link. Sleep 60 sec and retry...$Retry/$MAX_RETRY"
#                    (( Retry = Retry + 1 ))
#                    sleep 60
#                else
#                    echo -e ${CLEAR_LINE}${Notice}"Success to get rapid link."
#                    RAPIDLIST=$(printf ${rapid}\n)"${RAPIDLIST}"
#                    break
#                fi
#            done
        done
        BaiduPCS-Go rm "${uploadDIR}/${filename}"
        IFS=$SAVEIFS
    else
        resp=$(BaiduPCS-Go meta "${DEST}/${targetFile}"|grep "\[0\]" >& /dev/null;echo $?)
        if [ $resp -eq 0 ]; then
            echo "${Notice}\"${targetFile}\" already exist."
            BaiduPCS-Go rm "${SRC}"
        else
            BaiduPCS-Go mv "${SRC}" "${DEST}"
        fi

#        while true
#        do
#            resp=$(BaiduPCS-Go export --link --stdout "${DEST}/${targetFile}"|head -1)
#            chk=$(echo "$resp"|grep "导出失败" >& /dev/null;echo $?)
#            if [ $chk -eq 0 ]; then
#                if (( $Retry == $MAX_RETRY )); then
#                    NO_CLEAN=true
#                    RAPIDLIST="Failed to get rapid link."
#                    curl ${CurlFlag} POST ${LINE_API} --header "${ContentType}" --header "Authorization: Bearer ${LINE_TOKEN}" --data-urlencode \
#"Message=     Failed to get rapid link.
#[Task]：      ${DEST}/${targetFile}"
#                    break
#                fi
#                echo -ne ${CLEAR_LINE}${Notice}"Failed to get rapid link. Sleep 60 sec and retry...$Retry/$MAX_RETRY"
#                (( Retry = Retry + 1 ))
#                sleep 60
#            else
#                echo -e ${CLEAR_LINE}${Notice}"Success to get rapid link."
#                RAPIDLIST="$resp"
#                break
#            fi
#        done
    fi
    MOVED=true
fi

if ${NP}; then
    CLEAN_FILES
    exit
fi

# Get file ID
CHECK_INTERNET
GET_FILEID

# Create share link
CHECK_INTERNET
CSHARE

# Auto post to TSDM
CHECK_INTERNET
echo "${Notice}Posting main post on TSDM..."
pubURL=$(head -2 "${UploadConfig}" | tail -1)
pubDate=$(head -3 "${UploadConfig}" | tail -1)
post=$(tail -n +5 "${UploadConfig}" | head -n -1)

if ${DEBUG}; then
    echo 11111111111111111111111111
    cat "${UploadConfig}"
    echo 44444444444444444444444444
    tail -n +5 "${UploadConfig}" | head -n -1
    echo 77777777777777777777777777
fi

GET_FILESIZE
CHECK_SEASON

if $FAILSHARE; then
    LINK_SEQ="[tr][td]鏈接[/td][td=85%] ${LINK}[/td][/tr]"
else
    LINK_SEQ="[tr][td]鏈接[/td][td=85%] [url=${LINK}]${LINK}[/url][/td][/tr]"
fi

if ${DEBUG}; then
echo "curl ${CurlFlag} POST \"https://www.tsdm39.net/forum.php?mod=post&action=newthread&fid=${FID}&topicsubmit=yes\" --header \"${TSDM_Cookie}\" --form \"formhash=${FORMHASH}\" --form \"typeid=${TYPE}\" --form \"subject=${pmtitle}[${filesize}]\" --form 'usesig=\"1\"' --form 'allownoticeauthor=\"1\"' --form 'addfeed=\"1\"' --form 'wysiwyg=\"0\"' --form \"message=[align=center][b]*****This post is generated by script wrote by Inanity緋雪, 
if you find any problems please contact me ASAP, thanks.*****[/align][/b]
[table=98%]
${LINK_SEQ}
[tr][td]提取碼[/td][td]${sharePW}[/td][/tr]
[tr][td]解壓碼[/td][td] [b][color=Red][size=6]${PW}[/size][/color][/b][/td][/tr]
[tr][td]發佈源[/td][td][url=${pubURL}]${pubURL}[/url][/td][/tr]
[tr][td]發佈時間[/td][td]${pubDate}[/td][/tr]
[tr][td]MD5[/td][td]${MD5}[/td][/tr]
[tr][td]SHA1[/td][td]${SHA1}[/td][/tr]
[tr][td]秒傳(夢姬)[/td][td]${RAPIDLIST}[/td][/tr]
[tr][td]備註[/td][td]壓縮包皆含[color=DarkOrange]${RAR_RECOVERY}%[/color]紀錄，若有壞檔請自行嘗試修復。
文件有問題請先使用校驗碼驗證後再發問。[/td][/tr]
[/table]\""
fi
RCUP
response=$(curl ${CurlFlag} POST "https://www.tsdm39.net/forum.php?mod=post&action=newthread&fid=${FID}&topicsubmit=yes" --header "${TSDM_Cookie}" --form "formhash=${FORMHASH}" --form "typeid=${TYPE}" --form "subject=${pmtitle}[${filesize}]" --form 'usesig="1"' --form 'allownoticeauthor="1"' --form 'addfeed="1"' --form 'wysiwyg="0"' --form "message=[align=center][b]*****This post is generated by script wrote by Inanity緋雪, 
if you find any problems please contact me ASAP, thanks.*****[/align][/b]
[table=98%]
${LINK_SEQ}
[tr][td]提取碼[/td][td]${sharePW}[/td][/tr]
[tr][td]解壓碼[/td][td] [b][color=Red][size=6]${PW}[/size][/color][/b][/td][/tr]
[tr][td]發佈源[/td][td][url=${pubURL}]${pubURL}[/url][/td][/tr]
[tr][td]發佈時間[/td][td]${pubDate}[/td][/tr]
[tr][td]MD5[/td][td]${MD5}[/td][/tr]
[tr][td]SHA1[/td][td]${SHA1}[/td][/tr]
[tr][td]秒傳(夢姬)[/td][td]${RAPIDLIST}[/td][/tr]
[tr][td]備註[/td][td]壓縮包皆含[color=DarkOrange]${RAR_RECOVERY}%[/color]紀錄，若有壞檔請自行嘗試修復。
文件有問題請先使用校驗碼驗證後再發問。[/td][/tr]
[/table]")
RCDOWN
resp=$(echo "${response}"|grep "文档已移动" > /dev/null;echo $?)
if [ $resp -eq 0 ]; then
    echo ${Notice}Posting main post on TSDM... Success.
else
    if ${DEBUG}; then
        echo $response; echo
    fi
fi

# Post reply to TSDM
TID=$(echo ${response}|grep -o "tid=\([0-9]*\)&"|sed "s/.*tid=\([0-9]*\)&.*/\1/")
if [[ $TID != "" ]]; then
    echo "${Notice}Posting reply on TSDM..."
    RCUP
    response=$(curl ${CurlFlag} POST "https://www.tsdm39.net/forum.php?mod=post&action=reply&fid=${FID}&tid=${TID}&replysubmit=yes" --header "${TSDM_Cookie}" --form "formhash=${FORMHASH}" --form "typeid=${TYPE}" --form 'usesig="1"' --form "message=${post}")
    resp=$(echo "${response}"|grep "文档已移动" > /dev/null;echo $?)
    RCDOWN
    if [ $resp -eq 0 ]; then
        echo ${Notice}Posting reply on TSDM... Success.
    else
        echo ${Notice}"TSDM post reply failed. Exit..."
        echo $response; echo
        exit
    fi
    
else
    echo -n ${Notice}"TSDM post failed. Push notification to LINE & Exit... "
    resp=$(curl ${CurlFlag} POST ${LINE_API} --header "${ContentType}" --header "Authorization: Bearer ${LINE_TOKEN}" --data-urlencode \
"Message=     Task failed. (reason: TSDM post failed)
[Task]：      ${NEW}")
    
    chk=$(echo "${resp}"| grep -o "status[^,]*" | grep -o "[0-9]*")
    if [ "$chk" = "200" ]; then
        echo "Success."
    else
        resp=$(echo $resp| grep -o "message[^}]*" | tr -d "\"" | sed 's/message://')
        echo "Failed. (reason: ${resp})"
    fi
    exit
fi


# Push notification
CHECK_INTERNET
echo -n "${Notice}Push notification to LINE... "
DL_START=$(tail -1 "${UploadConfig}"|awk '{print $1}')
DL_FINISH=$(tail -1 "${UploadConfig}"|awk '{print $2}')

if [ -z "${DL_START}" ] || [ -z "${DL_FINISH}" ]; then
    SKIP=true
else
    SKIP=false
fi

if ! ${SKIP}; then
    if ${DEBUG}; then
        echo calculating download time...
    fi
    DLTIME=$(${ScriptDIR}/convertime.sh $((${DL_FINISH}-${DL_START})))
else
    DLTIME='No Record.'
fi
ULTIME=$(${ScriptDIR}/convertime.sh $((${UL_FINISH}-${UL_START})))

resp=$(curl ${CurlFlag} POST ${LINE_API} --header "${ContentType}" --header "Authorization: Bearer ${LINE_TOKEN}" --data-urlencode \
"Message=     Task has been completed.
[Task]：      ${pmtitle}
[TSDM]：   https://www.tsdm39.net/forum.php?mod=viewthread&tid=${TID}
[Baidu]：    ${LINK}
[PW]：       ${sharePW}
[DLTime]： ${DLTIME}
[ULTime]： ${ULTIME}";)

chk=$(echo "${resp}"| grep -o "status[^,]*" | grep -o "[0-9]*")
if [ "$chk" = "200" ]; then
    echo "Success."
else
    resp=$(echo $resp| grep -o "message[^}]*" | tr -d "\"" | sed 's/message://')
    echo "Failed. (reason: ${resp})"
fi

CLEAN_FILES

#echo "${Notice}Editing index post on TSDM..."
##group=$(echo ${ptitle} | sed 's/.*【\(.*\)】.*/\1/')
#group="爱恋&漫猫字幕组"
#group=$(echo $group | sed 's/&/&amp;/g')
#TID=1103066
#PID=66072107
#response=$(curl -g -sX GET "https://www.tsdm39.net/forum.php?mod=post&action=edit&fid=${FID}&tid=${TID}&pid=${PID}&page=1" --header "${TSDM_Cookie}")
#echo $response | grep -o \<textarea.*\</textarea\> | tr '\n' '!' | sed 's/\r/\n/g' | sed 's/[\>\<]/\n/g' | sed '1,2d' | head -n -2 | tr '\n' '\r' | tr '!' '\n' > res
##| grep -o \<textarea.*\</textarea\> | tr '\r' '\n' | sed 's/[\>\<]/\n/g' | sed '1,2d' | head -n -2 > res
