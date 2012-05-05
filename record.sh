#!/bin/bash
set -a

export LANG=C
export PATH=/opt/bin:$PATH

scannerhome="/scanner_audio"
confpath="/opt/etc"
conffile="record.conf"
envpath="/tmp/env.txt"
asound="/etc/asound.conf"

echo "DEBUG: checking and sourcing config..."

test -f ${scannerhome}/${conffile} && cp ${scannerhome}/${conffile} $confpath
test -f ${confpath}/${conffile} && source ${confpath}/${conffile} || ( echo "File $conffile not found in $confpath."; exit 1 )

echo "DEBUG: offloading env variables."

env > $envpath

echo "DEBUG: entering loop to run record0.sh."

num=$(cat $envpath | grep scanner[0-9] | wc -l)

echo "" > $asound

for i in $(seq 1 $num); do
        params=$(eval   "echo \$$( echo scanner${i})")
        echo "Starting record0.sh with $params."
	#record0.sh $params > /dev/null &	
	record0.sh $params  &	
done
