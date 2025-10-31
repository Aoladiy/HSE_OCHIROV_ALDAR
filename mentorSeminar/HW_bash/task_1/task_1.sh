#!/usr/bin/env bash

echo "!!! task 1 !!!"

for item in *; do
    if [ -d "$item" ]; then
        echo "  [DIR]  $item"
    elif [ -f "$item" ]; then
        echo "  [FILE] $item"
    fi
done

filename="$1"

if [ -e "$filename" ]; then
    echo "file '$filename' is found"
else
    echo "file '$filename' not found"
fi

echo ""
echo "filenames and their rights:"
for item in *; do
    if [ -e "$item" ]; then
        ls -ld "$item" | awk '{print $1, $9}'
    fi
done
