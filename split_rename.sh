#!/bin/bash

th=$1
delay=$2
mindur=$3
scorr=$4
mp3spltrecdir=$5
mp3spltoutput=$6
mp3spltinput=$7

mp3spltopts="-s -p th=${th},min=${delay},trackmin=${mindur},off=${scorr},rm -Q -N"
mp3spltopts_tr="-r -p th=${th},min=0.3,rm -Q"

while (true); do
	mp3splt $mp3spltopts -d $mp3spltrecdir -o $mp3spltoutput $mp3spltinput 
	workdir=$1
	list=$(mktemp)

	ls $mp3spltrecdir | grep _ > $list

	first=""
	last=""

	numlines=$(cat $list | wc -l)
	first=$(cat $list | head -1)
	[ $numlines -gt 1 ] && last=$(cat $list | tail -1)	

	test -e $first && mp3splt $mp3spltopts_tr -d $mp3spltrecdir -o m${first%.*} $first 
	test -e $last && mp3splt $mp3spltopts_tr -d $mp3spltrecdir -o m${last%.*} $last 

	test -e $mp3spltrecdir/m${first} && mv $mp3spltrecdir/m${first} $mp3spltrecdir/$first
	test -e $mp3spltrecdir/m${last} && mv $mp3spltrecdir/m${last} $mp3spltrecdir/$last

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
		echo "Moving file $filename to $(date -d "@$dpepoch" +%Y%m%d%H%M%S)"
    		mv ${mp3spltrecdir}/${line} ${mp3spltrecdir}/$(date -d "@$dpepoch" +%Y%m%d%H%M%S).mp3
	done < $list
	rm $list

	sleep 30
done
