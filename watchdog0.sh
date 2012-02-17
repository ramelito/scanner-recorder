#!/bin/bash

scannerindex=$1
bitrate=$2
samplerate=$3
divm=60
divs=60

scannerhome="/scanner_audio"
#scannerhome="/tmp"
arecordpidfile="/tmp/arecord${scannerindex}.pid"
audiodevice="-Dplughw:${scannerindex},0"
arecordopts="-f S16_LE -r $samplerate -c 1 -t wav -q"
lameopts="-S -m m -q9 -b $bitrate"
mp3spltopts="-s -p th=-50,min=2,trackmin=1,rm -Q -N"
mp3spltpidfile="/tmp/mp3splt${scannerindex}.pid"

touch $arecordpidfile
touch $mp3spltpidfile

while (true); do
	yy=$(date +%Y)
	mm=$(date +%m)
	dd=$(date +%d)
	hh=$(date +%H)
    min=$(date +%M)
    sec=$(date +%S)
    modm=$(expr $min % $divm)
    mods=$(expr $sec % $divs)
	recdir=$scannerhome/${yy}${mm}${dd}
	recfile=${recdir}/${yy}${mm}${dd}${hh}_SCANNER${scannerindex}_${min}.mp3
	if [ "$modm" -eq 0 -a "$mods" -eq 0 -o ! -f "/proc/$(cat $arecordpidfile)/exe" ];then
		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Killing previous instance."
		test -f "/proc/$(cat $arecordpidfile)/exe" && kill -9 $(cat $arecordpidfile)
		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Starting new instance."
        echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Going to record to $recfile."
		test -d "$recdir" || mkdir -p "$recdir"
		arecord $audiodevice $arecordopts --process-id-file $arecordpidfile | lame $lameopts - "$recfile" &
        echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] arecord started with pid $(cat $arecordpidfile)."
        mp3spltinput=$recfile
        mp3spltrecdir=$recdir/SCANNER${scannerindex}/${hh}
        mp3spltoutput=${yy}${mm}${dd}${hh}${mm}${ss}_@m@s
	fi
    if [ "$mods" -eq 0 -a ! -f "/proc/$(cat $mp3spltpidfile)/exe" ];then
        mp3splt $mp3spltopts -d $mp3spltrecdir -o $mp3spltoutput $mp3spltinput & echo $! > $mp3spltpidfile
    fi
    sleep 1
done
