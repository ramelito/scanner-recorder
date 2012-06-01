#!/bin/bash

PATH=/opt/bin:$PATH
export PATH

scannerindex=0

args=$(getopt s: $*)
if test $? != 0
     then
         echo 'Usage: -s <scanner-index>'
         exit 1
fi
set -- $args
for i
do
  case "$i" in
        -s) shift;scannerindex=$1;shift;;
  esac
done

test -e /dev/scanners/$scannerindex || exit 1

scannerlck="/tmp/scanner$scannerindex.lck"

echo 1 > $scannerlck
sleep 1

exec 3<> /dev/scanners/$scannerindex

exec_cmd () {
    echo -ne "$1\r" >&3
    read  -e -t 1 res <&3
    echo "$res"
}

res=$(exec_cmd PRG)
[ "$res" == "PRG,OK" ] || exit 0

sihres=$(exec_cmd SIH)

if [[ "$sihres" =~ SIH,[0-9]+ ]]; then
	sinnext=$(echo $sihres | cut -d, -f 2)
else
	echo "Failed to get system head index (error: $sihres)."
	exec_cmd EPG
	exec_cmd KEY,S,P
fi

while [ "$sinnext" != "-1" ]; do
	sinres=$(exec_cmd $(SIN --read --index $sinnext))
	if [ ${#sinres} -gt 7 ]; then

		sifnext="-1"
		ginnext="-1"
		sinres=$(echo "$sinres" | sed -e 's/^SIN,//g')
		sintype=$(echo "$sinres" | cut -d, -f 1)
		echo "SIN,$sinnext,$sinres"

		if [ "$sintype" != "CNV" ]; then
			trnres=$(exec_cmd $(TRN --read --index $sinnext))
			trnres=$(echo "$trnres" | sed -e 's/^TRN,//g')
			echo "TRN,$sinnext,$trnres"
			sifnext=$(echo "$sinres" | cut -d, -f 14)
			gtnnext=$(echo "$trnres" | cut -d, -f 21)
			while [ "$gtnnext" != "-1" ]; do
				gtnres=$(exec_cmd $(GIN --read --index $gtnnext))
				if [ ${#gtnres} -gt 7 ]; then
					gtnres=$(echo $gtnres | sed -e 's/^GIN,//g')
					tinnext=$(echo $gtnres | cut -d, -f 8)
					echo "GIN,$gtnnext,$gtnres"
					while [ "$tinnext" != "-1" ]; do
						tinres=$(exec_cmd $(TIN --read --index $tinnext))
						if [ ${#tinres} -gt 7 ]; then
							tinres=$(echo "$tinres" | sed -e 's/TIN,//g')
							echo "TIN,$tinnext,$tinres"
							tinnext=$(echo "$tinres" | cut -d, -f 8)
						fi
					done
					gtnnext=$(echo $gtnres | cut -d, -f 6 )
				fi
			done
		fi

		if [ "$sintype" == "CNV" ];then
			ginnext=$(echo "$sinres" | cut -d, -f 14 )
		fi

		while [ "$sifnext" != "-1" ]; do
			sifres=$(exec_cmd $(SIF --read --index $sifnext))
			if [ ${#sifres} -gt 7 ]; then
				sifres=$(echo "$sifres" | sed -e 's/^SIF,//g')
				tfqnext=$(echo "$sifres" | cut -d, -f 14)
				echo "SIF,$sifnext,$sifres"

				while [ "$tfqnext" != -1 ]; do
					tfqres=$(exec_cmd $(TFQ --read --index $tfqnext))
					if [ ${#tfqres} -gt 7 ]; then
						tfqres=$(echo $tfqres | sed -e 's/^TFQ,//g')
						echo "TFQ,$tfqnext,$tfqres"
						tfqnext=$(echo "$tfqres" | cut -d, -f 5)
					else
						echo "Failed to get channel information (error: $tfqres)"
						exit 1
					fi
				done
				sifnext=$(echo "$sifres" | cut -d, -f 12)
			fi
		done

		while [ "$ginnext" != "-1" ]; do
			ginres=$(exec_cmd $(GIN --read --index $ginnext))
			if [ ${#ginres} -gt 7 ]; then
				ginres=$(echo $ginres | sed -e 's/^GIN,//g')
				echo "GIN,$ginnext,$ginres"
				cinnext=$(echo "$ginres" | cut -d, -f 8)

				while [ "$cinnext" != -1 ]
				do
					cinres=$(exec_cmd $(CIN --read --index $cinnext))
					if [ ${#cinres} -gt 7 ]
		                        then
						cinres=$(echo $cinres | sed -e 's/^CIN,//g')
						echo "CIN,$cinnext,$cinres"
						cinnext=$(echo "$cinres" | cut -d, -f 12)
					fi
				done
				ginnext=$(echo "$ginres" | cut -d, -f 6)
			fi
		done

		sinnext=$(echo $sinres | cut -d, -f 13)
	fi

done

exec_cmd EPG >"/dev/null"
exec_cmd KEY,S,P >"/dev/null"

exec 3>&-

echo 0 > $scannerlck
