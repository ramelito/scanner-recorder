#!/bin/bash

PATH=/opt/bin:$PATH
export PATH

scannerindex=0

args=$(getopt s:c: $*)
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
        -c) shift;cmd=$1;shift;;
  esac
done

test -e /dev/scanners/$scannerindex || exit 1
[ "X" == "X$cmd" ] && exit 1

scannerlck="/tmp/scanner$scannerindex.lck"

echo 1 > $scannerlck
sleep 0.5

exec 3<> /dev/scanners/$scannerindex

exec_cmd () {
    echo -ne "$1\r" >&3
    read  -e -t 1 res <&3
    echo "$res"
}

exec_cmd $cmd

exec 3>&-
echo 0 > $scannerlck
