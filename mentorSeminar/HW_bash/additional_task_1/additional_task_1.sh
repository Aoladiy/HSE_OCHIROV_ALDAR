#!/usr/bin/env bash

echo "!!! additional task 1 !!!"

echo "Enter the path to the directory to back up:"
read -r source_dir

if [ ! -d "$source_dir" ]; then
    echo "Error: directory does not exist"
    exit 1
fi

backup_dir="$HOME/backups"
date_stamp=$(date +%Y%m%d_%H%M%S)
current_backup="$backup_dir/backup_$date_stamp"
log_file="$backup_dir/backup.log"

mkdir -p "$current_backup"

echo "$(date): Backup started from $source_dir" >> "$log_file"

shopt -s nullglob dotglob
count=0

for file in "$source_dir"/*; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        base="${filename%.*}"
        ext="${filename##*.}"
        if [[ "$filename" == "$ext" ]]; then
            newname="${filename}_${date_stamp}"
        else
            newname="${base}_${date_stamp}.${ext}"
        fi

        if cp -- "$file" "$current_backup/$newname"; then
            count=$((count + 1))
            echo "$(date): Copied $filename -> $newname" >> "$log_file"
        else
            echo "$(date): ERROR copying $filename" >> "$log_file"
        fi
    fi
done

echo "$(date): Backup finished. Files: $count" >> "$log_file"
echo ""
echo "Backup completed!"
echo "Files copied: $count"
echo "Backup directory: $current_backup"
echo "Log file: $log_file"

if command -v notify-send >/dev/null 2>&1; then
    notify-send "Backup completed" "Files: $count • Dir: $current_backup"
fi
