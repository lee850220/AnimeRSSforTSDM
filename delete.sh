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
	hash=$(python "$scriptpath"/aria2_to_magnet.py "$path".aria2)
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	for file in $(ls $downloadpath/*.torrent); do
		hash1=$(python "$scriptpath"/infohash.py "$file")
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
	if [ "${path##*.}" != "torrent" ]
	then
		echo [delete.sh]" "moving file...
		mv -v "$path" "$downloadpath/TEMP"
	else
		echo [delete.sh]" "This is torrent file, DO NOT move.
	fi
	rm -fv "$path.aria2"
	exit 0
}

function BT_SINGLE {
	echo [delete.sh]" "[Single BT Mode]
	CLEAN_FILES
	echo [delete.sh]" "moving file...
	mv -v "$path" "$downloadpath/TEMP"
	exit 0
}

function BT_FOLDER {
	echo [delete.sh]" "[Multi BT Mode]
	CLEAN_FILES
	echo [delete.sh]" "moving file...
	mv -v "$path" "$downloadpath/TEMP"
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
		if [ -e "$filename.torrent" ]; then BT_SINGLE; fi
		hash=$(python "$scriptpath"/aria2_to_magnet.py "$path".aria2)
		if [ -e "$downloadpath/$hash.torrent" ]; then BT_SINGLE $hash;
		else NORMAL;
		fi
elif [ "$path" != "$filepath" ]
    then
		# Folder
		BT_FOLDER        
fi
