#!/bin/bash
/bin/mknod /dev/ppp c 108 0
/usr/sbin/pppd file /etc/ppp/peers/megafon > /tmp/megafon.log &
