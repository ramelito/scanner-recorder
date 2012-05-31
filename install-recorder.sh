#!/bin/bash

installpath=/opt/bin
configpath=/opt/etc

echo "Installing recording software onto you board."

test -d $installpath ||  mkdir -p $installpath
test -d $configpath ||  mkdir -p $configpath

echo -n "Installing scripts... "
test -f MDL &&  cp MDL $installpath || (echo "failed to install MDL"; exit 1)
test -f code.sh &&  cp code.sh $installpath || (echo "failed to install code.sh"; exit 1)
test -f extdrv_handler.sh &&  cp extdrv_handler.sh $installpath || (echo "failed to install extdrv_handler.sh"; exit 1)
test -f simplecn.sh &&  cp simplecn.sh $installpath || (echo "failed to install simplecn.sh"; exit 1)
test -f start3g.sh &&  cp start3g.sh $installpath || (echo "failed to install start3g.sh"; exit 1)
test -f usbreset.sh &&  cp usbreset.sh $installpath || (echo "failed to install usbreset.sh"; exit 1)
test -f recordcleaner.sh &&  cp recordcleaner.sh $installpath || (echo "failed to install recordcleaner.sh"; exit 1)
test -f split_record.sh &&  cp split_record.sh $installpath || (echo "failed to install split_record.sh"; exit 1)
test -f usb_port_no.pm &&  cp usb_port_no.pm $installpath || (echo "failed to install usb_port_no.pm"; exit 1)
test -f rename.sh &&  cp rename.sh $installpath || (echo "failed to install rename.sh"; exit 1)
test -f clrsym.sed &&  cp clrsym.sed $installpath || (echo "failed to install clrsym.sed"; exit 1)
test -f update_icecast.sh &&  cp update_icecast.sh $installpath || (echo "failed to install update_icecast.sh"; exit 1)
test -f watchdog0.sh &&  cp watchdog0.sh $installpath || (echo "failed to install watchdog0.sh"; exit 1)
test -f watchdog_uniden0.sh &&  cp watchdog_uniden0.sh $installpath || (echo "failed to install watchdog_uniden0.sh"; exit 1)
test -f record.conf &&  cp record.conf $configpath || (echo "failed to install record.conf"; exit 1)
test -f record0.sh &&  cp record0.sh $installpath || (echo "failed to install record0.sh"; exit 1)
test -f record.sh &&  cp record.sh /etc/init.d || (echo "failed to install record.sh"; exit 1)
update-rc.d record.sh start 99 S .
echo "ok!"

echo -n "Installing udev rules... "
test -f 99-usb-serial.rules && cp 99-usb-serial.rules /etc/udev/rules.d/
test -f 99-nokia-3g-modem.rules && cp 99-nokia-3g-modem.rules /etc/udev/rules.d/
test -f 99-usb-sound.rules && cp 99-usb-sound.rules /etc/udev/rules.d/
test -f 99-usb-storage-mgmt.rules && 99-usb-storage-mgmt.rules /etc/udev/rules.d/
echo "ok!"

echo -n "Installing readscanner utility... "
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
