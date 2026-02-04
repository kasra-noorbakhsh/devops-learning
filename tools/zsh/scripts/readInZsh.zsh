#! /usr/bin/zsh
# testing read in zsh

read "age?Please enter your age: "
days=$(( age * 365 ))
echo "That makes you over $days days old!"
