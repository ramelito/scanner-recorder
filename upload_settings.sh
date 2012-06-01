#!/bin/bash

PATH=/opt/bin:$PATH
export PATH

scannerindex=""

shortopts="s:"
longopts="config:"

TEMP=`getopt -o $shortopts --long $longopts -n 'upload systems' -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
        case "$1" in
                -s) scannerindex=$2 ; shift 2 ;;
		--config) config=$2; shift 2 ;;
                --) shift ; break ;;
                *) echo "Internal error!" ; exit 1 ;;
        esac
done

[ "X$scannerindex" == "X" ] && exit 1
test -f "$config" || exit 1

scannerlck="/tmp/scanner$scannerindex.lck"

echo 1 > $scannerlck
#sleep 30

IFS="~"
echo "DEBUG: Opening port"

exec 3<> /dev/scanners/$scannerindex

exec_cmd () {
    echo -ne "$1\r" >&3
    read  -e -t 1 res <&3
    echo "$res"
}

release_scanner() {
	exec_cmd EPG
	exec_cmd KEY,S,P
	echo 0 > $scannerlck
	IFS=" "
	exit 0
}

echo "DEBUG: Enter programming"

res=$(exec_cmd PRG)
[ "$res" == "PRG,OK" ] || exit 0

echo "DEBUG: Enter cycle"

bbs=0
csp=0
dbc=1

while read line; do

	cmd=$(echo $line | cut -d, -f 1)

	[ "$cmd" == "BLT" ] && exec_cmd "$line" 
	[ "$cmd" == "BSV" ] && exec_cmd "$line" 
	[ "$cmd" == "KBP" ] && exec_cmd "$line" 
	[ "$cmd" == "OMS" ] && exec_cmd "$line"
	[ "$cmd" == "PRI" ] && exec_cmd "$line" 
	[ "$cmd" == "AGV" ] && exec_cmd "$line" 
	[ "$cmd" == "SCO" ] && exec_cmd "$line" 
	[ "$cmd" == "SHK" ] && exec_cmd "$line"
	if [ "$cmd" == "BBS" ]; then
		 exec_cmd "BBS,$bbs,$(echo $line | cut -d, -f 2,3)"
		 let "bbs += 1"
	fi
	if [ "$cmd" == "GLF" ]; then
		freq="$(echo $line | cut -d, -f 2)"
		[ "$freq" == "-1" ] && continue
		exec_cmd "LOF,$freq"
	fi
	[ "$cmd" == "CLC" ] && exec_cmd "$line"
	[ "$cmd" == "SSP" ] && exec_cmd "$line"
	[ "$cmd" == "CSG" ] && exec_cmd "$line"
	if [ "$cmd" == "CSP" ]; then
		 exec_cmd "CSP,$csp,$(echo $line | cut -d, -f 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21)"
		 let "csp += 1"
	fi
	[ "$cmd" == "CNT" ] && exec_cmd "$line"
	[ "$cmd" == "SCN" ] && exec_cmd "$line"
	if [ "$cmd" == "DBC" ]; then
		 exec_cmd "DBC,$dbc,$(echo $line | cut -d, -f 2,3)"
		 let "dbc += 1"
	fi
	[ "$cmd" == "BSP" ] && exec_cmd "$line"
done < $config

release_scanner
