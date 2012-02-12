#!/bin/bash

scannerhome="/scanner_audio"
config="/media/mmcblk0p3/record.conf"
clearlist=/tmp/clearlist

bitrate=48
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
