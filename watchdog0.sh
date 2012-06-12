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

export TZ=$timez
scannerhome="/scanner_audio"
arecordpidfile="/tmp/arecord${scannerindex}.pid"
arecordopts="-Dplug:dsnoop${scannerindex} -f S16_LE -r $samplerate -c 1 -q -t wav --process-id-file $arecordpidfile"
lameopts="-S -m m -q9 -b $bitrate -"
mp3spltopts="-s -p th=${th},min=${delay},trackmin=${mindur},off=${scorr},rm -Q -N"
mp3spltpidfile="/tmp/mp3splt${scannerindex}.pid"
renamepidfile="/tmp/rename${scannerindex}.pid"
darkconf="/tmp/darkice${scannerindex}.conf"
darkpidfile="/tmp/darkice${scannerindex}.pid"

host0=$(echo $host | awk -F: '{print $1}')
port=$(echo $host | awk -F: '{print $2}')

touch $arecordpidfile
touch $mp3spltpidfile
touch $renamepidfile
touch $darkpidfile

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
	if [ "$modm" -eq 0 -a "$mods" -eq 0 -o ! -f "/proc/$(cat $arecordpidfile)/exe" ];then
		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Killing previous instance."
		test -f "/proc/$(cat $arecordpidfile)/exe" && kill -9 $(cat $arecordpidfile)
		echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Starting new instance."
        echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Going to record to $recfile."
		test -d "$recdir" || mkdir -p "$recdir"
        echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] arecord opts: $arecordopts."
        echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] lame opts: $lameopts."
		arecord $arecordopts | lame $lameopts "$recfile" &
        echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] arecord started with pid $(cat $arecordpidfile)."
        echo "[ ${yy}-${mm}-${dd} ${hh}:${min}:${sec} ] Split variables values:"
        mp3spltinput=$recfile
        echo "recfile=$recfile"
        mp3spltrecdir=$recdir/SCANNER${scannerindex}/${hh}
        echo "mp3spltdir=$mp3spltrecdir"
        mp3spltoutput=${yy}${mm}${dd}${hh}${min}${sec}_@m@s
        echo "mp3spltoutput=$mp3spltoutput"
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

while (true); do
	yy=$(date +%Y)
	mm=$(date +%m)
	dd=$(date +%d)
	hh=$(date +%H)
    min=$(date +%M)
    sec=$(date +%S)
    modm=$(expr $min % $divm)
    mods=$(expr $sec % $divs)
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

    if [ "$mods" -eq 0 -a ! -f "/proc/$(cat $mp3spltpidfile)/exe" -a $uopt -ne 2 ];then
        mp3splt $mp3spltopts -d $mp3spltrecdir -o $mp3spltoutput $mp3spltinput & echo $! > $mp3spltpidfile
    fi
    if [ "$mods" -eq 30 -a ! -f "/proc/$(cat $mp3spltpidfile)/exe" -a ! -f "/proc/$(cat $renamepidfile)/exe" -a $uopt -ne 2 ];then
        rename.sh $mp3spltrecdir & echo $! > $renamepidfile
    fi
    sleep 0.75
done
