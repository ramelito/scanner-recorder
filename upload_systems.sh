#!/bin/bash

PATH=/opt/bin:$PATH
export PATH

scannerindex=""
config=""
sindex=""
gindex=""
cindex=""
model=""

shortopts="s:"
longopts="config:,sindex:,gindex:,cindex:"

TEMP=`getopt -o $shortopts --long $longopts -n 'upload systems' -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
        case "$1" in
                -s) scannerindex=$2 ; shift 2 ;;
		--config) config=$2; shift 2 ;;
		--sindex) sindex=$2; shift 2 ;;
		--gindex) gindex=$2; shift 2 ;;
		--cindex) cindex=$2; shift 2 ;;
                --) shift ; break ;;
                *) echo "Internal error!" ; exit 1 ;;
        esac
done

[ "X$scannerindex" == "X" ] && exit 1
test -f "$config" || exit 1

scannerlck="/tmp/scanner$scannerindex.lck"

echo 1 > $scannerlck
sleep 0.5

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


while read line; do

	cmd=$(echo $line | cut -d, -f 1)

	if [ "$cmd" == "SIN" ]; then
		echo "DEBUG: SIN command"
		ok=""
		systype=$(echo $line | cut -d, -f 3)
		echo "DEBUG: SIN type - $systype"
		[ "X$systype" == "X" ] && release_scanner
		sindex=$(exec_cmd CSY,$systype,)
		echo "DEBUG: SIN create result - $sindex"
		[[ "$sindex" =~ CSY,[0-9]+ ]] && sindex=$(echo $sindex | cut -d, -f 2) || release_scanner
		state=$(echo $line | cut -d, -f 30)
		syscmd="SIN,$sindex,$(echo $line | cut -d, -f 4,5,6,7,8,9,10,11,12,13 )"
		syscmd="$syscmd,$(echo $line | cut -d, -f 19,20,21,22,23,24 )"
		syscmd="$syscmd,$state"
		syscmd="$syscmd,$(echo $line | cut -d, -f 25,26,27,28)"
#		syscmd=$(echo $syscmd | sed -e 's/,$//g')
		echo "DEBUG: SIN cmd enter - $syscmd"
		ok=$(exec_cmd "$syscmd")
		echo "DEBUG: SIN cmd result - $ok"
		[ "$ok" == "SIN,OK" ] || release_scanner
	fi

	if [ "$cmd" == "TRN" -a "X$sindex" != "X" ]; then
		echo "DEBUG: TRN command"
		ok=""
		trnfields="3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,27,28,29,30,31"
		trncmd="TRN,$sindex,$(echo $line | cut -d, -f $trnfields)"
		echo "DEBUG: TRN cmd enter - $trncmd"
		ok=$(exec_cmd "$trncmd")
		echo "DEBUG: TRN cmd result - $ok"
		[ "$ok" == "TRN,OK" ] || release_scanner
	fi

	if [ "$cmd" == "SIF" -a "X$sindex" != "X" ]; then
		echo "DEBUG: SIF command"
		ok=""
		sifindex=$(exec_cmd AST,$sindex,)
		[[ "$sifindex" =~ AST,[0-9]+ ]] && sifindex=$(echo $sifindex | cut -d, -f 2) || release_scanner
		echo "DEBUG: SIF create result - $sifindex"
		siffields="4,5,6,7,8,9,10,11,12,19,20,21,22,23,24,25,26,27,28"
		sifcmd="SIF,$sifindex,$(echo $line | cut -d, -f $siffields)"
		echo "DEBUG: SIF cmd enter - $sifcmd"
		ok=$(exec_cmd "$sifcmd")
		echo "DEBUG: SIF cmd result - $ok"
		[ "$ok" == "SIF,OK" ] || release_scanner
	fi

	if [ "$cmd" == "GIN" -a "X$sindex" != "X" ]; then
		echo "DEBUG: GIN command"
		ok=""
		grptype=$(echo $line | cut -d, -f 3)
		echo "DEBUG: GIN type - $grptype"
		[ "X$grptype" == "X" ] && release_scanner
		[ "$grptype" == "C" ] && gindex=$(exec_cmd AGC,$sindex)
		[ "$grptype" == "T" ] && gindex=$(exec_cmd AGT,$sindex)
		[[ "$gindex" =~ AG[C,T],[0-9]+ ]] && gindex=$(echo $gindex | cut -d, -f 2) || release_scanner
		echo "DEBUG: GIN create result - $gindex"
		ginfields="4,5,6,13,14,15,16"
		gincmd="GIN,$gindex,$(echo $line | cut -d, -f $ginfields)"
		echo "DEBUG: GIN cmd enter - $gincmd"
		ok=$(exec_cmd "$gincmd")
		echo "DEBUG: GIN cmd result - $ok"
		[ "$ok" == "GIN,OK" ] || release_scanner
	fi

	if [ "$cmd" == "TFQ" -a "X$sifindex" != "X" ]; then
		echo "DEBUG: TFQ command"
		ok=""
		tfqindex=$(exec_cmd ACC,$sifindex)
		[[ "$tfqindex" =~ ACC,[0-9]+ ]] && tfqindex=$(echo $tfqindex | cut -d, -f 2) || release_scanner
		echo "DEBUG: TFQ create result - $tfqindex"
		tfqfields="3,4,5,10,11,12,13"
		tfqcmd="TFQ,$tfqindex,$(echo $line | cut -d, -f $tfqfields)"
		echo "DEBUG: TFQ cmd enter - $tfqcmd"
		ok=$(exec_cmd "$tfqcmd")
		echo "DEBUG: TFQ cmd result - $ok"
		[ "$ok" == "TFQ,OK" ] || release_scanner
	fi

	if [ "$cmd" == "CIN" -a "X$gindex" != "X" ]; then
		echo "DEBUG: CIN command"
		ok=""
		cinindex=$(exec_cmd ACC,$gindex)
		[[ "$cinindex" =~ ACC,[0-9]+ ]] && cinindex=$(echo $cinindex | cut -d, -f 2) || release_scanner
		echo "DEBUG: CIN create result - $cinidex"
		cinfields="3,4,5,6,7,8,9,10,11,12,17,18,19,20,21,22,23"
		cincmd="CIN,$cinindex,$(echo $line | cut -d, -f $cinfields)"
		echo "DEBUG: CIN cmd enter - $cincmd"
		ok=$(exec_cmd "$cincmd")
		echo "DEBUG: CIN cmd result - $ok"
		[ "$ok" == "CIN,OK" ] || release_scanner
	fi

	if [ "$cmd" == "TIN" -a "X$gindex" != "X" ]; then
		echo "DEBUG: TIN command"
		ok=""
		tinindex=$(exec_cmd ACT,$gindex)
		[[ "$tinindex" =~ ACT,[0-9]+ ]] && tinindex=$(echo $tinindex | cut -d, -f 2) || release_scanner
		echo "DEBUG: TIN create result - $tinidex"
		tinfields="3,4,5,6,7,8,13,14,15,16,17,18"
		tincmd="TIN,$tinindex,$(echo $line | cut -d, -f $tinfields)"
		echo "DEBUG: TIN cmd enter - $tincmd"
		ok=$(exec_cmd "$tincmd")
		echo "DEBUG: TIN cmd result - $ok"
		[ "$ok" == "TIN,OK" ] || release_scanner
	fi
done < $config

release_scanner
