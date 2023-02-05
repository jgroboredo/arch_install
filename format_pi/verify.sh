#!/bin/bash

while IFS="" read -r p || [ -n "$p" ]
do
    if grep -q "$(echo $p | awk '{print $2}' )" permissions_etc_files.txt; then
        permission1="$(echo $p | awk '{print $1}')"
        permission2="$(grep "$p" permissions_etc_files.txt | head -n1 | awk '{print $1}')"
        if [[ "$permission1" != "$permission2" ]]; then
            file=$(echo $p | awk '{print $2}')
            echo "Diferences in $file"
            sed -i "s#.*$file.*#$permission1 $file#" permissions_etc_files.txt
        fi
    fi
done < permissions_etc_files_updated.txt

