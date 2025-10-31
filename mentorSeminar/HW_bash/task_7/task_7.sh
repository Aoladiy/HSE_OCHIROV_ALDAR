#!/usr/bin/env bash

echo "!!! task 6 !!!"

alias ll='ls -la'
echo "Alias created: ll='ls -la'"

echo ""
echo "To make the alias permanent, add the following to ~/.bashrc:"
echo "alias ll='ls -la'"
echo "Then run: source ~/.bashrc"

echo ""
echo "Tab completion works automatically"
echo "Example: cd /etc/nixo[Tab] -> cd /etc/nixos"
