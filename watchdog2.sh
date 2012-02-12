#!/bin/bash

scannerindex=$1
bitrate=$2
samplerate=$3
host=$4
pass=$5
mount=$6

scannerhome="/scanner_audio"
#scannerhome="/tmp"
audiodevice="-Dplug:dsnoop${scannerindex}"
darkconf="/tmp/darkice${scannerindex}.conf"
darkpidfile="/tmp/darkice${scannerindex}.pid"

port=$(echo $host | awk -F: '{print $2}')
host0=$(echo $host | awk -F: '{print $1}')

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
" > $darkconf
}

while (true); do
	yy=$(date +%Y)
	mm=$(date +%m)
	dd=$(date +%d)
	hh=$(date +%H)
        min=$(date +%M)
        sec=$(date +%S)
	if [ ! -f "/proc/$(cat $darkpidfile)/exe" ]; then
		echo "Checking connection."
		res=$(curl -s http://source:$pass@$host/admin/listclients?mount=/$mount)
		echo "Result: $res."
		if [[ "$res" =~ "<b>Source does not exist</b>" ]];then
			echo "Connection established. Generating darkice config."
			gendarkconf
			echo "Starting darkice."
			darkice -c $darkconf & echo $! > $darkpidfile
			echo "Darkice started, stream is online, pid - $darkpidfile"
		fi
	fi
	sleep 2
done
