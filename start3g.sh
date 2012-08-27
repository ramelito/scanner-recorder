#!/bin/bash

modemportfile="/tmp/modemport"

test -e $modemportfile && mport=$(cat $modemportfile) || mport=125

generate_config () {
	echo "debug

	/dev/modems/$mport

	noauth
	defaultroute
	usepeerdns
	updetach
	persist
	noipdefault
	novjccomp
	nopcomp
	noaccomp
	nodeflate
	novj
	nobsdcomp
	passive
	name gdata

	connect '/usr/sbin/chat -v -f /opt/bin/megafon-chat'" > /etc/ppp/peers/megafon-peer
}

sleep 2

/usr/bin/pon megafon-peer
