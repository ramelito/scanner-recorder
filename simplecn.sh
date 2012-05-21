#!/bin/bash

interface=eth0

inet=$(/sbin/ifconfig $interface | grep "inet addr" | wc -l)
operstate=$(/bin/cat /sys/class/net/$interface/operstate)

case "$operstate" in
    down) 
        if [ "$inet" == "1" ]; then
            echo "Link is down, lets stop samba and remove address."
            /etc/init.d/samba stop
            sleep 3
            /bin/ip addr flush $interface
        fi
        ;;
    *)
        if [ "$inet" == "0" ]; then
            echo "Link is up, lets get address and start samba."
            /sbin/udhcpc $interface
            sleep 3
            /etc/init.d/samba start
        fi
        ;;
esac

