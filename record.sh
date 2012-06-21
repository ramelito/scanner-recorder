#!/bin/bash
set -a

export LANG=C
export PATH=/opt/bin:$PATH

[ "X$timeout" == "X" ] && timeout=10

scannerhome="/scanner_audio"
confpath="/opt/etc"
conffile="record.conf"
envpath="/tmp/env.txt"
asound="/etc/asound.conf"

test -n 0.ru.pool.ntp.org && /usr/bin/ntpdate 0.ru.pool.ntp.org

echo "DEBUG: checking and sourcing config..."

test -f ${scannerhome}/${conffile} && cp ${scannerhome}/${conffile} $confpath
test -f ${confpath}/${conffile} && source ${confpath}/${conffile} || ( echo "File $conffile not found in $confpath."; exit 1 )

echo "Changing IP address to static if configured..."

assign_static_address.sh &

echo "DEBUG: offloading env variables."

env > $envpath

echo "DEBUG: entering loop to run record0.sh."

num=$(cat $envpath | grep scanner[0-9] | wc -l)

echo "" > $asound

test -L $scannerhome || ln -s /media/mmcblk0p1/scanner_audio /scanner_audio

for i in $(seq 1 $num); do
        params=$(eval   "echo \$$( echo scanner${i})")
        echo "Starting record0.sh with $params."
	record0.sh $params $timeout &	
done
