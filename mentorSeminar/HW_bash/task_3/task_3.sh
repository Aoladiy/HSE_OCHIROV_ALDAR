#!/usr/bin/env bash

echo "!!! task 3 !!!"

echo "Enter a number:"
read number

if [ "$number" -gt 0 ]; then
    echo "The number is positive"
    echo "Counting from 1 to $number:"
    counter=1
    while [ $counter -le "$number" ]; do
        echo -n "$counter "
        counter=$((counter + 1))
    done
    echo ""
elif [ "$number" -lt 0 ]; then
    echo "The number is negative"
else
    echo "The number is zero"
fi
