#!/bin/bash

th=$1
delay=$2
mindur=$3
scorr=$4
mp3spltrecdir=$5
mp3spltoutput=$6
mp3spltinput=$7
bitrate=$8
logfile="/tmp/splitrename.log"

mp3spltopts="-s -p th=${th},min=${delay} -Q -N"
soxopts="silence -l 1 0.1 1% -1 0.5 1%"

spltrename() {
	
	echo "[$(date)] Running mp3splt on $mp3spltinput with $mp3spltopts" >> $logfile
	mp3splt $mp3spltopts -d $mp3spltrecdir -o $mp3spltoutput $mp3spltinput 
	list=$(mktemp)

	echo "[$(date)] Creating list $list of files to rename" >> $logfile
	ls $mp3spltrecdir | grep _ > $list
	numlines=$(cat $list | wc -l)
	[ "$numlines" == "0" ] && return 0
	
	echo "[$(date)] Reading list of files to rename." >> $logfile
	while read line; do
    		filename=${line%.*}
    		datepart=$(echo $filename | awk -F"_" '{print $1}')
    		shiftpart=$(echo $filename | awk -F "_" '{print $2}')
    		shiftmins=${shiftpart:0:2}
    		shiftsecs=${shiftpart:2:2}
    		dpyy=${datepart:0:4}
    		dpmm=${datepart:4:2}
    		dpdd=${datepart:6:2}
    		dphh=${datepart:8:2}
    		dpmins=${datepart:10:2}
    		dpsecs=${datepart:12:2}
    		dpepoch=$(date -d "${dpyy}-${dpmm}-${dpdd} ${dphh}:${dpmins}:${dpsecs}" +%s)
    		[ ${shiftsecs:0:1} == 0 ] && shiftsecs=${shiftsecs:1:1}
    		[ ${shiftmins:0:1} == 0 ] && shiftmins=${shiftmins:1:1}
    		let shiftsecs=${shiftmins}*60+$shiftsecs
    		let dpepoch=$dpepoch+$shiftsecs
    		newfile=${mp3spltrecdir}/$(date -d "@$dpepoch" +%Y-%m-%d_%Hh%Mm%Ss)
		if [ ! -f ${newfile}.mp3 ]; then
			echo "[$(date)] Soxing ${newfile}.wav." >> $logfile
			sox ${mp3spltrecdir}/${line} ${newfile}.wav $soxopts
			echo "[$(date)] Laming ${newfile}.wav." >> $logfile
			lame --quiet -b $bitrate ${newfile}.wav ${newfile}.mp3
			echo "[$(date)] Removing ${newfile}.wav." >> $logfile
			rm ${newfile}.wav 
		fi
		echo "[$(date)] Removing ${mp3spltrecdir}/${line}." >> $logfile
		rm ${mp3spltrecdir}/${line}	
	done < $list
	echo "[$(date)] Removing $list." >> $logfile	
	rm $list
}

ctrl_c() {
	echo "[$(date)] Received interrupting signal." >> $logfile	
	
	spltrename	
		
	echo "[$(date)] Exiting..." >> $logfile	
	exit 0
}

trap ctrl_c SIGTERM


echo "[$(date)] Entering into infinite loop" >> $logfile

while (true); do

	spltrename

	echo "[$(date)] Let's sleep for 120 secs." >> $logfile
	sleep 120 
done
