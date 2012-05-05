#!/bin/bash

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/opt/bin:/usr/local/sbin:/usr/local/bin
export PATH

scannerhome="/scanner_audio"
test -f /scanner_audio/record.conf && cp /scanner_audio/record.conf /opt/etc/
test -f /opt/etc/record.conf && source /opt/etc/record.conf || ( echo "File record.conf not found in /opt/etc."; exit 1 )
config="/opt/etc/record.conf"
clearlist=/tmp/clearlist
busy=/tmp/recordcleaner.lck

touch $busy

[ "$(cat $busy)" == "1" ] && exit 0

echo 1 > $busy

s0_profile=$(echo $scanner0 | awk -F";" '{print $8}')

case "$s0_profile" in
            lq)
                bitrate=16
                ;;
            mq)
                bitrate=24
                ;;
            hq)
                bitrate=48
                ;;
            *)
                bitrate=16
                ;;
        esac


let onehourleft=bitrate*3600*1000/8

if [ -f $config ]; then
	source $config
fi

cd $scannerhome

kbytes=$(df . | tail -1 | awk -F" " '{print $4}')
let bytes=kbytes*1024

echo "Now we have $bytes free bytes."

if [ $bytes -ge $onehourleft ]; then
    echo 0 > $busy; 
    exit 0
fi

find . -printf "%A@ %p\n" | sort -n > $clearlist

while [ $bytes -lt $onehourleft ]; do
	file=$(cat $clearlist | head -1 | awk -F" " '{print $2}')
    if [ ! -d $file ]; then
        rm $file
	    echo "Removing file $file."
	    tail -n+2 $clearlist > ${clearlist}.new
	    mv ${clearlist}.new $clearlist
	    kbytes=$(df . | tail -1 | awk -F" " '{print $4}')
	    let bytes=kbytes*1024
	    echo "After deleting $file we have $bytes free bytes."
	    xpath=${file%/*}
	    if [ "X$(ls -1A $xpath)" == "X" ]; then
		    echo "$xpath directory is empty, let's delete it."
		    rmdir $xpath
	    fi
    else
        if [ "X$(ls -1A $file)" == "X" ]; then
            echo "$file directory is empty, let's delete it."
            rmdir $file
	    fi
    fi
    sed -i".bak" '1d' $clearlist
done

echo 0 > $busy
