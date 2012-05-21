#!/bin/bash

pl2303lst="/tmp/pl2303.lst"
scanner_index=$1

[ "X$1" == "X" ] && exit 1

lsusb | grep 2303 | awk -F" " '{print "/dev/bus/usb/"$2"/"$4}' | tr -d '[:]' > $pl2303lst

while read usbpath; do
    index=$(udevadm info --attribute-walk --name $usbpath | grep "KERNEL==" | tr -d '[:alpha:][:punct:][:space:]')
    if [ "$scanner_index" == "$index" ]; then
        model=$(/opt/bin/MDL -s$scanner_index)
        [ "X$model" == "X" ] && /opt/bin/usbreset $usbpath
    fi
done < $pl2303lst
