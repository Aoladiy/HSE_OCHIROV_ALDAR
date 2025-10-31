#!/usr/bin/env bash

echo "!!! task 4 !!!"

say_hello() {
    echo "Hello, $1"
}

num_sum() {
    result=$(($1 + $2))
    echo $result
}

echo "Enter your name:"
read name
say_hello "$name"

echo "Enter the first number:"
read num1
echo "Enter the second number:"
read num2

result=$(num_sum "$num1" "$num2")
echo "Sum: $result"
