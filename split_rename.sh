#!/bin/bash

th=$1
delay=$2
mindur=$3
scorr=$4
mp3spltrecdir=$5
mp3spltoutput=$6
mp3spltinput=$7

mp3spltopts="-s -p th=${th},min=${delay},trackmin=${mindur},off=${scorr},rm -Q -N"

mp3splt $mp3spltopts -d $mp3spltrecdir -o $mp3spltoutput $mp3spltinput 
rename.sh $mp3spltrecdir
