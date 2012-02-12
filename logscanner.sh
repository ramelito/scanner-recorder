#!/bin/bash

PATH=/opt/bin/:$PATH
export PATH

shortopts="s:d:"

arch=$(uname -m)

delay=3000

step=30

TEMP=`getopt -o $shortopts -n 'logscanner' -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
        case "$1" in
                -s) scannerindex=$2 ; shift 2 ;;
                -d) delay=$2 ; shift 2 ;;
                --) shift ; break ;;
                *) echo "Internal error!" ; exit 1 ;;
        esac
done

lockfile="/tmp/scanner$scannerindex.lck"

prevline="EMPTY"
curline="NOSIGNAL"

rec=0
timer=0
delay=${delay}000000
sql=0

refepochtimefile="/tmp/refepochtime${scannerindex}"

if [ "X$scannerindex" == "X" ]; then
	exit 1
fi

echo 1 > $lockfile

while (true)	
do 
		inuse=$(cat $lockfile)

		line=""
		epoch_time=$(date +%s)
		ref_epoch_time=$(cat $refepochtimefile)
		nanos=$(date +%N)
		hundredths=${nanos:0:2}

		if [ $rec -eq 1 -a $inuse -eq 0 ]; then
			printf "$epoch_time.$hundredths\n"
			rec=0
			timer=0
		fi
	
		if [ $inuse -eq 1 ]; then	
			line=$(REMOTECONTROL2 -s $scannerindex --glg | sed -e 's///g' | grep -v ERR | grep GLG)
		fi

		sql=$(echo $line | awk -F, '{print $9}')
		if [ "X$sql" = "X" ]; then 
			sql=0; 
		fi

		system=$(echo $line | awk -F, '{print $6}' | sed -e 's/ //g')
                group=$(echo $line | awk -F, '{print $7}' | sed -e 's/ //g')
                channel=$(echo $line | awk -F, '{print $8}' | sed -e 's/ //g')
                code=$(echo $line | awk -F, '{print $5}')
                p25=$(echo $line | awk -F, '{print $13}')
                systag=$(echo $line | awk -F, '{print $11}')
                chantag=$(echo $line | awk -F, '{print $12}')
                freq=$(echo $line | awk -F, '{print $2}')
                curline="$system$group$channel$freq$code$p25"

                if [[ "$freq" =~ \. ]]; then
                        freqtgid="${freq}_MHz"
                else
                        freqtgid=$freq
                fi

                if [ "$code" != "0" ]; then
                        code=$(code.sh $code)
                        freqtgid="${freq}_MHz_${code}"
                fi

                if [ "$p25" != "NONE" ]; then
                        freqtgid="${freq}_MHz_${p25}"
                fi

		if [ "X$curline" = "X MHz" ]; then
			if [ $rec -eq 0 ]; then
		  		curline="NOSIGNAL"
		 	else
				curline="$prevline"
			fi
		fi

		if [ $sql == 1 ]; then
			if [ "$prevline" != "$curline" -a $rec -eq 1 -o "$prevline" != "$curline" -a $timer -gt 0 ]; then	
				printf "$epoch_time.$hundredths\n"
				rec=0
			fi
			timer=0

			if [ "$prevline" != "$curline" -o $rec -eq 0 ]; then
				printf "$system,$group,$channel,$freqtgid,$code,$p25,$systag,$chantag,$ref_epoch_time,$epoch_time.$hundredths,"
				rec=1
			fi
		fi

		if [ $sql -eq 0 -a $inuse -eq 1 ]; then
			if [ $rec -eq 1 ]; then
				if [ $timer -eq 0 ]; then
				   timer=$(date +%s%N)
				fi
				timer0=$(date +%s%N)
				let diff=$timer0-$timer
				if [ $diff -gt $delay ]; then
					rec=0
					curline="NOSIGNAL"
					timer=0
					printf "$epoch_time.$hundredths\n"
				fi
			fi
		fi
		prevline="$curline"
done
