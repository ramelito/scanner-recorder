#!/bin/bash

uopt=$1
scannerindex=$2
scardindex=$3
bitrate=$4
samplerate=$5
scor=$6
ecor=$7
delay=$8
mindur=$9
timez=${10}
host=${11}
pass=${12}
mount=${13}
icao=${14}
divm=60
divs=60
modf=0
mdl="^MDL*"

export TZ=$timez
scannerhome="/scanner_audio"
arecordpidfile="/tmp/arecord${scannerindex}.pid"
arecordopts="-Dplug:dsnoop${scardindex} -f S16_LE -r $samplerate -c 1 -q -t wav --process-id-file $arecordpidfile"
lameopts="-S -m m -q9 -b $bitrate -"
darkconf="/tmp/darkice${scannerindex}.conf"
darkpidfile="/tmp/darkice${scannerindex}.pid"
refepochtimefile="/tmp/refepochtime${scannerindex}"
scannerlck="/tmp/scanner${scannerindex}.lck"
loggerpidfile="/tmp/logger${scannerindex}.pid"
splitpidfile="/tmp/split${scannerindex}.pid"
updatepidfile="/tmp/update${scannerindex}.pid"
stopfile="/tmp/stop${scannerindex}"
glgopts="-d /dev/scanners/$scannerindex -t $delay -p $scannerlck"
elogdir="/tmp/EXT_${scannerindex}"

host0=$(echo $host | awk -F: '{print $1}')
port=$(echo $host | awk -F: '{print $2}')

touch $arecordpidfile
touch $splitpidfile
touch $loggerpidfile
touch $darkpidfile
touch $updatepidfile

test -e $stopfile && exit 1

echo 0 > $stopfile

echo 0 > $scannerlck

[ "X$uopt" == "X" ] && uopt=0

gendarkconf () {
    echo "
        [general]
        duration        = 0
        bufferSecs      = 2
        reconnect       = yes

        [input] 
        device          = plug:dsnoop${scardindex}
        sampleRate      = $samplerate
        bitsPerSample   = 16
        channel         = 1

        [icecast2-0]
        format          = mp3
        bitrateMode     = cbr
        bitrate         = $bitrate
        server          = $host0
        mountPoint      = $mount
        port            = $port
        password        = $pass" > $darkconf
}

record () {
	exe1="/proc/$(cat $splitpidfile)/exe"
	exe2="/proc/$(cat $loggerpidfile)/exe"
	exe3="/proc/$(cat $arecordpidfile)/exe"
	if [ ! -f "$exe1" -o ! -f "$exe2" -o ! -f "$exe3" ] ; then
		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Starting new instance."
        	echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Going to record to $recfile."
        	if test -f "/proc/$(cat $arecordpidfile)/exe"; then
		  echo -n "arecord with pid $(cat $arecordpidfile) is running. Killing it ..."
		  kill -9 $(cat $arecordpidfile)
		  echo " ok!"
		fi
        	if test -f "/proc/$(cat $loggerpidfile)/exe"; then
		 echo -n "logger with pid $(cat $loggerpidfile) is running. Killing it ..."
		 kill $(cat $loggerpidfile)
		 echo " ok!"
		fi
        	if test -f "/proc/$(cat $splitpidfile)/exe"; then
		 echo -n "splitter with pid $(cat $splitpidfile) is running. Killing it ..."
 		 kill -9 $(cat $splitpidfile)
		 echo " ok!"
		fi
	
		test -d "$recdir" || mkdir -p "$recdir"
		test -d "$logdir" || mkdir -p "$logdir"
		test -d "$elogdir" || mkdir -p "$elogdir"
	
		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] arecord opts: $arecordopts."
       		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] lame opts: $lameopts."

		arecord $arecordopts | lame $lameopts "$recfile" &
       		sleep 1.5
       
		echo -n "Checking if arecord has started..." 	
		test -f $arecordpidfile || exit 1
        	test -f "/proc/$(cat $arecordpidfile)/exe" || exit 1	
		echo "ok!"
	
		nanos=$(stat -c %z $arecordpidfile | awk -F. '{print $2}')
        	reftime=$(stat -c %Z $arecordpidfile)
		glgsts $glgopts -l $logfile -i $elogdir -r $reftime.${nanos:0:2} & echo $! > $loggerpidfile
        	split_record.sh $logfile $scor $ecor $mindur & echo $! > $splitpidfile

        	echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] arecord started with pid $(cat $arecordpidfile)."
	fi
}

livecast() {
	if [ ! -f "/proc/$(cat $darkpidfile)/exe" ];then
		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Starting new instance."
		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Checking connection."
	       
            	echo "http://source:$pass@$host/admin/listclients?mount=/$mount"
		res=$(curl -s http://source:$pass@$host/admin/listclients?mount=/$mount)
        	echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Result: $res."
	        if [[ "$res" =~ "<b>Source does not exist</b>" ]];then
        		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Connection established, killing offline recording if exists."
            		
			echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Generating darkice config."
            		
			gendarkconf
            		
			echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Starting darkice."
            		
			darkice -c $darkconf & echo $! > $darkpidfile
            		
			echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Darkice started, stream is online, pid - $(cat $darkpidfile)"

            sleep 10

            test -f "/proc/$(cat $updatepidfile)/exe" || (update_icecast.sh $scannerindex $host $pass $mount $icao & echo $! > $updatepidfile)
			
            echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Updating icecast."

            fi
    fi
}

echo "Checking timezone - $timez."
date

while (true); do
	yy=$(date +%Y)
	mm=$(date +%m)
	dd=$(date +%d)
	hh=$(date +%H)
	min=$(date +%M)
	sec=$(date +%S)
	modm=$(expr $min % $divm)
    	modm5=$(expr $min % 5)
	recdir=$scannerhome/${yy}${mm}${dd}/REC
	logdir=$scannerhome/${yy}${mm}${dd}/LOG
#   	elogdir=$logdir/EXT
	recfile=${recdir}/${yy}${mm}${dd}${hh}_SCANNER${scannerindex}_${min}.mp3
    	logfile=${logdir}/${yy}${mm}${dd}${hh}_SCANNER${scannerindex}_${min}.log

# 	[ $modm5 -eq 0 ] && /opt/bin/usbreset.sh $scannerindex

        if [ $modm -eq 0 -a $modf -eq 0 ]; then
#		    echo 0 > $scannerlck; sleep 1
            test -f "/proc/$(cat $arecordpidfile)/exe" && kill -9 $(cat $arecordpidfile)
            test -f "/proc/$(cat $loggerpidfile)/exe" && kill $(cat $loggerpidfile)
            sleep 5s
            test -f "/proc/$(cat $splitpidfile)/exe" && kill $(cat $splitpidfile)
            modf=1
        fi

    	case "$uopt" in
        	0) record
            	;;
        	1) record; livecast
            	;;
            *) livecast
                ;;

    	esac
    	
        sleep 15s

        [ "$modm" != 0 ] && modf=0

        if [ $(cat $stopfile) == 1 ]; then
            test -f "/proc/$(cat $arecordpidfile)/exe" && kill -9 $(cat $arecordpidfile)
            test -f "/proc/$(cat $darkpidfile)/exe" && kill -9 $(cat $darkpidfile)
            test -f "/proc/$(cat $loggerpidfile)/exe" && kill $(cat $loggerpidfile)
            test -f "/proc/$(cat $updatepidfile)/exe" && kill $(cat $updatepidfile)
            test -f "/proc/$(cat $splitpidfile)/exe" && kill $(cat $splitpidfile)
            sleep 5s
	    rm $stopfile
	    exit 1
        fi
done
