#!/usr/bin/env bash

if test -t 0; then  # stdin is terminal, not piped
    if [ $# -eq 0 ]; then
        echo "No arguments specified.\nUsage:\n transfer <file|directory>\n ... | transfer <file_name>">&2
        return 1
    fi
    file="$1"
    file_name=$(basename "$file")
    if [ ! -e "$file" ]; then
        echo "$file: No such file or directory">&2
        return 1
    fi
    if [ -d "$file" ]; then
        file_name="$file_name.zip"
        (cd "$file"&&zip -r -q - .)|curl --header "Max-Days: 7" --progress-bar --upload-file "-" "https://transfer.home.vanginderachter.be/$file_name"
    else
        cat "$file"|curl --header "Max-Days: 7" --progress-bar --upload-file "-" "https://transfer.home.vanginderachter.be/$file_name"
    fi
else
    cat - | curl --header "Max-Days: 7" --progress-bar --upload-file "-" "https://transfer.home.vanginderachter.be/$file_name"
fi
