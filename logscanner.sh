#!/bin/bash

PATH=/opt/bin/:$PATH
export PATH

shortopts="s:,d:"

delay=800

step=30


TEMP=`getopt -o $shortopts -n 'logscanner' -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
        case "$1" in
                -d) delay=$2 ; shift 2 ;;
                -s) scannerindex=$2; shift 2 ;;
                --) shift ; break ;;
                *) echo "Internal error!" ; exit 1 ;;
        esac
done

[ "X$scannerindex" == "X" ] && exit 1

loggerlogfile="/tmp/logger${scannerindex}.log"

prevline="EMPTY"
curline="NOSIGNAL"

rec=0
timer=0
delay=${delay}000000
sql=0

refepoch_timefile="/tmp/refepochtime${scannerindex}"

function on_exit() {
	epoch_time=$(date +%s)
	nanos=$(date +%N)
	hundredths=${nanos:0:2}
    [ "$sql" == 1 ] && printf "$epoch_time.$hundredths\n"
    exit 0
}

trap on_exit SIGINT SIGTERM

while (true)	
do 
		epoch_time=$(date +%s)
		ref_epoch_time=$(cat $refepoch_timefile)
		nanos=$(date +%N)
		hundredths=${nanos:0:2}

        read line
		
        sql=$(echo $line | awk -F, '{print $9}')
		system=$(echo $line | awk -F, '{print $6}' | sed -e 's/ //g')
        group=$(echo $line | awk -F, '{print $7}' | sed -e 's/ //g')
        channel=$(echo $line | awk -F, '{print $8}' | sed -e 's/ //g')
        code=$(echo $line | awk -F, '{print $5}')
        p25=$(echo $line | awk -F, '{print $13}')
        systag=$(echo $line | awk -F, '{print $11}')
        chantag=$(echo $line | awk -F, '{print $12}')
        freq=$(echo $line | awk -F, '{print $2}')
        curline="$system$group$channel$freq"

        if [ "X$sql" == "X" ];then
            sql=0
        fi

        [[ "$freq" =~ \. ]] && freqtgid="${freq}_MHz" || freqtgid=$freq

        if [ "$code" != "0" ]; then
            code=$(code.sh $code)
            freqtgid="${freq}_MHz_${code}"
        fi

        if [ "$p25" != "NONE" ]; then
            freqtgid="${freq}_MHz_${p25}"
        fi

		if [ "X$curline" = "X" ]; then
			if [ $rec -eq 0 ]; then
		  		curline="NOSIGNAL"
		 	else
				curline="$prevline"
			fi
#           echo "$epoch_time curline is empty - $curline $rec" >> $loggerlogfile
		fi

		if [ $sql == 1 ]; then
			if [ "$prevline" != "$curline" -a $rec -eq 1 -o "$prevline" != "$curline" -a $timer -gt 0 ]; then	
				printf "$epoch_time.$hundredths\n"
				rec=0
#                echo "$epoch_time squelch is opened, new transmission, rec is on or timer is ticking" >> $loggerlogfile
			fi
			timer=0

			if [ "$prevline" != "$curline" -o $rec -eq 0 ]; then
				printf "$system,$group,$channel,$freqtgid,$code,$p25,$systag,$chantag,$ref_epoch_time,$epoch_time.$hundredths,"
#               echo "$epoch_time squelch is opened, new transmission, rec is off" >> $loggerlogfile
				rec=1
			fi
		fi

		if [ $sql -eq 0 ]; then
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
#                    echo "$epoch_time squelch is closed, timer expired" >> $loggerlogfile
				fi
			fi
		fi
		prevline="$curline"
done
