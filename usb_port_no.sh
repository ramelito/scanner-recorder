#!/bin/bash

number=$(echo $1 | awk -F"/" '{print $7}' | awk -F. '{print $2}')
echo $(expr $number - 1)
