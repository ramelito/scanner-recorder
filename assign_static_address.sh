#!/bin/bash

. /opt/etc/record.conf

if [ "X$eth0_address" != "X" ]; then
	test "X$eth0_netmask" == "X" && exit 1
	test "X$eth0_gw" == "X" && exit 1
	/sbin/ifconfig eth0 $eth0_address netmask $eth0_netmask 
	/sbin/route add default gw $eth0_gw
fi
