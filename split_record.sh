#!/bin/bash

scannerhome="/scanner_audio"
scannerlog=$1
logdir=$(dirname $1)
comma=".*,$"
scorr="-0.2"
ecorr="+0.1"
fname=${scannerlog##*/}
fname2=${fname%.*}
yymmdd=${fname:0:8}
hh=${fname:8:2}
cutlinesfile="/tmp/cutlines${fname:18:3}"
splitlog="/tmp/split${fname:18:3}.log"
record_file="$scannerhome/${yymmdd}/REC/${fname2}.mp3"
elogdir=/tmp/EXT_${fname:18:3}
mp3spltopts="-Q"
numlines0=0
n=0
code=""
uids=""
mindur=250

echo "Waiting 60 seconds for data to begin capturing..."

sleep 60

echo "Checking $scannerlog and $record_file for existence."

test $# -eq 0 && exit 1
test -f $scannerlog || ( echo "$scannerlog does not exists"; exit 1 )
test -f $record_file || (echo "$record_file does not exists"; exit 1 )

while (true)	
do
	numlines=$(cat $scannerlog | wc -l)
    [ $numlines -gt $numlines0 ] && let cutlines=$numlines-$numlines0 || cutlines=0
    numlines0=$numlines
    head -n$numlines $scannerlog | tail -n${cutlines} > $cutlinesfile 
    while read line; do
        line=$(echo $line | sed -e 's/ /_/g')
		system=$(echo $line | cut -d, -f 6 | sed -e 's/^_//g')
        group=$(echo $line | cut -d, -f 7 | sed -e 's/^_//g')
        channel=$(echo $line | cut -d, -f 8 | sed -e 's/^_//g')
        freq=$(echo $line | cut -d, -f 2 | sed -e 's/^0*//g')
        r0=$(echo $line | cut -d, -f 14)
        s0=$(echo $line | cut -d, -f 15)
        e0=$(echo $line | cut -d, -f 16)
        if [ "X$e0" != "X" ]; then
		d0=$(echo "($e0-$s0)*100" | bc)
                d0=$(echo $d0 | cut -d. -f 1)
                if [ $d0 -le $mindur ]; then
                    [ -e "$elogdir/$s0" ] && rm "$elogdir/$s0" 
                    continue
                fi
            s=$(echo "scale=2; $s0-$r0$scorr" | bc)
            e=$(echo "scale=2; $e0-$r0$ecorr" | bc)
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
            if [[ "$freq" =~ \. ]]; then
	    	    filename="${filename_date_part}_${freq}_MHz"
	            dir1="${scannerhome}/${yymmdd}/${system}/${group}/${channel}/${hh}"
        		[ "X$group" == "X" ] && dir1="${scannerhome}/${yymmdd}/${system}/${freq}/${hh}"
                test -d "$dir1" || mkdir -p "$dir1"
                [ -s "$elogdir/$s0" ] || sleep 1m
                if [ -s "$elogdir/$s0" ];then
                    echo "Extracting code. File $elogdir/$s0, size $(stat -c %s $elogdir/$s0)."
                    cut -d, -f 9 "$elogdir/$s0" > "$elogdir/$s0".1
                    code=$(cat "$elogdir/$s0".1 | sort -u | grep "$freq" | tr ' ' '\n' | sed -e '/^$/d' | grep C | tr '\n' '_' | sed -e 's/_$//g')
                fi
                [ -e "$elogdir/$s0" ] && rm "$elogdir/$s0"
                [ -e "$elogdir/$s0".1 ] && rm "$elogdir/$s0".1
	    	    [ "X$code" != "X" ] && filename="${filename}_${code}"
                code=""
            else
	    	    filename="${filename_date_part}_${freq}_${system}"
	            dir1="${scannerhome}/${yymmdd}/${group}/${channel}/${hh}"
        		test "X$group" == "X" && dir1="${scannerhome}/${yymmdd}/FOUNDTGIDS/${freq}/${hh}"
                dir1=$(echo "$dir1" | sed -e 's/\://')
                test -d "$dir1" || mkdir -p "$dir1"
                [ -s "$elogdir/$s0" ] || sleep 1m
                if [ -s "$elogdir/$s0" ]; then
                    cut -d, -f 7,9 "$elogdir/$s0" | grep UID > "$elogdir/$s0".1 
                    uids=$(cat "$elogdir/$s0".1 | clrsym.sed | tr ' ' '\n' | sed -e '/^$/d' | sed -e "/\b$freq\b/d" | uniq | tr '\n' '_' | sed -e 's/_$//g')
                fi
                [ -e "$elogdir/$s0" ] && rm "$elogdir/$s0"
                [ -e "$elogdir/$s0".1 ] && rm "$elogdir/$s0".1
                [ "X$uids" != "X" ] && filename="${filename}_${uids}"
                uids=""
            fi
		    mp3splt $mp3spltopts $record_file $sm.$ss.$sh $em.$es.$eh -d "${dir1}" -o "${filename}" 2>/dev/null
            echo "Splitting ${filename}.mp3 from $record_file to ${dir1}, start $sm.$ss.$sh, end $em.$es.$eh." >> $splitlog
        fi
    done < $cutlinesfile
	sleep 1s
done
