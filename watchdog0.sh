#!/bin/bash

uopt=$1
scannerindex=$2
bitrate=$3
samplerate=$4
scorr=$5
delay=$6
mindur=$7
th=$8
timez=$9
host=${10}
pass=${11}
mount=${12}
divm=60
divs=60
modf=0

export TZ=$timez
scannerhome="/scanner_audio"
arecordpidfile="/tmp/arecord${scannerindex}.pid"
arecordopts="-Dplug:dsnoop${scannerindex} -f S16_LE -r $samplerate -c 1 -q -t wav --process-id-file $arecordpidfile"
lameopts="-S -m m -q9 -b $bitrate -"
spltrnamepidf="/tmp/spltrnamepidf${scannerindex}.pid"
darkconf="/tmp/darkice${scannerindex}.conf"
darkpidfile="/tmp/darkice${scannerindex}.pid"
stopfile="/tmp/stop${scannerindex}"

host0=$(echo $host | awk -F: '{print $1}')
port=$(echo $host | awk -F: '{print $2}')

touch $arecordpidfile
touch $spltrnamepidf
touch $darkpidfile

echo 0 > $stopfile

[ "X$uopt" == "X" ] && uopt=0

gendarkconf () {
    echo "
        [general]
        duration        = 0
        bufferSecs      = 2
        reconnect       = yes

        [input] 
        device          = plug:dsnoop${scannerindex}
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
	if [ ! -f "/proc/$(cat $arecordpidfile)/exe" ];then
		test -f "/proc/$(cat $arecordpidfile)/exe" && kill -9 $(cat $arecordpidfile)
		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Starting new instance."
        	echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Going to record to $recfile."
		test -d "$recdir" || mkdir -p "$recdir"
        	echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] arecord opts: $arecordopts."
        	echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] lame opts: $lameopts."
		arecord $arecordopts | lame $lameopts "$recfile" &
        	echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] arecord started with pid $(cat $arecordpidfile)."
        	echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Split variables values:"
        	spltin=$recfile
        	echo "recfile=$recfile"
        	spltrecdir=$todaydir/SCANNER${scannerindex}/${hh}
        	echo "spltdir=$spltrecdir"
        	spltout=${yy}${mm}${dd}${hh}${min}${sec}_@m@s
        	echo "spltout=$spltout"
		sleep 60
	fi
}

livecast() {
    if [ ! -f "/proc/$(cat $darkpidfile)/exe" ];then
		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Starting new instance."
        	echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Checking connection."
        	res=$(curl -s http://source:$pass@$host/admin/listclients?mount=/$mount)
        	echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Result: $res."
            	echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Generating darkice config."
            	gendarkconf
        	if [[ "$res" =~ "<b>Source does not exist</b>" ]];then
            		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Starting darkice."
            		darkice -c $darkconf & echo $! > $darkpidfile
            		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Darkice started, stream is online, pid - $(cat $darkpidfile)"
        	fi
    fi
}

spltrname() {
    if [ $uopt -ne 2 -a ! -f "/proc/$(cat $spltrnamepidf)/exe" ];then
	split_rename.sh $th $delay $mindur $scorr $spltrecdir $spltout $spltin & echo $! > $spltrnamepidf
    fi
}

while (true); do
	yy=$(date +%Y)
	mm=$(date +%m)
	dd=$(date +%d)
	hh=$(date +%H)
    	min=$(date +%M)
    	sec=$(date +%S)
    	modm=$(expr $min % $divm)
    	mods=$(expr $sec % $divs)
        todaydir=$scannerhome/${yy}${mm}${dd}	
	recdir=$scannerhome/${yy}${mm}${dd}/REC
	recfile=${recdir}/${yy}${mm}${dd}${hh}_SCANNER${scannerindex}_${min}.mp3

    case "$uopt" in
        0) record
            ;;
        1) record; livecast
            ;;
        *) livecast
            ;;
    esac

    spltrname

   if [ $modm -eq 0 -a $modf -eq 0 ]; then
        test -f "/proc/$(cat $arecordpidfile)/exe" && kill -9 $(cat $arecordpidfile)
	spltrname	
	modf=1
   fi

   [ "$modm" != 0 ] && modf=0

   if [ $(cat $stopfile) == 1 ]; then
       	echo "Received signal to stop..."
	echo -n "Stopping arecord ..." 
	test -f "/proc/$(cat $arecordpidfile)/exe" && kill -9 $(cat $arecordpidfile)
	echo "ok!"
        echo -n "Stopping darkice ..." 
	test -f "/proc/$(cat $darkpidfile)/exe" && kill -9 $(cat $darkpidfile)
        echo "ok!" 
   	spltrname	
	exit 1
   fi
   sleep 15 
done
