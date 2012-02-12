#!/bin/bash

PATH=/opt/bin:$PATH
export PATH

shortopts="s:"

led0="/sys/class/leds/beagleboard::usr0/brightness"
echo 0 | sudo tee -a $led0

for i in {1..4}; do
	echo 1 | sudo tee -a $led0
	sleep 0.5
	echo 0 | sudo tee -a $led0
	sleep 0.3
done

samplerate=16000
bitrate=48
delay=2000

scannerindex="0"
arch=$(uname -m)

step=30

TEMP=`getopt -o $shortopts -n 'record_scanner' -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
        case "$1" in
                -s) scannerindex=$2 ; shift 2 ;;
                --) shift ; break ;;
                *) echo "Internal error!" ; exit 1 ;;
        esac
done

scannerhome="/scanner_audio"
config=/media/mmcblk0p3/record.conf
if [ -f $config ]; then
	source $config
fi

lockfile="/tmp/scanner${scannerindex}.lck"
arecordpidfile="/tmp/arecord${scannerindex}.pid"
scannerport="/dev/ttyUSB${scannerindex}"
audiodevice="-Dplug:dsnoop${scannerindex}"
arecordopts="-f S16_LE -r $samplerate -c 1 -d 600 -t wav -q"
lameopts="-S -m m -s 16 -b $bitrate"

prevline="EMPTY"
curline="NOSIGNAL"

rec=0
timer=0
delay=${delay}000000
sql=0

refepochtimefile="/tmp/refepochtime${scannerindex}"

echo 1 > $lockfile

while (true)	
do 
		inuse=$(cat $lockfile)

		line=""
		yy=$(date +%Y)
		mm=$(date +%m)
		dd=$(date +%d)
		hh=$(date +%H)
		MM=$(date +%M)
		SS=$(date +%S)

		if [ "$rec" == 1 -a "$inuse" == 0 ]; then
			if [ -f "/proc/$(cat $arecordpidfile)/exe" ]; then
                        	kill -9 $(cat $arecordpidfile)
			fi
			rec=0
			timer=0
			echo 0 | tee -a $led0
		fi
	
		if [ $inuse == 1 ]; then	
			line=$(REMOTECONTROL -s $scannerindex --glg | grep -v ERR | grep GLG)
			line=$(REMOTECONTROL -s $scannerindex --glg | grep -v ERR | grep GLG)
			line=$(REMOTECONTROL -s $scannerindex --glg | grep -v ERR | grep GLG)
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

		if [ -f record.conf ]; then
			source $config 
		else
			recdir=${yy}${mm}${dd}/${system}/${group}/${channel}/${hh}
			recfile=${yy}${mm}${dd}${hh}${MM}${SS}_${systag}_${chantag}_${freqtgid}
		fi

		if [ "X$curline" = "X" ]; then
			if [ $rec == 0 ]; then
		  		curline="NOSIGNAL"
		 	else
				curline="$prevline"
			fi
		fi

		if [ $sql == 1 ]; then
			if [ "$prevline" != "$curline" -a $rec == 1 -o "$prevline" != "$curline" -a $timer -gt 0 ]; then	
				if [ -f "/proc/$(cat $arecordpidfile)/exe" ]; then
                        		kill -9 $(cat $arecordpidfile)
				fi
				rec=0
				echo 0 | sudo tee -a $led0
			fi
			timer=0

			if [ "$prevline" != "$curline" -o $rec == 0 ]; then
				recdir="${scannerhome}/${recdir}"
				recfile="${recdir}/${recfile}.mp3"
				mkdir -p "$recdir"
				echo $recfile
				arecord $audiodevice $arecordopts --process-id-file $arecordpidfile | lame $lameopts - "$recfile" &
				rec=1
				echo 1 | sudo tee -a $led0
			fi
		fi

		if [ $sql == 0 -a $inuse == 1 ]; then
			if [ $rec == 1 ]; then
				if [ $timer == 0 ]; then
				   timer=`date +%s%N`
				fi
				timer0=`date +%s%N`
				let diff=$timer0-$timer
				if [ $diff -gt $delay ]; then
					if [ -f "/proc/$(cat $arecordpidfile)/exe" ]; then
                        			kill -9 $(cat $arecordpidfile)
					fi
					rec=0
					curline="NOSIGNAL"
					timer=0
					echo 0 | tee -a $led0
				fi
			fi
		fi
		prevline="$curline"
done
