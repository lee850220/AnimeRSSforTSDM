#!/usr/bin/bash
############################################### Description ###############################################
#
# This file is used to clean unused torrent files.
# Get the magnet link from torrent file and aria2 control file and compare it.
# If cannot find a match, then remove it.
#
# Support single file or folder (both relative and absolute path)
# e.g. ./clean_torrent.sh 12345.torrent
#      ./clean_torrent.sh .                 # current folder
#
################################################### End ###################################################

Path=$1
Amagnet=
Tmagnet=
cnt=0
match=false

if [[ -d $Path ]]; then

    Path=$(realpath $Path)
    SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
    for file in $(ls $Path/*.torrent); do
        Tmagnet=$(transmission-show -m "$file" | grep -o "^[^&]*" | tr '[:upper:]' '[:lower:]')
        match=false
        for file2 in $(ls $Path/*.aria2); do
            Amagnet=$(python3 /etc/aria2/aria2_to_magnet.py "$file2" | grep -o "[^,]*$" | tr -d " " | tr '[:upper:]' '[:lower:]')
            if [[ $Tmagnet == $Amagnet ]]; then
                match=true
                break
            fi
        done
        if ! $match; then
            rm -v "$file"
            (( cnt++ ))
        fi
    done
    IFS=$SAVEIFS
    echo "Removed $cnt files."

elif [[ -f $Path ]]; then

    File="$Path"
    Tmagnet=$(transmission-show -m "$File" | grep -o "^[^&]*" | tr '[:upper:]' '[:lower:]')
    Path=$(realpath $Path)
    Path=${Path%/*}
    SAVEIFS=$IFS
    IFS=$(echo -en "\n\b")
    for file in $(ls $Path/*.aria2); do
        Amagnet=$(python3 /etc/aria2/aria2_to_magnet.py "$file" | grep -o "[^,]*$" | tr -d " " | tr '[:upper:]' '[:lower:]')
        if [[ $Tmagnet == $Amagnet ]]; then
            match=true
            break
        fi
    done
    IFS=$SAVEIFS
    if ! $match; then
        rm -v "$file"
    fi

else
    echo "invalid path."
fi