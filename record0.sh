#!/bin/bash

export LANG=C
export PATH=/opt/bin:$PATH

test -f /scanner_audio/record.cfg && cp /scanner_audio/record.cfg /opt/etc/record.cfg
test -f /opt/etc/record.cfg && source /opt/etc/record.cfg
test -f /opt/etc/record.cfg || exit 1

type -P arecord &>/dev/null || { echo "No arecord utility is installed. Install alsa-utils."; exit 1 }
type -P lame &>/dev/null || { echo "No lame utility is installed. Install lame."; exit 1 }
type -P darkice &>/dev/null || { echo "No darkice utility is installed. Install darkice."; exit 1 }
type -P mp3splt &>/dev/null || { echo "No mp3splt utility is installed. Install mp3splt."; exit 1 }
type -P ffmpeg &>/dev/null || { echo "No ffmpeg utility is installed. Install ffmpeg."; exit 1 }

s0_type=$(echo $scanner0 | awk -F";" '{print $1}')
s0_port=$(echo $scanner0 | awk -F";" '{print $2}')
s0_scard=$(echo $scanner0 | awk -F";" '{print $3}')
s0_rec=$(echo $scanner0 | awk -F";" '{print $4}')
s0_ihost=$(echo $scanner0 | awk -F";" '{print $5}')
s0_ipass=$(echo $scanner0 | awk -F";" '{print $6}')
s0_imount=$(echo $scanner0 | awk -F";" '{print $7}')
s0_bitrate=$(echo $scanner0 | awk -F";" '{print $8}')
s0_samplerate=$(echo $scanner0 | awk -F";" '{print $9}')

test "X$s0_rec" == "X" && s0_rec=0
test $s0_samplerate -eq 16000 || s0_samplerate=16000
test $s0_bitrate -eq 48 || s0_bitrate=48

if [ $s0_type -eq 0 ]; then
	echo "Scanner is UNcontrolled."
	if [ "X$s0_scard" != "X" ]; then
		if [ $(arecord -l | grep "card $s0_scard:" | wc -l) -eq 1 ]; then
			echo "Scanner card $s0_scard exists."
			if [ $s0_rec -eq 0 ]; then
				echo "Let's start recording for uncontrolled scanner."
				watchdog0.sh $s0_scard $s0_bitrate $s0_samplerate 1>/tmp/watchdog0.log &
			fi
			if [ $s0_rec -eq 1 -a "X$s0_ihost" != "X" -a "X$s0_ipass" != "X" -a "X$s0_imount" != "X" ]; then
				watchdog1.sh $s0_scard $s0_bitrate $s0_samplerate $s0_ihost $s0_ipass $s0_imount 1>/tmp/watchdog1.log &
			fi
			if [ $s0_rec -eq 2 -a "X$s0_ihost" != "X" -a "X$s0_ipass" != "X" -a "X$s0_imount" != "X" ]; then
				watchdog2.sh $s0_scard $s0_bitrate $s0_samplerate $s0_ihost $s0_ipass $s0_imount 1>/tmp/watchdog2.log &
			fi
		fi
	fi
fi

if [ $s0_type -eq 1 ]; then
	echo "Scanner is controlled."
	res=""
	mdl="^MDL*"
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
	if [ "X$s0_scard" != "X" ]; then
		if [ $(arecord -l | grep "card $s0_scard:" | wc -l) -eq 1 ]; then
			echo "Scanner card $s0_scard exists."
			if [ $s0_rec -eq 0 ]; then
				echo "Let's start recording for Uniden scanner."
				watchdog_uniden0.sh $s0_port $s0_scard $s0_bitrate $s0_samplerate 1>/tmp/watchdog_uniden0.log &
			fi
			if [ $s0_rec -eq 1 -a "X$s0_ihost" != "X" -a "X$s0_ipass" != "X" -a "X$s0_imount" != "X" ]; then
				watchdog_uniden1.sh $s0_port $s0_scard $s0_bitrate $s0_samplerate $s0_ihost $s0_ipass $s0_imount 1>/tmp/watchdog_uniden1.log &
			fi
		fi
	fi
fi
