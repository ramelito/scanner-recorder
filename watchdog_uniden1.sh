#!/bin/bash

export PATH=/opt/bin:$PATH

scannerindex=$1
cardindex=$2
bitrate=$3
samplerate=$4
host=$5
pass=$6
mount=$7
div=60

scannerhome="/scanner_audio"
#scannerhome="/tmp"
arecordpidfile="/tmp/arecord${scannerindex}.pid"
loggerpidfile="/tmp/logger${scannerindex}.pid"
splitpidfile="/tmp/split${scannerindex}.pid"
audiodevice="-Dplughw:${cardindex},0"
arecordopts="-f S16_LE -r $samplerate -c 1 -t wav -q"
lameopts="-S -m m -q9 -b $bitrate"
refepochtimefile="/tmp/refepochtime${scannerindex}"
scannerlck="/tmp/scanner${scannerindex}.lck"
darkconf="/tmp/darkice${scannerindex}.conf"
darkpidfile="/tmp/darkice${scannerindex}.pid"

port=$(echo $host | awk -F: '{print $2}')
host0=$(echo $host | awk -F: '{print $1}')

touch $arecordpidfile
touch $loggerpidfile
touch $splitpidfile
touch $darkpidfile

gendarkconf () {
        echo "
        [general]
        duration        = 0
        bufferSecs      = 2
        reconnect       = yes

        [input]
        device          = plughw:${cardindex},0
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
        password        = $pass
        localDumpFile   = $recfile
" > $darkconf
}

while (true); do
	yy=$(date +%Y)
	mm=$(date +%m)
	dd=$(date +%d)
	hh=$(date +%H)
        min=$(date +%M)
        sec=$(date +%S)
        epoch0=$(date +%s)
	echo $epoch0
        mod=$(expr $min % $div)
	recdir=$scannerhome/${yy}${mm}${dd}
	recfile=${recdir}/${yy}${mm}${dd}${hh}_SCANNER${scannerindex}_${min}.mp3
	logfile=${recdir}/${yy}${mm}${dd}${hh}_SCANNER${scannerindex}_${min}.log
	if [ "$mod" -eq 0 -o ! -f "/proc/$(cat $darkpidfile)/exe" -o ! -f "/proc/$(cat $loggerpidfile)/exe" ];then
		echo "Killing previous instances."
		test $mod -eq 0 && echo 0 > $scannerlck
		test $mod -eq 0 && sleep 0.5
		test -f "/proc/$(cat $arecordpidfile)/exe" -a $mod -eq 0 && kill -9 $(cat $arecordpidfile)
		test -f "/proc/$(cat $loggerpidfile)/exe" -a $mod -eq 0 && kill -9 $(cat $loggerpidfile)
		test -f "/proc/$(cat $darkpidfile)/exe" -a $mod -eq 0 && kill -9 $(cat $darkpidfile)
		test -f "/proc/$(cat $splitpidfile)/exe" -a $mod -eq 0 && kill -9 $(cat $splitpidfile)

		echo "Starting new instances."
		test -d "$recdir" || mkdir -p "$recdir"
		echo $(date +%s) > $refepochtimefile
		echo "Checking connection."
                res=$(curl -s http://source:$pass@$host/admin/listclients?mount=/$mount)
                echo "Result: $res."
                if [[ "$res" =~ "<b>Source does not exist</b>" ]];then
                        echo "Connection established, killing offline recording if exists."
			echo 0 > $scannerlck; sleep 0.5
			test -f "/proc/$(cat $arecordpidfile)/exe" && kill -9 $(cat $arecordpidfile)
			test -f "/proc/$(cat $loggerpidfile)/exe" && kill -9 $(cat $loggerpidfile)
                        echo "Generating darkice config."
                        gendarkconf
                        echo "Starting darkice."
                        darkice -c $darkconf 1>/dev/null & echo $! > $darkpidfile
                        echo "Darkice started, stream is online, pid - $darkpidfile"
			test -f "/proc/$(cat $loggerpidfile)/exe" && kill -9 $(cat $loggerpidfile)
			logscanner.sh -s $scannerindex > $logfile & echo $! > $loggerpidfile
			sleep 2
			test -f "/proc/$(cat $splitpidfile)/exe" && kill $(cat $splitpidfile)
			split_record.sh $logfile & echo $! > $splitpidfile
                else
                #        echo "Connection failed or broken, continue with offline recording."
                        test -f "/proc/$(cat $arecordpidfile)/exe" || arecord $audiodevice $arecordopts --process-id-file $arecordpidfile | lame $lameopts - "$recfile" &
			if [ ! -f "/proc/$(cat $loggerpidfile)/exe" ];then
			       logscanner.sh -s $scannerindex > $logfile & echo $! > $loggerpidfile
			fi
			if [ ! -f "/proc/$(cat $splitpidfile)/exe" ]; then
			       split_record.sh $logfile & echo $! > $splitpidfile
			fi
                fi
		test $mod -eq 0 && sleep 60
	fi
	sleep 2
        epoch=$(date +%s)
        let diff=$epoch-$epoch0
	echo "$epoch0, $epoch, $diff"
	if [ $diff -gt 6 -a $mod -ne 0 ]; then
		echo "System time changed!"
                test -f "/proc/$(cat $arecordpidfile)/exe" && kill -9 $(cat $arecordpidfile)
                test -f "/proc/$(cat $loggerpidfile)/exe" && kill -9 $(cat $loggerpidfile)
                test -f "/proc/$(cat $splitpidfile)/exe" && kill -9 $(cat $splitpidfile)
		test -f "/proc/$(cat $darkpidfile)/exe"  && kill -9 $(cat $darkpidfile)
        fi

done
