#!/usr/bin/env bash

echo "!!! task 2 !!!"

echo ""
echo "PATH = $PATH"

echo ""
echo "directory to add in PATH:"
read new_dir
export PATH="$PATH:$new_dir"
echo "new PATH: $PATH"

echo ""
echo "To permanently change the PATH, add the following to ~/.bashrc:"
echo "export PATH=\"\$PATH:$new_dir\""
echo "Then run: source ~/.bashrc"
