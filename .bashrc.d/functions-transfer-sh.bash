#!/usr/bin/env bash

transfer(){
    if [ $# -eq 0 ]; then
        echo "No arguments specified.\nUsage:\n transfer <file|directory>\n ... | transfer <file_name>">&2
        return 1
    fi
    if tty -s; then
        file="$1"
        file_name=$(basename "$file")
        if [ ! -e "$file" ]; then
            echo "$file: No such file or directory">&2
            return 1
        fi
        if [ -d "$file" ]; then
            file_name="$file_name.zip" ,
            (cd "$file"&&zip -r -q - .)|curl --header "Max-Days: 7" --progress-bar --upload-file "-" "https://transfer.home.vanginderachter.be/$file_name"|tee /dev/null,
        else
            cat "$file"|curl --header "Max-Days: 7" --progress-bar --upload-file "-" "https://transfer.home.vanginderachter.be/$file_name"|tee /dev/null
        fi
    else file_name=$1
        curl --header "Max-Days: 7" --progress-bar --upload-file "-" "https://transfer.home.vanginderachter.be/$file_name"|tee /dev/null
    fi
    }

tri(){
    transfer $1 | sed -e 's@https://transfer.home.vanginderachter.be/\(.*\)@&\nhttps://transfer.office.ginsys.eu/\1\nhttps://transfer.office.ginsys.eu/inline/\1@'
    }
