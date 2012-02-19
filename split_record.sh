#!/bin/bash

scannerhome="/scanner_audio"
scannerlog=$1
comma=".*,$"
mhz=".*MHz.*"
correction="-0.5"
fname=${scannerlog##*/}
fname2=${fname%.*}
yymmdd=${fname:0:8}
hh=${fname:8:2}
cutlinesfile="/tmp/cutlines${fname:18:1}"
splitlog="/tmp/split${fname:18:1}.log"
record_file="$scannerhome/${yymmdd}/${fname2}.mp3"
mp3spltopts="-Q"
numlines0=0

test $# -eq 0 && exit 1
test -f $scannerlog || exit 1
test -f $record_file || exit 1 

while (true)	
do
	numlines=$(cat $scannerlog | wc -l)
    [ $numlines -gt $numlines0 ] && let cutlines=$numlines-$numlines0+2 || cutlines=0
    numlines0=$numlines
    tail -n${cutlines} $scannerlog > $cutlinesfile 
    while read line; do
		system=$(echo $line | awk -F, '{print $1}')
        group=$(echo $line | awk -F, '{print $2}')
        channel=$(echo $line | awk -F, '{print $3}')
        freq=$(echo $line | awk -F, '{print $4}')
        r0=$(echo $line | awk -F, '{print $9}')
        s0=$(echo $line | awk -F, '{print $10}')
        e0=$(echo $line | awk -F, '{print $11}')
        if [ "X$e0" != "X" ]; then
            s=$(echo "scale=2; $s0-$r0$correction" | bc)
            e=$(echo "scale=2; $e0-$r0$correction" | bc)
		    ss=$(echo $s | awk -F. '{print $1}')
    		sh=$(echo $s | awk -F. '{print $2}')
	    	es=$(echo $e | awk -F. '{print $1}')
		    eh=$(echo $e | awk -F. '{print $2}')
    		[ "X$ss" == "X" -o "${ss:0:1}" == 0 ] && ss=0
	    	[ "X$es" == "X" -o "${es:0:1}" == 0 ] && es=0
    		[ "X$sm" == "X" -o "${sm:0:1}" == 0 ] && sm=0
	    	[ "X$em" == "X" -o "${em:0:1}" == 0 ] && em=0
		    sm=$(expr $ss / 60)
    		ss=$(expr $ss % 60)
	    	em=$(expr $es / 60)
		    es=$(expr $es % 60)
    		filename_date_part=$(date -d @$s0 +%Y%m%d%H%M%S)
	    	filename="${filename_date_part}_${freq}@t"
	        dir1="${scannerhome}/${yymmdd}/${system}/${group}/${channel}/${hh}"
    		test "X$group" == "X" && dir1="${scannerhome}/${yymmdd}/${system}/${freq}/${hh}"
	    	[[ "$freq" =~ $mhz ]] || dir1="${scannerhome}/${yymmdd}/${system}/${freq}/${hh}"
		    mp3splt $mp3spltopts $record_file $sm.$ss.$sh $em.$es.$eh -d ${dir1} -o "${filename}" 2>/dev/null
    		echo "Splitting ${filename_date_part}_${freq}.mp3 from $record_file to ${dir1}, start $sm.$ss.$sh, end $em.$es.$eh." >> $splitlog
        fi
    done < $cutlinesfile
	sleep 10s
done
