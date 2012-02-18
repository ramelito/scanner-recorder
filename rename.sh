#!/bin/bash

workdir=$1
list=$(mktemp)

ls $workdir | grep mp3 > $list

while read line; do
    filename=${line%.*}
    datepart=$(echo $filename | awk -F"_" '{print $1}')
    shiftpart=$(echo $filename | awk -F "_" '{print $2}')
    shiftmins=${shiftpart:0:2}
    shiftsecs=${shiftpart:2:2}
    datepartyy=${datepart:0:4}
    datepartmm=${datepart:4:2}
    datepartdd=${datepart:6:2}
    dateparthh=${datepart:8:2}
    datepartmins=${datepart:10:2}
    datepartsecs=${datepart:12:2}
    datepartepoch=$(date -d "${datepartyy}-${datepartmm}-${datepartdd} ${dateparthh}:${datepartmins}:${datepartsecs}" +%s)
    [ ${shiftsecs:0:1} == 0 ] && shiftsecs=${shiftsecs:1:1}
    [ ${shiftmins:0:1} == 0 ] && shiftmins=${shiftmins:1:1}
    let shiftsecs=${shiftmins}*60+$shiftsecs
    let datepartepoch=$datepartepoch+$shiftsecs
    echo "Moving file $filename to $(date -d "@$datepartepoch" +%Y%m%d%H%M%S)"
    mv ${workdir}/${line} ${workdir}/$(date -d "@$datepartepoch" +%Y%m%d%H%M%S).mp3
done < $list

rm $list
