#!/bin/bash

installpath=/opt/bin
configpath=/opt/etc

echo "Installing recording software onto you board."

test -d $installpath ||  mkdir -p $installpath
test -d $configpath ||  mkdir -p $configpath

echo -n "Installing scripts... "
test -f MDL &&  cp MDL $installpath || (echo "failed to install MDL"; exit 1)
test -f REMOTECONTROL &&  cp REMOTECONTROL $installpath || (echo "failed to install REMOTECONTROL"; exit 1)
test -f code.sh &&  cp code.sh $installpath || (echo "failed to install code.sh"; exit 1)
test -f logscanner.sh &&  cp logscanner.sh $installpath || (echo "failed to install logscanner.sh"; exit 1)
test -f recordcleaner.sh &&  cp recordcleaner.sh $installpath || (echo "failed to install recordcleaner.sh"; exit 1)
test -f split_record.sh &&  cp split_record.sh $installpath || (echo "failed to install split_record.sh"; exit 1)
test -f stop_record.sh &&  cp stop_record.sh $installpath || (echo "failed to install stop_record.sh"; exit 1)
test -f usb_port_no.sh &&  cp usb_port_no.sh $installpath || (echo "failed to install usb_port_no.sh"; exit 1)
test -f rename.sh &&  cp rename.sh $installpath || (echo "failed to install rename.sh"; exit 1)
test -f watchdog0.sh &&  cp watchdog0.sh $installpath || (echo "failed to install watchdog0.sh"; exit 1)
test -f watchdog_uniden0.sh &&  cp watchdog_uniden0.sh $installpath || (echo "failed to install watchdog_uniden0.sh"; exit 1)
test -f watchdog_uniden1.sh &&  cp watchdog_uniden1.sh $installpath || (echo "failed to install watchdog_uniden1.sh"; exit 1)
test -f record.conf &&  cp record.conf $configpath || (echo "failed to install record.cfg"; exit 1)
test -f record0.sh &&  cp record0.sh $installpath || (echo "failed to install record.sh"; exit 1)
test -f record.sh &&  cp record.sh /etc/init.d || (echo "failed to install record.sh"; exit 1)
update-rc.d record.sh start 99 S .
echo "ok!"

echo -n "Installing udev rules... "
test -f 99-usb-serial.rules &&  cp 99-usb-serial.rules /etc/udev/rules.d/
echo "ok!"

echo -n "Installing readscanner utility... "
type -P wget &>/dev/null || (echo "No wget. Install it."; exit 1)
wget http://www.amelito.com/rec/armel/readscanner -O readscanner -q
wget http://www.amelito.com/rec/armel/readscanner.md5 -O readscanner.md5 -q
md5sum0=$(cat readscanner.md5)
md5sum1=$(md5sum readscanner | awk -F" " '{print $1}')
[ "$md5sum1" == "$md5sum0" ] || (echo "MD5 check sum failed"; exit 1)
 chmod +x readscanner
 cp readscanner $installpath
echo "ok!"
