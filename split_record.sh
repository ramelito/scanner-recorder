#!/bin/bash

scannerhome="/scanner_audio"
scannerlog=$1
prevline=""
line=""
comma=".*,$"
mhz=".*MHz.*"
correction="-0.5"
fname=${scannerlog##*/}
fname2=${fname%.*}
yymmdd=${fname:0:8}
hh=${fname:8:2}
record_file="$scannerhome/${yymmdd}/${fname2}.mp3"
mp3spltopts="-Q"

test $# -eq 0 && exit 1
test -f $scannerlog || exit 1
test -f $record_file || exit 1 

while (true)	
do
	line=$(tail -n1 $scannerlog)
	[[ "$line" =~ $comma ]] && continue
	if [ "$prevline" != "$line" ]; then
		system=$(echo $line | awk -F, '{print $1}')
        group=$(echo $line | awk -F, '{print $2}')
        channel=$(echo $line | awk -F, '{print $3}')
        freq=$(echo $line | awk -F, '{print $4}')
        r0=$(echo $line | awk -F, '{print $9}')
        s0=$(echo $line | awk -F, '{print $10}')
        e0=$(echo $line | awk -F, '{print $11}')
        s=$(echo "scale=2; $s0-$r0$correction" | bc)
        e=$(echo "scale=2; $e0-$r0$correction" | bc)
		ss=$(echo $s | awk -F. '{print $1}')
		sh=$(echo $s | awk -F. '{print $2}')
		es=$(echo $e | awk -F. '{print $1}')
		eh=$(echo $e | awk -F. '{print $2}')
		[ "X$ss" == "X" ] && ss=0
		[ "X$es" == "X" ] && es=0
		sm=$(expr $ss / 60)
		ss=$(expr $ss % 60)
		em=$(expr $es / 60)
		es=$(expr $es % 60)
		filename_date_part=$(date -d @$s0 +%Y%m%d%H%M%S)
		filename="${filename_date_part}_${freq}@t"
	    dir1="${scannerhome}/${yymmdd}/${system}/${group}/${channel}/${hh}"
		test "X$group" == "X" && dir1="${scannerhome}/${yymmdd}/${system}/${freq}/${hh}"
		[[ "$freq" =~ $mhz ]] || dir1="${scannerhome}/${yymmdd}/${system}/${freq}/${hh}"
#        test -d $dir1 || mkdir -p $dir1
		mp3splt $mp3spltopts $record_file $sm.$ss.$sh $em.$es.$eh -d ${dir1} -o "${filename}" 2>/dev/null
		echo "Splitting ${filename_date_part}_${freq}.mp3 from $record_file to ${dir1}, start $sm.$ss.$sh, end $em.$es.$eh.">> /tmp/split.log
	fi
	prevline="$line"
	sleep 1s
done
