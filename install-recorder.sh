#!/bin/bash

installpath=/opt/bin
configpath=/scanner_audio

corefiles[0]='assign_static_address.sh'
corefiles[1]='code.sh'
corefiles[2]='extdrv_handler.sh'
corefiles[3]='simplecn.sh'
corefiles[4]='usbreset.sh'
corefiles[5]='recordcleaner.sh'
corefiles[6]='split_record.sh'
corefiles[7]='usb_port_no.pm'
corefiles[8]='split_rename.sh'
corefiles[9]='clrsym.sed'
corefiles[10]='update_icecast.sh'
corefiles[11]='watchdog0.sh'
corefiles[12]='watchdog_uniden0.sh'
corefiles[13]='record0.sh'
corefiles[14]='start3g.sh'
corefiles[15]='megafon-chat'

echo "Installing recording software onto you board."

test -d $installpath ||  mkdir -p $installpath
test -d $configpath ||  mkdir -p $configpath

echo -n "Installing scripts... "

for corefile in "${corefiles[@]}"; do
	test -f $corefile && cp $corefile $installpath
done

test -f record.conf &&  cp record.conf $configpath/record.conf.example
test -f 01defaultroute &&  cp 01defaultroute /etc/ppp/ip-up.d/ 
test -f record.sh &&  cp record.sh /etc/init.d/
test -f networking &&  cp networking /etc/init.d/
test -f udev &&  cp udev /etc/init.d/
test -f smb.conf &&  cp smb.conf /etc/samba/
test -h /etc/rcS.d/S15udev.sh || /usr/sbin/update-rc.d udev start 15 S .
test -h /etc/rcS.d/S99record.sh || /usr/sbin/update-rc.d record.sh start 99 S .
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

echo -n "Setting samba password..."
echo -ne "recorder\nrecorder\n" | smbpasswd -a -s recorder
echo "ok!"

echo -n "Installing crontab jobs..."
test -e cronjobs && crontab cronjobs
echo "ok!"
