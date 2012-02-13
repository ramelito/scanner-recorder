#!/bin/bash

scannerindex=$1
bitrate=$2
samplerate=$3
host=$4
pass=$5
mount=$6
div=60

scannerhome="/scanner_audio"
#scannerhome="/tmp"
arecordpidfile="/tmp/arecord${scannerindex}.pid"
audiodevice="-Dplughw:${scannerindex},0"
arecordopts="-f S16_LE -r $samplerate -c 1 -t wav -q"
lameopts="-S -m m -q9 -b $bitrate"
darkconf="/tmp/darkice${scannerindex}.conf"
darkpidfile="/tmp/darkice${scannerindex}.pid"

port=$(echo $host | awk -F: '{print $2}')
host0=$(echo $host | awk -F: '{print $1}')

touch $arecordpidfile
touch $darkpidfile

gendarkconf () {
	echo "
	[general]
	duration        = 0
	bufferSecs      = 2
	reconnect       = yes

	[input]
	device          = plughw:${scannerindex},0
	sampleRate      = $samplerate
	bitsPerSample   = 16
	channel         = 1

	[icecast2-0]
	format          = mp3
	bitrateMode     = cbr
	bitrate         = $bitrate
	server          = $host0
	mountPoint      = $mount
	port            = $port
	password        = $pass
	localDumpFile	= $recfile
" > $darkconf
}

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
	if [ "$mod" -eq 0 -o ! -f "/proc/$(cat $darkpidfile)/exe" ];then
		echo "Time to rotate: ${hh}:${min}:${sec}."
		echo "Killing previous instance if exists."
		test -f "/proc/$(cat $arecordpidfile)/exe" -a "$mod" -eq 0 && kill -9 $(cat $arecordpidfile)
		test -f "/proc/$(cat $darkpidfile)/exe" -a "$mod" -eq 0 && kill -9 $(cat $darkpidfile)
		echo "Creating directory $recdir."
		test -d "$recdir" || mkdir -p "$recdir"
		echo "Checking connection."
		res=$(curl -s http://source:$pass@$host/admin/listclients?mount=/$mount)
		echo "Result: $res."
		if [[ "$res" =~ "<b>Source does not exist</b>" ]];then
			echo "Connection established, killing offline recording if exists."
			test -f "/proc/$(cat $arecordpidfile)/exe" && kill -9 $(cat $arecordpidfile)
			echo "Generating darkice config."
			gendarkconf
			echo "Starting darkice."
			darkice -c $darkconf & echo $! > $darkpidfile
			echo "Darkice started, stream is online, pid - $darkpidfile"
		else
			echo "Connection broken, continue with offline recording."
			test -f "/proc/$(cat $arecordpidfile)/exe" || arecord $audiodevice $arecordopts --process-id-file $arecordpidfile | lame $lameopts - "$recfile" &
		fi
		test "$mod" -eq 0 && sleep 60
	fi
	sleep 2
done
