#!/bin/bash
#=====================================================
# File name：DL_Stop.sh
# Description: Delete files, .aria2 file, and torrent file after Aria2 download error
# Author: Kelvin Lee
#=====================================================

# Aria2下載目錄
downloadpath='/var/www/html/nextcloud/data/lee850220/files/Aria2'
TSDM='/DATA/TSDM/TEMP/'
DL='/DATA/DL/'
scriptpath='/etc/aria2'
echo $1
echo $2
echo $3

#=====================================================
function CLEAN_FILES {
	echo [DL_Stop.sh]" "searching match torrent...
	hash=$(aria2mgt "$path".aria2 | awk -F ':' '{print $4}')
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	REMOVED=false
	for file in $(ls $downloadpath/*.torrent); do
		hash1=$(transmission-show -i "$file" | grep Hash | awk '{print $2}')
		if [ "$hash" = "$hash1" ]; then
			rm -fv "$file"
			REMOVED=true
			break
		fi
	done
	IFS=$SAVEIFS
	if ! ${REMOVED}; then
		echo ${Notice}"Cannot found torrent file."
	fi
	rm -fv "$path.aria2" "$path.complete" "$path.upload" "$path.NP" "${downloadpath}/[Inanity緋雪@TSDM]${filename_noext}.rar"
}

function NORMAL {
	echo [DL_Stop.sh]" "[NORMAL Mode]
	if [ "${path}" == *"torrent" ];	then
		echo [DL_Stop.sh]" "moving file...
		mv -v "$path" "$DL"
	else
		echo [DL_Stop.sh]" "This is torrent file, DO NOT move.
	fi
	rm -fv "$path.aria2"
	exit 0
}

function BT_SINGLE {
	echo [DL_Stop.sh]" "[Single BT Mode]
	echo [DL_Stop.sh]" "moving file...
	if [[ -f "$path.upload" ]]; then
		mv -v "$path" "$TSDM"
		if [ "$?" != "0" ]; then rm -rfv "$path"; fi
	else
		mv -v "$path" "$DL"
	fi
	CLEAN_FILES
	exit 0
}

function BT_FOLDER {
	echo [DL_Stop.sh]" "[Multi BT Mode]
	echo [DL_Stop.sh]" "moving file...
	if [[ -f "$path.upload" ]]; then
		mv -v "$path" "$TSDM"
		if [ "$?" != "0" ]; then rm -rfv "$path"; fi
	else
		mv -v "$path" "$DL"
	fi
	CLEAN_FILES
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
		if [[ $path == *"torrent" ]]; then
  			echo ${Notice}"torrent file. Skip..."
			exit 0
		fi
		hash=$(aria2mgt "$path".aria2 | awk -F ':' '{print $4}')
		SAVEIFS=$IFS
		IFS=$(echo -en "\n\b")
		for file in $(ls $downloadpath/*.torrent); do
			hash1=$(transmission-show -i "$file" | grep Hash | awk '{print $2}')
			if [ "$hash" = "$hash1" ]; then 
				#[ -e "$path.upload" ] && /etc/aria2/RAR_TSDM.sh "${path}"
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
