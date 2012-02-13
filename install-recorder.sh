#!/bin/bash

installpath=/opt/bin

echo "Installing recording software onto you board."

test -d $installpath || sudo mkdir -p $installpath

echo -n "Installing scripts... "
test -f MDL && sudo cp MDL $installpath || (echo "failed not install MDL"; exit 1)
test -f REMOTECONTROL && sudo cp REMOTECONTROL $installpath || (echo "failed not install REMOTECONTROL"; exit 1)
test -f code.sh && sudo cp code.sh $installpath || (echo "failed not install code.sh"; exit 1)
test -f logscanner.sh && sudo cp logscanner.sh $installpath || (echo "failed not install logscanner.sh"; exit 1)
test -f recordcleaner.sh && sudo cp recordcleaner.sh $installpath || (echo "failed not install recordcleaner.sh"; exit 1)
test -f split_record.sh && sudo cp split_record.sh $installpath || (echo "failed not install split_record.sh"; exit 1)
test -f usb_port_no.sh && sudo cp usb_port_no.sh $installpath || (echo "failed not install usb_port_no.sh"; exit 1)
test -f watchdog0.sh && sudo cp watchdog0.sh $installpath || (echo "failed not install watchdog0.sh"; exit 1)
test -f watchdog1.sh && sudo cp watchdog1.sh $installpath || (echo "failed not install watchdog1.sh"; exit 1)
test -f watchdog2.sh && sudo cp watchdog2.sh $installpath || (echo "failed not install watchdog2.sh"; exit 1)
test -f watchdog_uniden0.sh && sudo cp watchdog_uniden0.sh $installpath || (echo "failed not install watchdog_uniden0.sh"; exit 1)
test -f watchdog_uniden1.sh && sudo cp watchdog_uniden1.sh $installpath || (echo "failed not install watchdog_uniden1.sh"; exit 1)
test -f record0.sh && sudo cp record0.sh /etc/init.d || (echo "failed not install record0.sh"; exit 1)
sudo ln -s /etc/init.d/record0.sh /etc/rc2.d/S99record0.sh
sudo ln -s /etc/init.d/record0.sh /etc/rc3.d/S99record0.sh
sudo ln -s /etc/init.d/record0.sh /etc/rc4.d/S99record0.sh
sudo ln -s /etc/init.d/record0.sh /etc/rc5.d/S99record0.sh
echo "ok!"

echo -n "Installing udev rules... "
test -f 99-usb-serial.rules && sudo cp 99-usb-serial.rules /etc/udev/rules.d/
echo "ok!"

echo -n "Installing readscanner utility... "
type -P wget &>/dev/null || (echo "No wget. Install it."; exit 1)
wget http://www.amelito.com/rec/armel/readscanner -O recordscanner -o /dev/null
wget http://www.amelito.com/rec/armel/readscanner.md5 -O readscanner.md5 -o /dev/null
md5sum0=$(cat readscanner.md5)
md5sum1=$(md5sum readscanner | awk -F" " '{print $1}')
[ "$md5sum1" == "$md5sum0" ] || (echo "MD5 check sum failed"; exit 1)
sudo chmod +x readscanner
sudo cp readscanner $installpath
echo "ok!"
