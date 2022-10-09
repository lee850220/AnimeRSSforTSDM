#!/bin/bash
#=====================================================
# File name：delete.sh
# Description: Delete files, .aria2 file, and torrent file after Aria2 download error
# Author: Kelvin Lee
#=====================================================

# Aria2下載目錄
downloadpath='/var/www/html/nextcloud/data/lee850220/files/Aria2'
scriptpath='/etc/aria2'

#=====================================================
function CLEAN_FILES {
	echo [delete.sh]" "searching match torrent...
	hash=$(aria2mgt "$path".aria2 | awk -F ':' '{print $4}')
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	for file in $(ls $downloadpath/*.torrent); do
		hash1=$(transmission-show -i "$file" | grep Hash | awk '{print $2}')
		if [ "$hash" = "$hash1" ]
		then
			rm -vf "$file" "$file.aria2"
		fi
	done
	IFS=$SAVEIFS
	rm -rvf "$path.aria2" "$path" "$path.complete" "$path.upload"
}

function NORMAL {
	echo [delete.sh]" "[NORMAL Mode]
	rm -fv "$path" "$path.aria2"
	exit 0
}

function BT_SINGLE {
	echo [delete.sh]" "[Single BT Mode]
	CLEAN_FILES
	exit 0
}

function BT_FOLDER {
	echo [delete.sh]" "[Multi BT Mode]
	CLEAN_FILES
	exit 0
}


filepath=$3
rdp=${filepath#${downloadpath}/}
path=${downloadpath}/${rdp%%/*}
filename=${path#${downloadpath}/}
echo -e "[delete.sh] ""\"${path}\""" Download Stop!!!"

if [ $2 -eq 0 ]
    then
		# No File
        echo "[delete.sh] ""[No file exist]"
        exit 0
elif [ "$path" = "$filepath" ] && [ $2 -eq 1 ]
    then
		# One File
		hash=$(aria2mgt "$path".aria2 | awk -F ':' '{print $4}')
		SAVEIFS=$IFS
		IFS=$(echo -en "\n\b")
		echo "[delete.sh] Finding torrents..."
		for file in $(ls $downloadpath/*.torrent); do
			hash1=$(transmission-show -i "$file" | grep Hash | awk '{print $2}')
			if [ "$hash" = "$hash1" ]; then 
				[ -e "$path.upload" ] && /etc/aria2/rar_TSDM.sh "${path}" && rm -fv "${downloadpath}/[Inanity緋雪@TSDM]${filename}.rar"
				BT_SINGLE
			fi
		done
		IFS=$SAVEIFS
		NORMAL;
elif [ "$path" != "$filepath" ]
    then
		# Folder
		BT_FOLDER        
fi
