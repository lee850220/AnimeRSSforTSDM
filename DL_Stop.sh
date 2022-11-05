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
source /root/.bashrc
Notice="[DL_Stop.sh]: "
#=====================================================
function CLEAN_FILES {
	echo "${Notice}searching match torrent..."
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
		echo "${Notice}Cannot found torrent file."
	fi
	rm -fv "$path.aria2" "$path.complete" "$path.upload" "$path.NP" "${downloadpath}/[Inanity緋雪@TSDM]${filename_noext}.rar"
}

function NORMAL {
	echo "${Notice}[NORMAL Mode]"
	if [ "${path}" == *"torrent" ];	then
		echo "${Notice}moving file..."
		mv -v "$path" "$DL${filename}"
	else
		echo "${Notice}This is torrent file, DO NOT move."
	fi
	rm -fv "$path.aria2"
	exit 0
}

function BT_SINGLE {
	echo "${Notice}[Single BT Mode]"
	echo "${Notice}moving file..."
	if [[ -f "$path.upload" ]]; then
		mv -v "$path" "$TSDM${filename}"
		if [ "$?" != "0" ]; then rm -rfv "$path"; fi
	else
		mv -v "$path" "$DL${filename}"
	fi
	CLEAN_FILES
	exit 0
}

function BT_FOLDER {
	echo "${Notice}[Multi BT Mode]"
	echo "${Notice}moving file..."
	if [[ -f "$path.upload" ]]; then
		mv -v "$path" "$TSDM${filename}"
		if [ "$?" != "0" ]; then rm -rfv "$path"; fi
	else
		mv -v "$path" "$DL${filename}"
	fi
	CLEAN_FILES
	exit 0
}


filepath=$3
rdp=${filepath#${downloadpath}/}
path=${downloadpath}/${rdp%%/*}
filename=${path#${downloadpath}/}
filename_noext=${filename_ext%.*}
echo -e "${Notice}\"${path}\" Download Stop!!!"

if [ $2 -eq 0 ]
    then
		# No File
        echo "${Notice}[No file exist]"
        exit 0
elif [ "$path" = "$filepath" ] && [ $2 -eq 1 ]
    then
		# One File
		if [[ $path == *"torrent" ]]; then
  			echo "${Notice}torrent file. Skip..."
			rm -fv "$path.aria2"
			exit 0
		fi
		hash=$(aria2mgt "$path".aria2 | awk -F ':' '{print $4}')
		SAVEIFS=$IFS
		IFS=$(echo -en "\n\b")
		for file in $(ls $downloadpath/*.torrent); do
			hash1=$(transmission-show -i "$file" | grep Hash | awk '{print $2}')
			if [ "$hash" = "$hash1" ]; then 
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
