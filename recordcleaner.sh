#!/bin/bash

scannerhome="/scanner_audio"
test -f /scanner_audio/record.conf && cp /scanner_audio/record.conf /opt/etc/
test -f /opt/etc/record.conf && source /opt/etc/record.conf || ( echo "File record.conf not found in /opt/etc."; exit 1 )
config="/opt/etc/record.conf"
clearlist=/tmp/clearlist

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

kbytes=$(df $scannerhome | tail -1 | awk -F" " '{print $4}')
let bytes=kbytes*1024

echo "Now we have $bytes free bytes."

find $scannerhome -printf "%A@ %p\n" | sort -n > $clearlist

while [ $bytes -lt $onehourleft ]; do
	file=$(cat $clearlist | head -1 | awk -F" " '{print $2}')
	rm $file
	echo "Removing file $file."
	tail -n+2 $clearlist > ${clearlist}.new
	mv ${$clearlist}.new $clearlist
	kbytes=$(df $scannerhome | tail -1 | awk -F" " '{print $4}')
	let bytes=kbytes*1024
	echo "After deleting $file we have $bytes free bytes."
	xpath=${file%/*}
	if [ "$xpath" != "$scannerhome" -a "X$(ls -1A $xpath)" == "X" ]; then
		rmdir $xpath
		echo "$xpath directory is empty, let's delete it."
	fi
done
