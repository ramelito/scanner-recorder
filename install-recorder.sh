#!/bin/bash

installpath=/opt/bin
configpath=/scanner_audio

echo "Installing recording software onto you board."

test -d $installpath ||  mkdir -p $installpath
test -d $configpath ||  mkdir -p $configpath

echo -n "Installing scripts... "
test -f assign_static_address.sh && cp assign_static_address.sh $installpath
test -f code.sh &&  cp code.sh $installpath 
test -f extdrv_handler.sh &&  cp extdrv_handler.sh $installpath 
test -f simplecn.sh &&  cp simplecn.sh $installpath 
test -f usbreset.sh &&  cp usbreset.sh $installpath
test -f recordcleaner.sh &&  cp recordcleaner.sh $installpath
test -f split_record.sh &&  cp split_record.sh $installpath
test -f usb_port_no.pm &&  cp usb_port_no.pm $installpath
test -f rename.sh &&  cp rename.sh $installpath
test -f clrsym.sed &&  cp clrsym.sed $installpath
test -f update_icecast.sh &&  cp update_icecast.sh $installpath
test -f watchdog0.sh &&  cp watchdog0.sh $installpath
test -f watchdog_uniden0.sh &&  cp watchdog_uniden0.sh $installpath
test -f record.conf &&  cp record.conf $configpath
test -f record0.sh &&  cp record0.sh $installpath
test -f start3g.sh &&  cp start3g.sh $installpath
test -f megafon-chat &&  cp megafon-chat $installpath
test -f megafon-peer &&  cp megafon-peer /etc/ppp/peers/ 
test -f 01defaultroute &&  cp 01defaultroute /etc/ppp/ip-up.d/ 
test -f record.sh &&  cp record.sh /etc/init.d
test -f networking &&  cp networking /etc/init.d
test -f udev &&  cp udev /etc/init.d
test -h /etc/rcS.d/S15udev.sh || update-rc.d udev start 15 S .
test -h /etc/rcS.d/S99record.sh || update-rc.d record.sh start 99 S .
echo "ok!"

echo -n "Installing udev rules... "
test -f 99-usb-serial.rules && cp 99-usb-serial.rules /etc/udev/rules.d/
test -f 99-usb-sound.rules && cp 99-usb-sound.rules /etc/udev/rules.d/
test -f 99-usb-storage-mgmt.rules && cp 99-usb-storage-mgmt.rules /etc/udev/rules.d/
echo "ok!"

echo -n "Installing glgsts utility... "
type -P wget &>/dev/null || (echo "No wget. Install it."; exit 1)
arch=$(uname -m)
wget http://www.amelito.com/rec/${arch}/glgsts -O /tmp/glgsts -q
wget http://www.amelito.com/rec/${arch}/glgsts.md5 -O /tmp/glgsts.md5 -q
md5sum0=$(cat /tmp/glgsts.md5)
md5sum1=$(md5sum /tmp/glgsts | awk -F" " '{print $1}')
[ "$md5sum1" == "$md5sum0" ] || (echo "MD5 check sum failed"; exit 1)
 chmod +x /tmp/glgsts
 cp /tmp/glgsts $installpath
 rm /tmp/glgsts /tmp/glgsts.md5
echo "ok!"
