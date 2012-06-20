#!/bin/bash

scannerindex=$1
host=$2
pass=$3
mount=$4
icao=$5
curlout="/tmp/updateicecast${scannerindex}.log"


prevline="EMPTY"
metarfile="/tmp/${icao}.metar"

while (true)	
do
	yyyymmdd=$(date +%Y%m%d)
	logdir="/scanner_audio/${yyyymmdd}/LOG"

	test -d "$logdir" || continue
    
	scannerlog="$logdir/$(ls -tr $logdir | grep SCANNER${scannerindex} | tail -1)"
    
	[ "X$scannerlog" == "X" ] && continue	


	if [ ! -e $scannerlog ]; then
		curline=""
	else
		curline=$(tail -1 $scannerlog | awk -F, '{print $6" "$7" "$8" "$2}' | sed -e 's/ /+/g')
	fi

	if [ ! -e $metarfile ]; then
		metar=""
	else
		metar=$(head -1 $metarfile | sed -e 's/+/&#43;/g' | sed -e 's/ /+/g')
	fi
	if [ "$prevline" != "$curline" ]; then
        echo "Change in $scannerlog detected, update $host/$mount with $curline+$metar"
		webaddress="http://${host}/admin/metadata?mount=/${mount}&mode=updinfo&song=$curline+$metar"
		curl -o $curlout -s -u source:${pass} $webaddress
	fi
	sleep 1
	prevline="$curline";
done
