#!/bin/bash
#    Recorder script for scanners
#
#    Copyright (C) 2012  Anton Komarov
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

export LANG=C
export PATH=/sbin:/usr/sbin:/usr/local/sbin:/opt/sbin:/bin:/usr/bin:/usr/local/bin:/opt/bin

verbose=10
qui_lvl=0
err_lvl=10
inf_lvl=50
dbg_lvl=99

workbin=/opt/bin
scanner_audio="/scanner_audio"
config="/opt/etc/record.conf"
asound_conf="/etc/asound.conf"
hardware="beagle"
ms_action=""
wstart=""
_wdog=""
_split=""
_update=""

test -f $HOME/.recorderc && source $HOME/.recorderc

#Global funcs

usage () {

echo "Recorder usage help.

	-h, --help	shows this help
	--verbose	verbosity level 
			0 - quiet, 
			10 - error, 
			50 - info, 
			99 - debug
	--install	install software on box
	--with-udvrls	install udev rules
	--with-crnjbs	install cron jobs
	
	--config	config file location
	--start		starting recorders using record.conf file
	--stop		stopping recorders using record.conf file
	--wstart	starting watchdog
	--split		split function init
	--update	update function init
	--type		scanner type
			0 - uncontrolled
			1 - uniden
	--port		scanner serial port
	--scard		soundcard usb port
	--rec		record mode
			0 - record
			1 - record and live
			2 - live
	--ihost		icecast server
	--ipass		mount point password
	--imount	mount point
	--profile	audio profile
	--icao		icao code for METAR retreive
	--scor		start split correction
	--ecor		end split correction
	--delay		recording delay after squelch closing
	--mindur	minimum duration
	--timez		timezone
	--th		threshold for mp3splt utility
	--vol		volume for controlled scanners
	--srate		sample rate for arecord and darkice
	--brate		bitrate for arecord and darkice
	--divm		modulo for audio rotation
	--log-file	log file for split
	--rec-file	rec file for split
	--split-dir	directory for split
	--template	template for mp3splt
	--extdrive	manage external drive connection
	--usbdev	usb device for external drive connection
	--mntpnt	mount point for external drive connection
	--mntopts	mount options for mount point for extdrive
	--mngaddr	manage ip address
	--intf		interface name to manage
	--clean		clean old files procedure
	--modem-up	modem up function
	--misp		mobile internet service provider (e.g. megafon)
	--mport		modem port
"
exit 0
}



_log () {
    if [ $verbose -ge $1 ]; then
        echo -e "$2" | fold -w140 -s | sed '2~1s/^/  /'
	logger -t recorder.sh "$2"
    fi
}

_notify () {
	_log $qui_lvl "[$(date "+%Y-%m-%d %H:%M:%S %Z")] NOTE: $1"
}

_error () {
	_log $err_lvl "[$(date "+%Y-%m-%d %H:%M:%S %Z")] ERROR: $1"
}

_info () {
	_log $inf_lvl "[$(date "+%Y-%m-%d %H:%M:%S %Z")] INFO: $1"
}

_debug () {
	_log $dbg_lvl "[$(date "+%Y-%m-%d %H:%M:%S %Z")] DEBUG: $1"
}

chk_sw () {

	local fail=0
	local sw_list="ifconfig route ping ntpdate mktemp env cat wc od bc tr stty"
	sw_list="$sw_list arecord lame darkice mp3splt stat glgsts sox head uniq curl"
	sw_list="$sw_list insserv wget md5sum df find uname logger"

	_notify "Check installed software."


	for sw in $sw_list; do
		if [ $(type -P $sw) ]; then
			_info "$sw utility is istalled."
		else
		 	_error "$sw is not installed."
			fail=1
		fi
	done

	if [ $fail -eq 1 ]; then
		_error "Exiting..."
		exit 1
	fi
}

chk_net () {

	_notify "Check network connection."
	if [ "$(ping -c1 -w10 8.8.8.8)" ]; then
		_info "Network is up. Sync with NTP servers."
		ntpdate -s pool.ntp.org
	else
		_error "Network is down."
	fi
}

chk_conf () {

	_notify "Check record.conf."

	if [ -f $config ]; then
		_info "Sourcing $config"
		while read line; do
			_debug $line
		done < $config	
		source $config
	else
		_error "$config does not exist, exiting..."
		exit 1
	fi
}

asgn_addr () {

	if [ "X$eth0_address" != "X" ]; then
		_notify "assign static ip address $eth0_address to interface eth0."

        	if [ "X$eth0_netmask" == "X" ]; then
			_error "netmask is not set, exiting..."
			exit 1
		fi

        	if [ "X$eth0_gw" == "X" ]; then
			_error "default gateway is not set, exiting..."
			exit 1
		fi

		_info "ifconfig eth0 $eth0_address netmask $eth0_netmask"
        	ifconfig eth0 $eth0_address netmask $eth0_netmask
		_debug $(ifconfig eth0)

		_info "route add default gw $eth0_gw"
        	route add default gw $eth0_gw
		_debug $(route -n)

		_info "pushing $eth0_dns to /etc/resolv.conf."
    		echo "nameserver $eth0_dns" > /etc/resolv.conf
		_debug $(cat /etc/resolv.conf)
	fi
	
}

#Main starter

main_starter () {

	local envdump
	local num
	local opts

	case "$ms_action" in
		start)
			chk_sw
			chk_conf;
			asgn_addr;
			chk_net;

			_notify "throttling processor."
			cpufreq-set -g performance

			num=$(cat $config | grep ^scanner[0-9]* | wc -l)
			_info "found $num config lines."
			test -d $scanner_audio || mkdir $scanner_audio	
			_debug "remove previous asound.conf."	
			test -f $asound_conf && rm $asound_conf

			for i in $(seq 1 $num); do
			        params=$(eval   "echo \$$( echo scanner${i})")
				local s0_type=$(echo $params | cut -d, -f1)
				local s0_port=$(echo $params | cut -d, -f2)
				local s0_scard=$(echo $params | cut -d, -f3)
				local s0_rec=$(echo $params | cut -d, -f4)
				local s0_ihost=$(echo $params | cut -d, -f5)
				local s0_ipass=$(echo $params | cut -d, -f6)
				local s0_imount=$(echo $params | cut -d, -f7)
				local s0_profile=$(echo $params | cut -d, -f8)
				local s0_icao=$(echo $params | cut -d, -f9)
				local s0_scor=$(echo $params | cut -d, -f10)
				local s0_ecor=$(echo $params | cut -d, -f11)
				local s0_delay=$(echo $params | cut -d, -f12)
				local s0_mindur=$(echo $params | cut -d, -f13)
				local s0_timez=$(echo $params | cut -d, -f14)
				local s0_th=$(echo $params | cut -d, -f15)
				local s0_vol=$(echo $params | cut -d, -f16)
				local s0_divm=$(echo $params | cut -d, -f17)

				test "X$s0_type" == "X" && s0_type=0
				test "X$s0_scard" == "X" && s0_scard=0
				test "X$s0_port" == "X" && s0_port=$s0_scard
				test "X$s0_rec" == "X" && s0_rec=0
				test "X$s0_ihost" == "X" && s0_ihost="none"
				test "X$s0_ipass" == "X" && s0_ipass="none"
				test "X$s0_imount" == "X" && s0_imount="none"
				test "X$s0_profile" == "X" && s0_profile="lq"
				test "X$s0_scor" == "X" && s0_scor=0
				test "X$s0_ecor" == "X" && s0_ecor=0
				test "X$s0_delay" == "X" && s0_delay="0.8"
				test "X$s0_mindur" == "X" && s0_mindur="2.5"
				test "X$s0_timez" == "X" && s0_timez="UTC"
				test "X$s0_th" == "X" && s0_th="-48"
				test "X$s0_vol" == "X" && s0_vol=4
				test "X$s0_icao" == "X" && s0_icao="UUEE"
				test "X$s0_divm" == "X" && s0_divm=10

				opts="--wstart --type $s0_type --port $s0_port --scard $s0_scard"
				opts="$opts --rec $s0_rec --ihost $s0_ihost --ipass $s0_ipass"
				opts="$opts --imount $s0_imount --profile $s0_profile"
				opts="$opts --icao $s0_icao --scor $s0_scor --ecor $s0_ecor"
				opts="$opts --delay $s0_delay --mindur $s0_mindur --timez $s0_timez"
				opts="$opts --th $s0_th --vol $s0_vol --verbose $verbose --divm $s0_divm"
				_info "params for scanner $s0_port: $params"	
				_info "starting recorder.sh with opts:  $opts"
        			recorder.sh $opts &
			        sleep 1
			done
			;;
		stop)
			_notify "Stopping recorders."
			for stops in $(ls /tmp/stop*); do
				_notify "stopping recorder ($stops)."
				echo 1 > $stops
			done
		;;
	esac
}

#Watchdog starter

wdog_starter () {

	local opts

	_notify "run watchdog starters."

	ipckey=$(cat /dev/urandom | od -N2 -An -i)

	if [ $scard -eq 0 ]; then
		
		echo "pcm.dsnoop0 {
		        type dsnoop
        		    ipc_key $ipckey
		            slave {
       			 	    pcm {
                			type hw
	               			card $hardware
	                		device 0
		            	}
	        		rate 16000
		        	channels 1
	        	}
		    } " >> $asound_conf
	else
		echo "pcm.dsnoop$scard {
			type dsnoop
			ipc_key $ipckey
			slave {
				pcm {
					type hw
					card USBSOUND$scard
					device 0
				}
				rate 16000
				channels 1
			}
		} " >> $asound_conf
	fi

	case "$profile" in
        	lq)
                	srate=8000; brate=16
                	;;
        	mq)
                	srate=11025; brate=24
                	;;
        	hq)
                	srate=16000; brate=48
                	;;
        	*)
                	srate=8000; brate=16
                        ;;
	esac

        if [ $rec -gt 0 ]; then
              	_notify "Livecast with optional recording."

               	if [ "$ihost" == "none" ]; then
			_error "icecast server host not defined, exiting..." 
			exit 1
		fi
               	if [ "$ipass" == "none" ]; then 
			_error "icecast password not defined, exiting..." 
			exit 1
		fi
               	if [ "$imount" == "none" ]; then
			_error "icecast mount not defined, exiting..."
			exit 1
		fi
       	fi

	if [ $type -eq 0 ]; then
        	_notify "Scanner is uncontrolled."

	fi

	if [ $type -eq 1 ]; then
        	_notify "Scanner is controlled (Uniden)."
        	while (true); do
        		if [ -L /dev/scanners/$port ]; then
            			stty -F /dev/scanners/$port 115200 raw
				_info "Sending cmd VOL,$vol to port $sport"
				/opt/bin/sendcmd.sh -s$sport -c VOL,$vol
            			break;
        		fi
        	done
	fi

	opts="--wdog --type $type --port $port --scard $scard"
	opts="$opts --rec $rec --ihost $ihost --ipass $ipass"
	opts="$opts --imount $imount --profile $profile"
	opts="$opts --icao $icao --scor $scor --ecor $ecor"
	opts="$opts --delay $delay --mindur $mindur --timez $timez"
	opts="$opts --th $th --vol $vol --srate $srate --brate $brate"
	opts="$opts --verbose $verbose --divm $divm"
	_info "$opts"
	recorder.sh $opts &
}

#Watchdog

gen_dc () {


    echo "[general]
duration        = 0
bufferSecs      = 2
reconnect       = yes

[input]
device          = plug:dsnoop${scard}
sampleRate      = $srate
bitsPerSample   = 16
channel         = 1

[icecast2-0]
format          = mp3
bitrateMode     = cbr
bitrate         = $brate
server          = $ihost
mountPoint      = $imount
port            = $iport
password        = $ipass
"
}

split0 () {

	_info "starting simple splitting func."

	local soxopts="silence -l 1 0.1 1% -1 0.5 1%"

	local mp3spltopts="-s -p th=${th},min=${delay} -Q -N"
	mp3spltopts="$mp3spltopts -d $split_dir -o $_template $rec_file"	
	_info "mp3splt opts: $mp3spltopts"
        mp3splt $mp3spltopts
        list=$(mktemp)

	_debug "preparing $list for list of files to process."
        ls $split_dir | grep RAWSPLIT > $list
        numlines=$(cat $list | wc -l)
	_notify "$numlines found after split."

        if [ "$numlines" == "0" ]; then
		rm $list
		return 0
	fi

	_debug "reading list to rename."
        while read line; do
                local filename=${line%.*}
                local datepart=$(echo $filename | cut -d"_" -f2)
                local shiftpart=$(echo $filename | cut -d"_" -f3)
                local shiftmins=${shiftpart:0:2}
                local shiftsecs=${shiftpart:2:2}
                local dpyy=${datepart:0:4}
                local dpmm=${datepart:4:2}
                local dpdd=${datepart:6:2}
                local dphh=${datepart:8:2}
                local dpmins=${datepart:10:2}
                local dpsecs=${datepart:12:2}
                local dpepoch=$(date -d "${dpyy}-${dpmm}-${dpdd} ${dphh}:${dpmins}:${dpsecs}" +%s)
                [ ${shiftsecs:0:1} == 0 ] && shiftsecs=${shiftsecs:1:1}
                [ ${shiftmins:0:1} == 0 ] && shiftmins=${shiftmins:1:1}
                let shiftsecs=${shiftmins}*60+$shiftsecs
                let dpepoch=$dpepoch+$shiftsecs
                local newfile=${split_dir}/$(date -d "@$dpepoch" +%Y-%m-%d_%Hh%Mm%Ss)
                if [ ! -f ${newfile}.mp3 ]; then
                       	_info "soxing ${split_dir}/${line} to ${newfile}.wav" 
			sox ${split_dir}/${line} ${newfile}.wav $soxopts
			_info "laming ${newfile}.wav to ${newfile}.mp3 with bitrate=$brate."
                        lame --quiet -b $brate ${newfile}.wav ${newfile}.mp3
                        rm ${newfile}.wav
                fi
               	_debug "removing ${split_dir}/${line}." 
		rm ${split_dir}/${line}
        done < $list
	_debug "removing $list."
        rm $list
}

split1 () {
	
	_info "starting Uniden splitting func."
	
	local logdir=$(dirname $log_file)
	local comma=".*,$"
	_mindur=$(echo "$mindur*1000" | bc | cut -d. -f1)
	local fname=${log_file##*/}
	local yymmdd=${fname:0:8}
	local hh=${fname:8:2}
	local elogdir=/tmp/EXT_${port}
	local mp3spltopts="-Q"
	local numlines0=0
	local n=0
	local code=""
	local uids=""

	test -f $log_file || ( _error "$log_file does not exists"; exit 1 )
	test -f $rec_file || ( _error "$rec_file does not exists"; exit 1 )

        numlines=$(cat $log_file | wc -l)
	_notify "$numlines found in $log_file."

   	if [ $numlines -gt $numlines0 ]; then
        	let cutlines=$numlines-$numlines0+3
        	[ $cutlines -gt $numlines ] && cutlines=$numlines
    	else
       		cutlines=0
    	fi

    	numlines0=$numlines

	ctf=$(mktemp)
	_debug "creating temp file $ctf."

 	head -n$numlines $log_file | tail -n${cutlines} > $ctf

	while read line; do

        	local line=$(echo $line | sed -e 's/ /_/g')
	        local system=$(echo $line | cut -d, -f 6 | sed -e 's/^_//g')
	        local group=$(echo $line | cut -d, -f 7 | sed -e 's/^_//g')
	        local channel=$(echo $line | cut -d, -f 8 | sed -e 's/^_//g')
	        local freq=$(echo $line | cut -d, -f 2 | sed -e 's/^0*//g')
	        local r0=$(echo $line | cut -d, -f 14)
        	local s0=$(echo $line | cut -d, -f 15)
	        local e0=$(echo $line | cut -d, -f 16)

	        if [ "X$e0" != "X" ]; then
			_debug "e0=$e0."

	                local d0=$(echo "($e0-$s0)*1000" | bc)
                	local d0=$(echo $d0 | cut -d. -f 1)

                	if [ $d0 -le $_mindur ]; then
				_debug "$d0 less than $_mindur."
                    		[ -e "$elogdir/$s0" ] && rm "$elogdir/$s0"
                    		continue
                	fi
			s=$(echo "scale=2; $s0-$r0$scorr" | bc)
			e=$(echo "scale=2; $e0-$r0$ecorr" | bc)
			ss=$(echo $s | cut -d. -f1)
			sh=$(echo $s | cut -d. -f2)
			es=$(echo $e | cut -d. -f1)
			eh=$(echo $e | cut -d. -f2)
			[ "X$ss" == "X" -o "${ss:0:1}" == 0 ] && ss=0
			[ "X$es" == "X" -o "${es:0:1}" == 0 ] && es=0
			[ "X$sm" == "X" -o "${sm:0:1}" == 0 ] && sm=0
			[ "X$em" == "X" -o "${em:0:1}" == 0 ] && em=0
                    	sm=$(expr $ss / 60)
                	ss=$(expr $ss % 60)
                	em=$(expr $es / 60)
                    	es=$(expr $es % 60)
			fdp=$(date -d @$s0 +%Y-%m-%d_%Hh%Mm%Ss)
			_debug "fdp is $fdp."
            		if [[ "$freq" =~ \. ]]; then
                    		filename="${fdp}_${freq}_MHz"
				_debug "filename is $filename."

                    		dir1="${scanner_audio}/${yymmdd}/${system}/${group}/${channel}/${hh}"
                        	[ "X$group" == "X" ] && dir1="${scanner_audio}/${yymmdd}/${system}/${freq}/${hh}"
				_debug "dir1 is $dir1."
                		test -d "$dir1" || mkdir -p "$dir1"

                		[ -s "$elogdir/$s0" ] || sleep 3s
                		if [ -s "$elogdir/$s0" ];then
                    			cut -d, -f 9 "$elogdir/$s0" > "$elogdir/$s0".1
   code=$(cat "$elogdir/$s0".1 | sort -u | grep "$freq" | tr ' ' '\n' | sed -e '/^$/d' | grep C | tr '\n' '_' | sed -e 's/_$//g')
                    			_debug "extracting code $code. File $elogdir/$s0, size $(stat -c %s $elogdir/$s0)."
                		fi
				_debug "code is $code."
                		[ -e "$elogdir/$s0".1 ] && rm "$elogdir/$s0".1
                    		[ "X$code" != "X" ] && filename="${filename}_${code}"
				_debug "filename is $filename."
                		code=""
            		else
                    		filename="${fdp}_${freq}_${system}"
				_debug "filename is $filename."

                    		dir1="${scanner_audio}/${yymmdd}/${group}/${channel}/${hh}"
                        	test "X$group" == "X" && dir1="${scanner_audio}/${yymmdd}/FOUNDTGIDS/${freq}/${hh}"
				_debug "dir1 is $dir1."
                		dir1=$(echo "$dir1" | sed -e 's/\://')
                		test -d "$dir1" || mkdir -p "$dir1"

                		[ -s "$elogdir/$s0" ] || sleep 3s
                		if [ -s "$elogdir/$s0" ]; then
                    			cut -d, -f 7,9 "$elogdir/$s0" | grep UID > "$elogdir/$s0".1
uids=$(cat "$elogdir/$s0".1 | clrsym.sed | tr ' ' '\n' | sed -e '/^$/d' | sed -e "/\b$freq\b/d" | uniq | tr '\n' '_' | sed -e 's/_$//g')
                    			_debug "extracting uids $uids. File $elogdir/$s0, size $(stat -c %s $elogdir/$s0)."
                		fi
                		[ -e "$elogdir/$s0".1 ] && rm "$elogdir/$s0".1
                		[ "X$uids" != "X" ] && filename="${filename}_${uids}"
				_debug "filename is $filename."
                		uids=""
            		fi
                    	mp3splt $mp3spltopts $rec_file $sm.$ss.$sh $em.$es.$eh -d "${dir1}" -o "${filename}"
            		_info "cutting ${filename}"
			_info "from $rec_file"
			_info "to ${dir1},"
			_info "start $sm.$ss.$sh, end $em.$es.$eh."
        	fi
    	done < $ctf
	
	_debug "removing $ctf."
        rm $ctf
}

split () {

	_info "starting splitter."

	th=$(echo $th | sed -e 's/m/-/g')
	scor=$(echo $scor | sed -e 's/m/-/g')
	scor=$(echo $scor | sed -e 's/p/\+/g')
	ecor=$(echo $ecor | sed -e 's/m/-/g')
	ecor=$(echo $ecor | sed -e 's/p/\+/g')
	

	while (true); do
	
		sleep $divm 
		case "$type" in
			0)
			split0
			;;
			1)
			split1
			;;	
		esac


		_info "starting for next cycle."
	done

}

update () {
	
	_info "starting update for icecast."

	prevline="EMPTY"
	metarfile="/tmp/${icao}.metar"

	while (true); do

	        sleep 1
	        
		yyyymmdd=$(date +%Y%m%d)

		logdir=${scanner_audio}/$yyyymmdd/LOG		

        	test -d "$logdir" || continue

	        slog="$(ls -tr $logdir | grep SCANNER${port} | tail -1)"

        	[ "X$slog" == "X" ] && continue
		
		slog=$logdir/$slog

	        if [ ! -e $slog ]; then
        	        curline=""
	        else
        	        curline=$(tail -1 $slog | awk -F, '{print $6" "$7" "$8" "$2}' | sed -e 's/ /+/g')
	        fi

        	if [ ! -e $metarfile ]; then
                	metar=""
	        else
        	        metar=$(head -1 $metarfile | sed -e 's/+/&#43;/g' | sed -e 's/ /+/g')
	        fi
        	if [ "$prevline" != "$curline" ]; then
		        _info "change in $slog detected."
			_debug "update $ihost:${iport}/$imount ... "
			_debug "... with $curline+$metar"
                	webaddr="http://${ihost}:${iport}/admin/metadata?mount=/${imount}&mode=updinfo&song=$curline+$metar"
	                curl -o $curlout -s -u source:${ipass} $webaddr
        	fi
        	prevline="$curline";
	done
}

record () {

	local sw_killed=0
	touch $apf

        local exe1="/proc/$(cat $apf)/exe"
        local exe2="/proc/$(cat $spf)/exe"
        local exe3="/proc/$(cat $lpf)/exe"

	case "$type" in
		0)
			_info "checking arecord or split are running."

			if [ ! -f "$exe1" -o ! -f "$exe2" ]; then

				_info "arecord kill -9 on pid $(cat $apf)"
                		test -f "/proc/$(cat $apf)/exe" && kill -9 $(cat $apf)

				_info "split kill on pid $(cat $spf)"
                		test -f "/proc/$(cat $spf)/exe" && kill $(cat $spf)

				sw_killed=1
			fi
			;;	
		1)
			_info "checking arecord, split or logger are running."
			
			if [ ! -f "$exe1" -o ! -f "$exe2" -o ! -f "$exe3" ] ; then

				_info "arecord kill -9 on pid $(cat $apf)"
                		test -f "/proc/$(cat $apf)/exe" && kill -9 $(cat $apf)

				_info "split kill on pid $(cat $spf)"
                		test -f "/proc/$(cat $spf)/exe" && kill $(cat $spf)

				_info "logger kill -9 on pid $(cat $lpf)"
                		test -f "/proc/$(cat $lpf)/exe" && kill -9 $(cat $lpf)
				test -d "$elogdir" && rm -rf "$elogdir"

				sw_killed=1
			fi
			;;	
	esac

	test $sw_killed -eq 0 && return 0

	_info "check if $rec_dir, $log_dir and $elogdir exist, otherwise create them."

	test -d "$rec_dir" || mkdir -p "$rec_dir"
	test -d "$log_dir" || mkdir -p "$log_dir"
	test -d "$elogdir" || mkdir -p "$elogdir"

	_info "starting new arecord, split and logger instances."
	_info "recording to $rec_file"

	_info "starting arecord with opts: $aopts."
	_info "starting lame with opts: $lopts."

        arecord $aopts | lame $lopts "$rec_file" &
        sleep 2

       _notify "checking if arecord has started."
        if [ ! -f $apf -o ! -f "/proc/$(cat $apf)/exe" ]; then
		_error "arecord is dead, killing darkice if exists."
	        test -f "/proc/$(cat $dpf)/exe" && kill -9 $(cat $dpf)
	        return 1
       fi

       opts="--split --type $type --port $port --scard $scard"
       opts="$opts --rec $rec --ihost $ihost --ipass $ipass"
       opts="$opts --imount $imount --profile $profile"
       opts="$opts --icao $icao --scor $scor --ecor $ecor"
       opts="$opts --delay $delay --mindur $mindur --timez $timez"
       opts="$opts --th $th --vol $vol --srate $srate --brate $brate"
       opts="$opts --divm $divm --verbose $verbose"

	if [ $type -gt 0 ]; then
		local nanos=$(stat -c %z $apf | cut -d. -f2)
		local reftime=$(stat -c %Z $apf)
		gopts="$gopts -l $log_file -i $elogdir -r $reftime.${nanos:0:2}"
		_debug "starting glgsts with gopts."
		glgsts $gopts & echo $! > $lpf

		opts="$opts --log-file $log_file --rec-file $rec_file"
		
		_info "starting split with $opts."

		recorder.sh $opts & echo $! > $spf
	else
        	split_dir=$today_dir/SCANNER${port}/${hh}
	        split_out=RAWSPLIT_${yy}${mm}${dd}${hh}${min}${sec}_@m@s
		
		_info "split env: $rec_file, $split_out, $split_dir."
	
		opts="$opts --rec-file $rec_file --split-dir $split_dir"
		opts="$opts --template $split_out"
		
		_info "starting split with $opts."
	
		recorder.sh $opts & echo $! > $spf
	fi

	_info "arecord started with pid $(cat $apf)."
}

livecast () {

        local exe1="/proc/$(cat $dpf)/exe"
        local exe2="/proc/$(cat $upf)/exe"

        if [ ! -f "$exe1" -o ! -f "$exe2" ];then
				
		_info "darkice kill -9 on pid $(cat $dpf)"
                test -f "/proc/$(cat $dpf)/exe" && kill -9 $(cat $dpf)

		_info "update kill -9 on pid $(cat $upf)"
                test -f "/proc/$(cat $upf)/exe" && kill $(cat $upf)

		local url="http://source:$ipass@$ihost:$iport/admin/listclients?mount=/$imount"

                _info "starting new darkice and update instance."
                _info "checking connection to $url."

                res=$(curl -s $url)

		_info $res

                if [[ "$res" =~ "<b>Source does not exist</b>" ]];then
                        _info "connection established."

			_notify "generating darkice config."
                        
			gen_dc > $darkice_conf

                        _notify "starting darkice."

                        darkice -c $darkice_conf & echo $! > $dpf

			sleep 10

                        if [ -f "/proc/$(cat $dpf)/exe" ]; then
				_info "darkice started, stream is online, pid - $(cat $dpf)."

        			opts="--update --type $type --port $port --scard $scard"
			        opts="$opts --rec $rec --ihost $ihost --ipass $ipass"
			        opts="$opts --imount $imount --iport $iport --profile $profile"
			        opts="$opts --icao $icao --scor $scor --ecor $ecor"
			        opts="$opts --delay $delay --mindur $mindur --timez $timez"
			        opts="$opts --th $th --vol $vol --srate $srate --brate $brate"
			        opts="$opts --verbose $verbose"

				_info "starting update for icecast with $opts."

				recorder.sh $opts & echo $! > $upf

			else
				_error "darkice failed to start."
			fi
            	fi
    	fi
}

wdog () {

	export TZ=$timez
	_notify "starting watchdog."

	local modf=0

	touch $apf
	touch $spf
	touch $dpf
	touch $lpf
	touch $upf

	if [ -e $stopf ]; then
		_info "stopfile $stopf exists, exiting..."
		exit 1
	fi

	echo 0 > $stopf

	iport=$(echo $ihost | cut -d: -f2)
	ihost=$(echo $ihost | cut -d: -f1)

	while (true); do
	        yy=$(date +%Y)
        	mm=$(date +%m)
	        dd=$(date +%d)
        	hh=$(date +%H)
	        min=$(date +%M)
        	sec=$(date +%S)
	        modm=$(expr $min % $divm)
		today_dir=$scanner_audio/${yy}${mm}${dd}
        	rec_dir=$scanner_audio/${yy}${mm}${dd}/REC
	        log_dir=$scanner_audio/${yy}${mm}${dd}/LOG
        	rec_file=${rec_dir}/${yy}${mm}${dd}${hh}_SCANNER${port}_${min}.mp3
	        log_file=${log_dir}/${yy}${mm}${dd}${hh}_SCANNER${port}_${min}.log

		case "$rec" in
			0) record
			;;
			1) record; livecast
			;;
			2) livecast
			;;
		esac

#		if [ $modm -eq 0 -a $modf -eq 0 ]; then
#			test -f "/proc/$(cat $apf)/exe" && kill -9 $(cat $apf)
#                        test -f "/proc/$(cat $lpf)/exe" && kill $(cat $lpf)
#                        test -f "/proc/$(cat $spf)/exe" && kill $(cat $spf)
#            		modf=1
#        	fi

		sleep 5

        	[ "$modm" != 0 ] && modf=0

		if [ $(cat $stopf) == 1 ]; then
			test -f "/proc/$(cat $apf)/exe" && kill -9 $(cat $apf)
            		test -f "/proc/$(cat $dpf)/exe" && kill -9 $(cat $dpf)
                        test -f "/proc/$(cat $lpf)/exe" && kill $(cat $lpf)
                        test -f "/proc/$(cat $upf)/exe" && kill $(cat $upf)
                        test -f "/proc/$(cat $spf)/exe" && kill $(cat $spf)
                        rm $stopf
            		exit 1
        	fi
	done
}

ctrl_c () {

	if [ "$_split" == 1 ]; then
		
		_debug "SIGTERM caught, making last split."

		th=$(echo $th | sed -e 's/m/-/g')
		scor=$(echo $scor | sed -e 's/m/-/g')
		scor=$(echo $scor | sed -e 's/p/\+/g')
		ecor=$(echo $ecor | sed -e 's/m/-/g')
		ecor=$(echo $ecor | sed -e 's/p/\+/g')
		case "$type" in
			0)
			split0
			;;
			1)
			split1
			;;	
		esac
	fi

	if [ "$_wdog" == 1 ]; then
		_debug "SIGTERM caught, remove $stopf file."
		rm $stopf
	fi	
        	
	exit 1
}

install () {

	_notify "installing software on the box."
	_debug "_udvrls is $_udvrls." 
	_debug "_crnjbs is $_crnjbs." 

	_notify "creating directories."
	mkdir -p $workbin
	mkdir -p /opt/etc

	local sw_list="recorder.sh code.sh usb_port_no.sh clrsym.sed megafon-chat sendcmd.sh"

	for file in $sw_list; do
		if test -f $file; then 
			_debug "copying $file to $workbin/"
			cp -v $file $workbin/
		fi
	done

	if test -f record.conf; then 
		_debug "copying record.conf to /opt/etc/record.conf.example"
		cp -v record.conf /opt/etc/record.conf.example
	fi

	_debug "installing initrec script"
	cp -v initrec /etc/init.d/
	insserv initrec

	if [ "$_udvrls" == 1 ]; then

		_debug "copying udev rules to /etc/udev/rules.d/"
		test -f 99-usb-serial.rules && cp 99-usb-serial.rules /etc/udev/rules.d/
		test -f 99-usb-sound.rules && cp 99-usb-sound.rules /etc/udev/rules.d/
		test -f 99-usb-storage-mgmt.rules && cp 99-usb-storage-mgmt.rules /etc/udev/rules.d/
	fi

	local arch=$(uname -m)

	_info "downloading glgsts utility for arch $arch."
	wget http://www.amelito.com/rec/${arch}/glgsts -O glgsts -q
	wget http://www.amelito.com/rec/${arch}/glgsts.md5 -O glgsts.md5 -q
	local ok=$(md5sum -c glgsts.md5 | cut -d: -f2 | sed -e 's/ //g')
	if [ "$ok" != "OK" ]; then
		_error "md5 check sum failed."
		exit 1
	else
		chmod +x glgsts
		cp -r glgsts $workbin/
		rm glgsts glgsts.md5
	fi

	if [ "$_crnjbs" == 1 ]; then
		_info "installing crontab jobs..."
		test -e cronjobs && crontab cronjobs
	fi
}

extdrive () {

	_info "got new device:usb_device=$usb_device"
	_info "mount_point=$mount_point mount_options=$mount_options" 
	_info "and action $ACTION."

	if test -L $scanner_audio; then
		_error "$scanner_audio not exists, exiting..."
		exit 1
	fi

	_debug "stop recording."

	for file in $(ls /tmp/stop*); do
    		test -e $file && echo 1 > $file
	done

	sleep 10

	mounted_usb_disk=$(mount | grep $mount_point | awk '{print $1}')

	_notify "mounted_usb_disc=$mounted_usb_disk."

	if [ "A$mounted_usb_disk" != "A" -a "$ACTION" == "add" ]; then
		_info "ACTION=$ACTION."
		_info "deleting $scanner_audio symlink."
        	test -L $scanner_audio && rm $scanner_audio
	        _info "umounting $mntpnt."
	        umount -l "$mntpnt"
        	mount -o "$mntopts" "$usbdev" "$mntpnt"
	        mkdir -p "$mntpnt/scanner_audio"
        	ln -s "$mntpnt/scanner_audio" $scanner_audio
	fi

	if [ "$ACTION" == "remove" ]; then
		_info "ACTION=$ACTION."
		_info "deleting $scanner_audio symlink."
        	test -L $scanner_audio && rm $scanner_audio
	        _info "umounting $mntpnt."
        	umount -l "$mntpnt"
        	rmdir "$mntpnt"
	fi

	_debug "starting recording."

	recorder.sh --verbose $verbose --start --config $config
}

mngaddr () {

	_info "checking ip address on eth0."

	if test "X${intf}_address" == "X"; then
		_info "static address is in use."
		exit 0
	fi

	local inet=$(/sbin/ifconfig $intf | grep "inet addr" | wc -l)
	local opstate=$(/bin/cat /sys/class/net/$intf/operstate)

	_debug "inet is $inet."
	_debug "opstate is $opstate."

	case "$opstate" in
	    "down")
	        if [ "$inet" == "1" ]; then
        	    	_notify "link is down, lets stop samba and remove address."
	        	/etc/init.d/samba stop
		       	sleep 3
	        	/bin/ip addr flush $intf
	        fi
        	;;
    	     *)
	        if [ "$inet" == "0" ]; then
            		_notify "link is up, lets get address and start samba."
		        /sbin/udhcpc $intf
		        sleep 3
		        /etc/init.d/samba start
        	fi
        	;;
	esac
}

clean () {

	local clrlist=$(mktemp)
	local pid=/tmp/clean.pid

	test -f $pid || touch $pid

	_notify "start record cleaning."
	_debug "create list file $clrlist."

	if test -f "/proc/$(cat $pid)/exe"; then
		_info "copy of cleaning is already running."
		exit 0
	fi

	echo $$ > $pid

	let onehourleft=2*4*brate*3600*1000/8

	_info "free at least $onehourleft bytes."

	if [ -f $config ]; then
		source $config
	fi

	cd $scanner_audio

	kbytes=$(df . | tail -1 | awk -F" " '{print $4}')
	let bytes=kbytes*1024

	_info "there are $bytes free bytes."

	if [ $bytes -ge $onehourleft ]; then
		_notify "$bytes greater $onehourleft, exiting."
		_debug "remove $clrlist."
		rm $clrlist
		exit 0
	fi

	_info "building list of files ..."

	find . -printf "%A@ %p\n" | sort -n > $clrlist

	_info "reading list until free needed space."

	while [ $bytes -lt $onehourleft ]; do
		file=$(cat $clrlist | head -1 | awk -F" " '{print $2}')
		if [ ! -d $file ]; then
		        rm $file
			_debug "removing file $file."
			kbytes=$(df . | tail -1 | awk -F" " '{print $4}')
			let bytes=kbytes*1024
	  		_debug "$bytes bytes free."
			xpath=${file%/*}
			if [ "X$(ls -1A $xpath)" == "X" ]; then
				_debug "$xpath directory is empty, let's delete it."
				rmdir $xpath
	    		fi
    		else
        		if [ "X$(ls -1A $file)" == "X" ]; then
		        	_info "$file directory is empty, let's delete it."
            			rmdir $file
	    		fi
    		fi
		tail -n+2 $clrlist > ${clrlist}.new
		mv ${clrlist}.new $clrlist
	done
	_debug "remove $clrlist."
	rm $clrlist
	
	kbytes=$(df . | tail -1 | awk -F" " '{print $4}')
	_notify "$kbytes available after cleaning."
}

modem_up () {

	_notify "establishing mobile connection."

	case "$misp" in

		"megafon")
			_info "using Megafon."

			echo "debug
			/dev/modems/$mport
			noauth
			defaultroute
			usepeerdns
			updetach
			persist
			noipdefault
			novjccomp
			nopcomp
			noaccomp
			nodeflate
			novj
			nobsdcomp
			passive
			name gdata
			connect '/usr/sbin/chat -v -f /opt/bin/megafon-chat'" > /etc/ppp/peers/megafon-peer

			sleep 2

			/usr/bin/pon megafon-peer &
			;;
	esac
}

shortopts="h"

#global keys
longopts="help,verbose:,extdrive,usbdev:,mntpnt:,mntopts:,mngaddr,intf:,clean"
longopts="$longopts,modem-up,misp:,mport:"

#install keys
longopts="$longopts,install,with-udvrls,with-crnjbs"

#starter keys
longopts="$longopts,start,stop,restart,config:"

#wdog starter keys
longopts="$longopts,wstart,type:,port:,scard:,rec:,ihost:,ipass:,imount:,iport:"
longopts="$longopts,profile:,icao:,scor:,ecor:,delay:,mindur:,timez:,th:,vol:"

#wdog keys
longopts="$longopts,wdog,srate:,brate:,divm:"

#split keys
longopts="$longopts,split,log-file:,rec-file:,split-dir:,template:"

#update keys
longopts="$longopts,update"

t=$(getopt -o $shortopts --long $longopts -n 'recorder' -- "$@")

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

eval set -- "$t"

while true ; do
        case "$1" in
                -h|--help) usage ; break ;;
		--verbose) verbose=$2; shift 2;;
		--start) ms_action="start"; shift ;;
		--stop) ms_action="stop"; shift ;;
		--install) _install=1; shift ;;
		--with-udvrls) _udvrls=1; shift ;;
		--with-crnjbs) _crnjbs=1; shift ;;
		--config) config=$2; shift 2;;
		--wstart) wstart=1; shift;;
		--type) type=$2; shift 2;;
		--port) port=$2; shift 2;;
		--scard) scard=$2; shift 2;;
		--rec) rec=$2; shift 2;;
		--ihost) ihost=$2; shift 2;;
		--iport) iport=$2; shift 2;;
		--ipass) ipass=$2; shift 2;;
		--imount) imount=$2; shift 2;;
		--profile) profile=$2; shift 2;;
		--scor) scor=$2; shift 2;;
		--ecor) ecor=$2; shift 2;;
		--icao) icao=$2; shift 2;;	
		--delay) delay=$2; shift 2;;
		--mindur) mindur=$2; shift 2;;
		--timez) timez=$2; shift 2;;
		--th) th=$2; shift 2;;
		--vol) vol=$2; shift 2;;
		--wdog) _wdog=1; shift;;
		--srate) srate=$2; shift 2;;
		--brate) brate=$2; shift 2;;
		--divm) divm=$2; shift 2;;
		--split) _split=1; shift ;;
		--log-file) log_file=$2; shift 2;;
		--rec-file) rec_file=$2; shift 2;;
		--split-dir) split_dir=$2; shift 2;;
		--template) _template=$2; shift 2;;
		--update) _update=1; shift;;
		--extdrive) _extdrive=1; shift ;;
		--usbdev) usbdev=$2; shift 2;;
		--mntpnt) mntpnt="$2"; shift 2;;
		--mntopts) mntopts="$2"; shift 2;;
		--mngaddr) _mngaddr=1; shift ;;
		--intf) intf=$2; shift 2;;
		--clean) _clean=1; shift ;;
		--modem-up) _modem_up=1; shift;;
		--misp) misp=$2; shift 2;;
		--mport) mport=$2; shift 2;;
                --) shift ; break ;;
                *) _error "Parsing variables failed!" ; exit 1 ;;
        esac
done


#Function starters

trap ctrl_c SIGTERM

_debug "ms_action is $ms_action"
main_starter

_debug "wstart value is $wstart"
test "$wstart" == 1 && wdog_starter

apf="/tmp/arecord${port}.pid"
spf="/tmp/split${port}.pid"
dpf="/tmp/darkice${port}.pid"
lpf="/tmp/logger${port}.pid"
upf="/tmp/update${port}.pid"

scanner_lck="/tmp/scanner${port}.lck"

aopts="-Dplug:dsnoop${scard} -f S16_LE -r $srate"
aopts="$aopts -c 1 -q -t wav -d $divm --process-id-file $apf"
lopts="-S -m m -q9 -b $brate -"
gopts="-d /dev/scanners/${port} -t $delay -p $scanner_lck"

stopf="/tmp/stop${port}"
darkice_conf="/tmp/darkice${port}.conf"
retf="/tmp/ref_epoch${port}.txt"

elogdir="/tmp/EXT_${port}"

_debug "wdog value is $_wdog"
test "$_wdog" == 1 && wdog

_debug "split value is $_split"
test "$_split" == 1 && split

_debug "update value is $_update"
test "$_update" == 1 && update 

_debug "install value is $_install"
test "$_install" == 1 && install

_debug "external drive is $_extdrive"
test "$_extdrive" == 1 && extdrive

_debug "mngaddr is $_mngaddr"
test "$_mngaddr" == 1 && mngaddr

_debug "clean is $_clean"
test "$_clean" == 1 && clean

_debug "modem_up is $_modem_up"
test "$_modem_up" == 1 && modem_up
