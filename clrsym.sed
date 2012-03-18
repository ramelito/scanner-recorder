#!/bin/sed -f
s/\xb5//g
s/\xb6//g
s/UID\://g
s/LNK//g
s/P25//g
s/DAT//g
s/  */ /g
s/,//g
/^$/d
