#!/usr/bin/env bash

echo "!!! task 6 !!!"

cat > input.txt << EOF
afsdgsdfg 1
sdfgsdfgsdfg 2
adsfgsdfgsdfg 3
adsfgsdfgsdfas__9g 4
adsfgs2sdfg 5


EOF

echo "File input.txt has been created"

wc -l < input.txt > output.txt
echo "The number of lines has been written to output.txt"
cat output.txt

ls nonexistent_file 2> error.log
echo "The error has been written to error.log"
cat error.log
