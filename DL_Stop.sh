#!/bin/bash
#=====================================================
# File name：DL_Stop.sh
# Description: Delete files, .aria2 file, and torrent file after Aria2 download error
# Author: Kelvin Lee
#=====================================================

# Aria2下載目錄
downloadpath='/var/www/html/nextcloud/data/lee850220/files/Aria2'
scriptpath='/etc/aria2'

#=====================================================
function CLEAN_FILES {
	echo [DL_Stop.sh]" "searching match torrent...
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
	rm -vf "$path.aria2" "$path.complete" "$path.upload" "${downloadpath}/[Inanity緋雪@TSDM]${filename_noext}.rar"
}

function NORMAL {
	echo [DL_Stop.sh]" "[NORMAL Mode]
	if [ "${path##*.}" != "torrent" ]
	then
		echo [DL_Stop.sh]" "moving file...
		mv -v "$path" "$downloadpath/TEMP"
	else
		echo [DL_Stop.sh]" "This is torrent file, DO NOT move.
	fi
	rm -fv "$path.aria2"
	exit 0
}

function BT_SINGLE {
	echo [DL_Stop.sh]" "[Single BT Mode]
	CLEAN_FILES
	echo [DL_Stop.sh]" "moving file...
	mv -v "$path" "$downloadpath/TEMP"
	if [ "$?" != "0" ]; then rm -rfv "$path"; fi
	exit 0
}

function BT_FOLDER {
	echo [DL_Stop.sh]" "[Multi BT Mode]
	CLEAN_FILES
	echo [DL_Stop.sh]" "moving file...
	mv -v "$path" "$downloadpath/TEMP"
	if [ "$?" != "0" ]; then rm -rfv "$path"; fi
	exit 0
}


filepath=$3
rdp=${filepath#${downloadpath}/}
path=${downloadpath}/${rdp%%/*}
filename=${path#${downloadpath}/}
filename_noext=${filename_ext%.*}
echo -e "[DL_Stop.sh] ""\"${path}\""" Download Stop!!!"

if [ $2 -eq 0 ]
    then
		# No File
        echo "[DL_Stop.sh] ""[No file exist]"
        exit 0
elif [ "$path" = "$filepath" ] && [ $2 -eq 1 ]
    then
		# One File
		hash=$(python "$scriptpath"/aria2_to_magnet.py "$path".aria2)
		IFS=$'\n'
		for file in $(ls $downloadpath/*.torrent); do
			hash1=$(python "$scriptpath"/infohash.py "$file")
			if [ "$hash" = "$hash1" ]; then 
				[ -e "$path.upload" ] && /etc/aria2/rar_TSDM.sh "${path}" && rm -fv "${downloadpath}/[Inanity緋雪@TSDM]${filename}.rar"
				BT_SINGLE
			fi
		done
		unset IFS
		NORMAL;
		
elif [ "$path" != "$filepath" ]
    then
		# Folder
		BT_FOLDER        
fi
