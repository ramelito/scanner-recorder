#!/bin/bash

installpath=/opt/bin

echo "Installing recording software onto you board."

test -d $installpath || sudo mkdir -p $installpath

echo -n "Installing MDL... "
test -f MDL && sudo cp MDL $installpath
echo "ok!"

echo -n "Installing REMOTECONTROL... "
test -f REMOTECONTROL && sudo cp REMOTECONTROL $installpath
echo "ok!"

echo -n "Installing code.sh... "
test -f code.sh && sudo cp code.sh $installpath
echo "ok!"

echo -n "Installing logscanner.sh... "
test -f logscanner.sh && sudo cp logscanner.sh $installpath
echo "ok!"

echo -n "Installing recordcleaner.sh... "
test -f recordcleaner.sh && sudo cp recordcleaner.sh $installpath
echo "ok!"

echo -n "Installing split_record.sh... "
test -f split_record.sh && sudo cp split_record.sh $installpath
echo "ok!"

echo -n "Installing usb_port_no.sh... "
test -f usb_port_no.sh && sudo cp usb_port_no.sh $installpath
echo "ok!"

echo -n "Installing watchdog0.sh... "
test -f watchdog0.sh && sudo cp watchdog0.sh $installpath
echo "ok!"

echo -n "Installing watchdog1.sh... "
test -f watchdog1.sh && sudo cp watchdog1.sh $installpath
echo "ok!"

echo -n "Installing watchdog2.sh... "
test -f watchdog2.sh && sudo cp watchdog2.sh $installpath
echo "ok!"

echo -n "Installing watchdog_uniden0.sh... "
test -f watchdog_uniden0.sh && sudo cp watchdog_uniden0.sh $installpath
echo "ok!"

echo -n "Installing watchdog_uniden1.sh... "
test -f watchdog_uniden1.sh && sudo cp watchdog_uniden1.sh $installpath
echo "ok!"
