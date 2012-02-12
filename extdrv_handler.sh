#!/bin/bash

PATH=/bin:/sbin:/usr/bin:/usr/sbin:$PATH
export PATH

udevlog=/tmp/99udev.log
usb_device=$1
mount_point=$2
mount_options=$3

echo "[`date "+%Y-%m-%d %H:%M:%S"`] Got new device:usb_device=$usb_device mount_point=$mount_point mount_options=$mount_options and action $ACTION." >> $udevlog
echo "[`date "+%Y-%m-%d %H:%M:%S"`] Pausing recording." >> $udevlog

for index in `seq 0 9`; do
	test -e /tmp/scanner${index}.lck && echo 0 > /tmp/scanner${index}.lck
done

sleep 1s

mounted_usb_disk=`mount | grep $mount_point | awk '{print $1}'`

echo "[`date "+%Y-%m-%d %H:%M:%S"`] mounted_usb_disc=$mounted_usb_disk." >> $udevlog

if [ "A$mounted_usb_disk" != "A" -a "$ACTION" == "add" ]; then
	echo "[`date "+%Y-%m-%d %H:%M:%S"`] Umounting $mount_point." >> $udevlog
	test -L /scanner_audio && rm /scanner_audio
	umount -l "$mount_point"
	mount -o "$mount_options" "$usb_device" "$mount_point"
	mkdir -p "$mount_point/scanner_audio"
	ln -s "$mount_point/scanner_audio" /scanner_audio
fi

if [ "A$mounted_usb_disk" == "A" -a "$ACTION" == "add" ]; then
	test -L /scanner_audio && rm /scanner_audio
	echo "[`date "+%Y-%m-%d %H:%M:%S"`] Mounting $usb_device on $mount_point with $mount_options." >> $udevlog
	mkdir -p "$mount_point"
	mount -o "$mount_options" "$usb_device" "$mount_point" >> $udevlog
	mkdir -p "$mount_point/scanner_audio"
	ln -s "$mount_point/scanner_audio" /scanner_audio
fi

if [ "$mounted_usb_disk" == "$usb_device" -a "$ACTION" == "remove" ]; then
	test -L /scanner_audio && rm /scanner_audio
	echo "[`date "+%Y-%m-%d %H:%M:%S"`] Unmounting $mount_point on remove action." >> $udevlog
	umount -l "$mount_point"
	rmdir "$mount_point"
	ln -s /media/mmcblk0p3/scanner_audio /scanner_audio
fi

echo "[`date "+%Y-%m-%d %H:%M:%S"`] Resuming recording." >> $udevlog

for index in `seq 0 9`; do
	test -e /tmp/scanner${index}.lck && echo 1 > /tmp/scanner${index}.lck
done
