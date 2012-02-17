#!/bin/bash

installpath=/opt/bin
configpath=/opt/etc

echo "Installing recording software onto you board."

test -d $installpath || sudo mkdir -p $installpath
test -d $configpath || sudo mkdir -p $configpath

echo -n "Installing scripts... "
test -f MDL && sudo cp MDL $installpath || (echo "failed to install MDL"; exit 1)
test -f REMOTECONTROL && sudo cp REMOTECONTROL $installpath || (echo "failed to install REMOTECONTROL"; exit 1)
test -f code.sh && sudo cp code.sh $installpath || (echo "failed to install code.sh"; exit 1)
test -f logscanner.sh && sudo cp logscanner.sh $installpath || (echo "failed to install logscanner.sh"; exit 1)
test -f recordcleaner.sh && sudo cp recordcleaner.sh $installpath || (echo "failed to install recordcleaner.sh"; exit 1)
test -f split_record.sh && sudo cp split_record.sh $installpath || (echo "failed to install split_record.sh"; exit 1)
test -f stop_record.sh && sudo cp stop_record.sh $installpath || (echo "failed to install stop_record.sh"; exit 1)
test -f usb_port_no.sh && sudo cp usb_port_no.sh $installpath || (echo "failed to install usb_port_no.sh"; exit 1)
test -f watchdog0.sh && sudo cp watchdog0.sh $installpath || (echo "failed to install watchdog0.sh"; exit 1)
test -f watchdog1.sh && sudo cp watchdog1.sh $installpath || (echo "failed to install watchdog1.sh"; exit 1)
test -f watchdog2.sh && sudo cp watchdog2.sh $installpath || (echo "failed to install watchdog2.sh"; exit 1)
test -f watchdog_uniden0.sh && sudo cp watchdog_uniden0.sh $installpath || (echo "failed to install watchdog_uniden0.sh"; exit 1)
test -f watchdog_uniden1.sh && sudo cp watchdog_uniden1.sh $installpath || (echo "failed to install watchdog_uniden1.sh"; exit 1)
test -f record.conf && sudo cp record.conf $configpath || (echo "failed to install record.cfg"; exit 1)
test -f record0.sh && sudo cp record0.sh $installpath || (echo "failed to install record.sh"; exit 1)
test -f record.sh && sudo cp record.sh /etc/init.d || (echo "failed to install record.sh"; exit 1)
test -L /etc/rc2.d/S99record.sh || sudo ln -s etc/init.d/record.sh /etc/rc2.d/S99record.sh
test -L /etc/rc3.d/S99record.sh || sudo ln -s /etc/init.d/record.sh /etc/rc3.d/S99record.sh
test -L /etc/rc4.d/S99record.sh || sudo ln -s /etc/init.d/record.sh /etc/rc4.d/S99record.sh
test -L /etc/rc5.d/S99record.sh || sudo ln -s /etc/init.d/record.sh /etc/rc5.d/S99record.sh
echo "ok!"

echo -n "Installing udev rules... "
test -f 99-usb-serial.rules && sudo cp 99-usb-serial.rules /etc/udev/rules.d/
echo "ok!"

echo -n "Installing readscanner utility... "
type -P wget &>/dev/null || (echo "No wget. Install it."; exit 1)
wget http://www.amelito.com/rec/armel/readscanner -O readscanner -q
wget http://www.amelito.com/rec/armel/readscanner.md5 -O readscanner.md5 -q
md5sum0=$(cat readscanner.md5)
md5sum1=$(md5sum readscanner | awk -F" " '{print $1}')
[ "$md5sum1" == "$md5sum0" ] || (echo "MD5 check sum failed"; exit 1)
sudo chmod +x readscanner
sudo cp readscanner $installpath
echo "ok!"
