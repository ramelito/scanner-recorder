#!/bin/bash
set -a

scannerhome="/scanner_audio"
confpath="/opt/etc"
conffile="record.conf"
envpath="/tmp/env.txt"

test -f ${scannerhome}/${conffile} && cp ${scannerhome}/${conffile} $confpath
test -f ${confpath}/${conffile} && source ${confpath}/${conffile} || ( echo "File $conffile not found in $confpath."; exit 1 )

env > $envpath

num=$(cat $envpath | grep scanner[0-9] | wc -l)

for i in $(seq 1 $num); do
        params=$(eval   "echo \$$( echo scanner${i})")
	record0.sh $params > /dev/null &	
done
