#!/bin/bash

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/opt/bin:/usr/local/sbin:/usr/local/bin
export PATH

scannerhome="/scanner_audio"
test -f /scanner_audio/record.conf && cp /scanner_audio/record.conf /opt/etc/
test -f /opt/etc/record.conf && source /opt/etc/record.conf || ( echo "File record.conf not found in /opt/etc."; exit 1 )
config="/opt/etc/record.conf"
clearlist=/tmp/clearlist
pid=/tmp/recordcleaner.pid

test -f $pid || touch $pid

echo "Checking recordcleaner is working..."

test -f "/proc/$(cat $pid)/exe" && exit 0

echo "Recordcleaner not running. Let's run it!"

echo $$ > $pid

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

echo "We should get at least $onehourleft bytes."

if [ -f $config ]; then
	source $config
fi

echo "Entering $scannerhome ... "

cd $scannerhome

kbytes=$(df . | tail -1 | awk -F" " '{print $4}')
let bytes=kbytes*1024

echo "Now we have $bytes free bytes."

echo "Check if $bytes greater or equal $onehourleft bytes ... "

[ $bytes -ge $onehourleft ] && exit 0

echo "Building clearlist of files ..."

find . -printf "%A@ %p\n" | sort -n > $clearlist

echo "Reading clearlist until free needed space."

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
    echo "Sedding clearlist to remove already checked $file ..."
    lines=$(cat $clearlist | wc -l)
    let "lines--"
    tail -n$lines $clearlist > $clearlist.1
    mv $clearlist.1 $clearlist
done
