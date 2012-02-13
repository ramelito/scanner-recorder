#!/bin/bash

export LANG=C
export PATH=/opt/bin:$PATH

res=""
mdl="^MDL*"

test -f /scanner_audio/record.conf && cp /scanner_audio/record.conf /opt/etc/
test -f /opt/etc/record.conf && source /opt/etc/record.conf || ( echo "File record.conf not found in /opt/etc."; exit 1 )

type -P arecord &>/dev/null || ( echo "No arecord utility is installed. Install alsa-utils."; exit 1 )
type -P lame &>/dev/null || ( echo "No lame utility is installed. Install lame."; exit 1 )
type -P darkice &>/dev/null || ( echo "No darkice utility is installed. Install darkice."; exit 1 )
type -P mp3splt &>/dev/null || ( echo "No mp3splt utility is installed. Install mp3splt."; exit 1 )

s0_type=$(echo $scanner0 | awk -F";" '{print $1}')
s0_port=$(echo $scanner0 | awk -F";" '{print $2}')
s0_scard=$(echo $scanner0 | awk -F";" '{print $3}')
s0_rec=$(echo $scanner0 | awk -F";" '{print $4}')
s0_ihost=$(echo $scanner0 | awk -F";" '{print $5}')
s0_ipass=$(echo $scanner0 | awk -F";" '{print $6}')
s0_imount=$(echo $scanner0 | awk -F";" '{print $7}')
s0_profile=$(echo $scanner0 | awk -F";" '{print $8}')

test "X$s0_rec" == "X" && s0_rec=0
test "X$s0_scard" == "X" && s0_card=0
[ $(arecord -l | grep "card $s0_scard:" | wc -l) -eq 1 ] || ( echo "Card $s0_scard does not exist."; exit 1 )

case "$s0_profile" in
        lq)
                s0_samplerate=8000; s0_bitrate=16
                ;;
        mq)
                s0_samplerate=11025; s0_bitrate=24
                ;;
        hq)
                s0_samplerate=16000; s0_bitrate=48
                ;;
	*)
                s0_samplerate=8000; s0_bitrate=16
		;;	
esac

if [ $s0_type -eq 0 ]; then
	echo "Scanner is UNcontrolled."
	if [ $s0_rec -eq 0 ]; then
		echo "Simple recording."
		watchdog0.sh $s0_scard $s0_bitrate $s0_samplerate 1>/tmp/watchdog0.log &
	fi
	if [ $s0_rec -eq 1 ]; then
		echo "Simple recording and livecast."

		test "X$s0_ihost" == "X" && ( echo "Icecast server host not defined. Aborting."; exit 1 )
		test "X$s0_ipass" == "X" && ( echo "Icecast password not defined. Aborting."; exit 1 )
		test "X$s0_imount" == "X" && ( echo "Icecast mount not defined. Aborting."; exit 1 )

		watchdog1.sh $s0_scard $s0_bitrate $s0_samplerate $s0_ihost $s0_ipass $s0_imount 1>/tmp/watchdog1.log &
	fi
	if [ $s0_rec -eq 2 ]; then
		echo "Livecast only."

		test "X$s0_ihost" == "X" && ( echo "Icecast server host not defined. Aborting."; exit 1 )
		test "X$s0_ipass" == "X" && ( echo "Icecast password not defined. Aborting."; exit 1 )
		test "X$s0_imount" == "X" && ( echo "Icecast mount not defined. Aborting."; exit 1 )

		watchdog2.sh $s0_scard $s0_bitrate $s0_samplerate $s0_ihost $s0_ipass $s0_imount 1>/tmp/watchdog2.log &
	fi
fi

if [ $s0_type -eq 1 ]; then
	echo "Scanner is controlled."
	while (true); do
		test -L /dev/scanners/$s0_port && res=$(MDL -s$s0_port)
		echo $res
		if [[ "$res" =~ $mdl ]]; then
			model=$(echo $res | awk -F, '{print $2}')
			echo "Scanner detected. Model is $model."
			break
		fi
		sleep 10
	done
	if [ $s0_rec -eq 0 ]; then
		echo "Recording for Uniden scanner."
		watchdog_uniden0.sh $s0_port $s0_scard $s0_bitrate $s0_samplerate 1>/tmp/watchdog_uniden0.log &
	fi
	if [ $s0_rec -eq 1 ]; then
		echo "Recording for Uniden scanner and livecast."

		test "X$s0_ihost" == "X" && ( echo "Icecast server host not defined. Aborting."; exit 1 )
		test "X$s0_ipass" == "X" && ( echo "Icecast password not defined. Aborting."; exit 1 )
		test "X$s0_imount" == "X" && ( echo "Icecast mount not defined. Aborting."; exit 1 )

		watchdog_uniden1.sh $s0_port $s0_scard $s0_bitrate $s0_samplerate $s0_ihost $s0_ipass $s0_imount 1>/tmp/watchdog_uniden1.log &
	fi
fi
