#!/bin/bash
#============================================================
# File name：DL_BT.sh
# Description: Aria2 download completes
# Version: 1.9
# Author: Kelvin Lee
#============================================================

# Aria2下載目錄
scriptpath='/etc/aria2'
downloadpath='/var/www/html/nextcloud/data/lee850220/files/Aria2'

#============================================================
Notice="[DL_BT.sh]: "
source /root/.bashrc

function NORMAL {
	echo ${Notice}"task="${filename}" NORMAL mode, DO NOTHING."
	exit 0
}

function BT {
	touch "$path.complete"
	exit 0
}

DL_FIN=$(date +%s)
filepath=$3 # Aria2傳遞給腳本的檔路徑。BT下載有多個檔時該值為資料夾內第一個檔，如/root/Download/a/b/1.mp4
rdp=${filepath#${downloadpath}/} # 路徑轉換，去掉開頭的下載路徑。
path=${downloadpath}/${rdp%%/*} # 路徑轉換，BT下載檔案夾時為頂層資料夾路徑，普通單檔下載時與檔路徑相同。
filename=${path#${downloadpath}/}
echo "${Notice}RDP= "$rdp
echo "${Notice}DLP= "$downloadpath
echo "${Notice}P= "$path
echo "${Notice}FN= "$filename
echo "${Notice}""\"${path}\""" Download Completed!!!"

if [ -z $2 ]
then
    echo && echo ${Notice}"[ERROR] This script can only be used by passing parameters through Aria2."
    exit 1
elif [ $2 -eq 0 ]
then
    exit 0
fi


if [ $2 -eq 0 ]
    then
		# No File
        echo ${Notice}"[No file exist]"
        exit 0
elif [ "$path" = "$filepath" ] && [ $2 -eq 1 ]
then
	# One File
	if [[ $path == *"torrent" ]]; then
  		echo ${Notice}"torrent file. Skip..."
		exit 0
	fi
	# find torrent
	hash=$(aria2mgt "$path".aria2 | awk -F ':' '{print $4}')
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	for file in $(ls $downloadpath/*.torrent); do
		hash1=$(transmission-show -i "$file" | grep Hash | awk '{print $2}')
		if [ "$hash" = "$hash1" ]; then
			echo ${Notice}"BT mode"
			if [ -e "$path.upload" ]; then
				if [ -e "${path}.NP" ]; then
					echo ${Notice}"$path run with RAR_TSDM.sh." && /etc/aria2/RAR_TSDM.sh "${path}" "NP"
				else
					chk=$(tail -1 "$path.upload")
					if [ "$chk" = "" ]; then
						echo ${Notice}"$path run with RAR_TSDM.sh." && /etc/aria2/RAR_TSDM.sh "${path}"
					else
						echo ${Notice}"$path run with RAR_TSDM.sh." && echo $DL_FIN >> "$path.upload" && /etc/aria2/RAR_TSDM.sh "${path}"
					fi
					
				fi
			fi
			BT
		fi
	done
	IFS=$SAVEIFS
	NORMAL
	
elif [ "$path" != "$filepath" ]
then
	# Folder
	if [ -e "$path.upload" ]; then
		if [ -e "${path}.NP" ]; then
			echo ${Notice}"$path run with RAR_TSDM.sh." && /etc/aria2/RAR_TSDM.sh "${path}" "F" "NP"
		else
			chk=$(tail -1 "$path.upload")
			if [ "$chk" = "" ]; then
				echo ${Notice}"$path run with RAR_TSDM.sh." && /etc/aria2/RAR_TSDM.sh "${path}" "F"
			else
				echo ${Notice}"$path run with RAR_TSDM.sh." && echo $DL_FIN >> "$path.upload" && /etc/aria2/RAR_TSDM.sh "${path}" "F"
			fi
		fi
	fi
	BT        
fi


