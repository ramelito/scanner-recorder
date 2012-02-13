#!/bin/bash

export PATH=/opt/bin:$PATH

scannerindex=$1
cardindex=$2
bitrate=$3
samplerate=$4
div=60

scannerhome="/scanner_audio"
#scannerhome="/tmp"
arecordpidfile="/tmp/arecord${scannerindex}.pid"
loggerpidfile="/tmp/logger${scannerindex}.pid"
splitpidfile="/tmp/split${scannerindex}.pid"
audiodevice="-Dplughw:${cardindex},0"
arecordopts="-f S16_LE -r $samplerate -c 1 -t wav -q"
lameopts="-S -m m -q9 -b $bitrate"
refepochtimefile="/tmp/refepochtime${scannerindex}"
scannerlck="/tmp/scanner${scannerindex}.lck"

touch $arecordpidfile
touch $loggerpidfile
touch $splitpidfile

while (true); do
	yy=$(date +%Y)
	mm=$(date +%m)
	dd=$(date +%d)
	hh=$(date +%H)
        min=$(date +%M)
        sec=$(date +%S)
	epoch0=$(date +%s)
        mod=$(expr $min % $div)
	recdir=$scannerhome/${yy}${mm}${dd}
	recfile=${recdir}/${yy}${mm}${dd}${hh}_SCANNER${scannerindex}_${min}.mp3
	logfile=${recdir}/${yy}${mm}${dd}${hh}_SCANNER${scannerindex}_${min}.log
	if [ "$mod" -eq 0 -o ! -f "/proc/$(cat $arecordpidfile)/exe" -o ! -f "/proc/$(cat $loggerpidfile)/exe" ];then
		echo "Killing previous instances."
		echo 0 > $scannerlck; sleep 0.5
		test -f "/proc/$(cat $arecordpidfile)/exe" && kill -9 $(cat $arecordpidfile)
		test -f "/proc/$(cat $loggerpidfile)/exe" && kill -9 $(cat $loggerpidfile)

		echo "Starting new instances."
		test -d "$recdir" || mkdir -p "$recdir"
		echo $(date +%s) > $refepochtimefile

		arecord $audiodevice $arecordopts --process-id-file $arecordpidfile | lame $lameopts - "$recfile" &
		logscanner.sh -s $scannerindex > $logfile & echo $! > $loggerpidfile
		sleep 2
		test -e "/proc/$(cat $splitpidfile)/exe" && kill -9 $(cat $splitpidfile)
		split_record.sh $logfile & echo $! > $splitpidfile
		test $mod -eq 0 && sleep 60
	fi
	sleep 2
	epoch=$(date +%s)
	let diff=$epoch-$epoch0
	if [ $diff -gt 6 -a $mod -ne 0 ]; then
		test -f "/proc/$(cat $arecordpidfile)/exe" && kill -9 $(cat $arecordpidfile)
		test -f "/proc/$(cat $loggerpidfile)/exe" && kill -9 $(cat $loggerpidfile)
		test -e "/proc/$(cat $splitpidfile)/exe" && kill -9 $(cat $splitpidfile)
	fi
done
