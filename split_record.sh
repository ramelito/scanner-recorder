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
                ref_epoch_time=$(echo $line | awk -F, '{print $9}')
                start_time=$(echo $line | awk -F, '{print $10}')
                end_time=$(echo $line | awk -F, '{print $11}')
                ss=$(echo "scale=2; $start_time-$ref_epoch_time$correction" | bc)
                if [ "${ss:0:1}" == "-" -o "${ss:0:1}" == "." ]; then ss=0; fi
                t=$(echo "scale=2; $end_time-$start_time" | bc)
                if [ "${t:0:1}" == "." ]; then t=0; fi
                ti=$(echo $t | awk -F. '{print $1}')
		filename_date_part=$(date -d "Jan 1, 1970 00:00:00 +0000 + $start_time seconds" +%Y%m%d%H%M%S)
		filename="${filename_date_part}_${freq}.mp3"
	        dir1="${scannerhome}/${yymmdd}/${system}/${group}/${channel}/${hh}"
		test "X$group" == "X" && dir1="${scannerhome}/${yymmdd}/${system}/${freq}/${hh}"
		[[ "$freq" =~ $mhz ]] || dir1="${scannerhome}/${yymmdd}/${system}/${freq}/${hh}"
                test -d $dir1 || mkdir -p $dir1
		test $ti -gt 2 && ffmpeg -y -ss $ss -t $t -i $record_file -acodec copy "${dir1}/${filename}" 2>/dev/null
		test $ti -gt 2 && echo "Splitting ${filename_date_part}_${freq}.mp3 from $record_file to ${dir1}, position $ss, duration $t.">> /tmp/split.log
	fi
	prevline="$line"
	sleep 1s
done
