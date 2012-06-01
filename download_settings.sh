#!/bin/bash

PATH=/opt/bin:$PATH
export PATH

args=$(getopt s: $*)
if test $? != 0
     then
         echo 'Usage: -s <scanner-index>'
         exit 1
fi
set -- $args
for i
do
  case "$i" in
        -s) shift;scannerindex=$1;shift;;
  esac
done

test -e /dev/scanners/$scannerindex || exit 1

scannerlck="/tmp/scanner$scannerindex.lck"

echo 1 > $scannerlck

exec 3<> /dev/scanners/$scannerindex

exec_cmd () {
    echo -ne "$1\r" >&3
    read  -e -t 1 res <&3
    echo "$res"
}

res=$(exec_cmd PRG)
[ "$res" == "PRG,OK" ] || exit 0

exec_cmd BLT
exec_cmd BSV
exec_cmd COM
exec_cmd KBP
exec_cmd OMS
exec_cmd PRI
exec_cmd AGV
exec_cmd SCT
exec_cmd SCO
exec_cmd SHK
for i in $(seq 0 9); do
	exec_cmd BBS,$i
done
res=""
while [ "$res" != "GLF,-1" ]; do
	res=$(exec_cmd GLF)
	echo $res
done
exec_cmd CLC
for i in $(seq 1 9); do
	exec_cmd SSP,$i
done
exec_cmd SSP,11
exec_cmd SSP,12
exec_cmd SSP,15
exec_cmd CSG
for i in $(seq 0 9); do
	exec_cmd CSP,$i
done
exec_cmd CNT
exec_cmd SCN
exec_cmd P25
for i in $(seq 1 31); do
	exec_cmd DBC,$i
done
exec_cmd BSP

exec_cmd EPG >"/dev/null"
exec_cmd KEY,S,P >"/dev/null"

exec 3>&-

echo 0 > $scannerlck
