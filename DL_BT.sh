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

function NORMAL {
	echo [DL_BT.sh]" NORMAL mode, DO NOTHING."
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
echo "[DL_BT.sh] RDP= "$rdp
echo "[DL_BT.sh] DLP= "$downloadpath
echo "[DL_BT.sh] P= "$path
echo "[DL_BT.sh] FN= "$filename
echo "[DL_BT.sh] ""\"${path}\""" Download Completed!!!"

if [ -z $2 ]
then
    echo && echo "[DL_BT.sh] ""[ERROR] This script can only be used by passing parameters through Aria2."
    exit 1
elif [ $2 -eq 0 ]
then
    exit 0
fi


if [ $2 -eq 0 ]
    then
		# No File
        echo "[DL_BT.sh] ""[No file exist]"
        exit 0
elif [ "$path" = "$filepath" ] && [ $2 -eq 1 ]
then
	# One File
	# find torrent
	hash=$(aria2mgt "$path".aria2 | awk -F ':' '{print $4}')
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	for file in $(ls $downloadpath/*.torrent); do
		hash1=$(transmission-show -i "$file" | grep Hash | awk '{print $2}')
		if [ "$hash" = "$hash1" ]; then
			echo [DL_BT.sh]" "BT mode
			[ -e "$path.upload" ] && echo $DL_FIN >> "$path.upload" && /etc/aria2/RAR_TSDM.sh "${path}"
			BT
		fi
	done
	IFS=$SAVEIFS
	NORMAL;
	
elif [ "$path" != "$filepath" ]
then
	# Folder (need fix)
	[ -e "$path.upload" ] && echo $DL_FIN >> "$path.upload" && /etc/aria2/RAR_TSDM.sh "${path}" "F"
	BT        
fi


