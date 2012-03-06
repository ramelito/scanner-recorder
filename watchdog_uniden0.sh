#!/bin/bash

uopt=$1
scannerindex=$2
scardindex=$3
bitrate=$4
samplerate=$5
host=$6
pass=$7
mount=$8
divm=60
divs=60
modf=0

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
loggeropts="-s $scannerindex -d 800"

host0=$(echo $host | awk -F: '{print $1}')
port=$(echo $host | awk -F: '{print $2}')

touch $arecordpidfile
touch $splitpidfile
touch $loggerpidfile
touch $darkpidfile

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
#        [ $uopt -eq 1 ] && echo "localDumpFile   = $recfile" >> $darkconf
}

record () {
	if [ ! -f "/proc/$(cat $splitpidfile)/exe" -o ! -f "/proc/$(cat $loggerpidfile)/exe" -o ! -f "/proc/$(cat $arecordpidfile)/exe" ];then
		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Starting new instance."
        	echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Going to record to $recfile."
        test -f "/proc/$(cat $arecordpidfile)/exe" && kill -9 $(cat $arecordpidfile)
        test -f "/proc/$(cat $loggerpidfile)/exe" && kill -9 $(cat $loggerpidfile)
        test -f "/proc/$(cat $splitpidfile)/exe" && kill -9 $(cat $splitpidfile)
	
		test -d "$recdir" || mkdir -p "$recdir"
		echo $(date +%s) > $refepochtimefile        
	
		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] arecord opts: $arecordopts."
        	echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] lame opts: $lameopts."

		arecord $arecordopts | lame $lameopts "$recfile" &
		logscanner.sh $loggeropts > $logfile & echo $! > $loggerpidfile
        split_record.sh $logfile & echo $! > $splitpidfile

        	echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] arecord started with pid $(cat $arecordpidfile)."
		
	fi
}

livecast() {
	if [ ! -f "/proc/$(cat $darkpidfile)/exe" ];then
		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Killing previous instance."
        	
	        test -f "/proc/$(cat $darkpidfile)/exe" -a "$modm" -eq 0 && kill -9 $(cat $darkpidfile)
		
		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Starting new instance."
		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Checking connection."
	        
		res=$(curl -s http://source:$pass@$host/admin/listclients?mount=/$mount)
        	echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Result: $res."
	        if [[ "$res" =~ "<b>Source does not exist</b>" ]];then
        		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Connection established, killing offline recording if exists."
            		
			echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Generating darkice config."
            		
			gendarkconf
            		
			echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Starting darkice."
            		
			darkice -c $darkconf & echo $! > $darkpidfile
            		
			echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Darkice started, stream is online, pid - $(cat $darkpidfile)"

            fi
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
#	mods=$(expr $sec % $divs)
	recdir=$scannerhome/${yy}${mm}${dd}/ARCHIVE
	recfile=${recdir}/${yy}${mm}${dd}${hh}_SCANNER${scannerindex}_${min}.mp3
    logfile=${recdir}/${yy}${mm}${dd}${hh}_SCANNER${scannerindex}_${min}.log

        if [ $modm -eq 0 -a $modf -eq 0 ]; then
		    echo 0 > $scannerlck; sleep 1
            test -f "/proc/$(cat $arecordpidfile)/exe" && kill -9 $(cat $arecordpidfile)
            test -f "/proc/$(cat $loggerpidfile)/exe" && kill -9 $(cat $loggerpidfile)
            test -f "/proc/$(cat $splitpidfile)/exe" && kill -9 $(cat $splitpidfile)
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
    	
        sleep 20

        [ $modm -ne 0 ] && modf=0
#		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] DEBUG: Timing $modm $modf."

done
