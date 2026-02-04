#! /usr/bin/zsh
# testing the if condition

if [ $1 -eq $2 ]
then
    echo "Both values are equal!"
    exit
fi
if [ $1 -gt $2 ]
then
    echo "The first value is greater than the second"
    exit
fi
if [ $1 -lt $2 ]
then
    echo "The first value is less than the second"
    exit
fi
