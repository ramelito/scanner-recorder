#!/bin/bash

number=$(echo $1 | awk -F"/" '{print $8}' | awk -F. '{print $2}')
#echo $number
echo $(expr $number - 1)
