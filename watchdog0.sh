#!/bin/bash

scannerindex=$1
bitrate=$2
samplerate=$3
div=60

scannerhome="/scanner_audio"
#scannerhome="/tmp"
arecordpidfile="/tmp/arecord${scannerindex}.pid"
audiodevice="-Dplughw:${scannerindex},0"
arecordopts="-f S16_LE -r $samplerate -c 1 -t wav -q"
lameopts="-S -m m -s 16 -b $bitrate"

touch $arecordpidfile

while (true); do
	yy=$(date +%Y)
	mm=$(date +%m)
	dd=$(date +%d)
	hh=$(date +%H)
        min=$(date +%M)
        sec=$(date +%S)
        mod=$(expr $min % $div)
	recdir=$scannerhome/${yy}${mm}${dd}
	recfile=${recdir}/${yy}${mm}${dd}${hh}_SCANNER${scannerindex}_${min}.mp3
	if [ "$mod" -eq 0 -o ! -f "/proc/$(cat $arecordpidfile)/exe" ];then
		echo "Killing previous instance."
		test -f "/proc/$(cat $arecordpidfile)/exe" && kill -9 $(cat $arecordpidfile)
		echo "Starting new instance."
		test -d "$recdir" || mkdir -p "$recdir"
		arecord $audiodevice $arecordopts --process-id-file $arecordpidfile | lame $lameopts - "$recfile" &
		sleep 60
	fi
	sleep 2
done
