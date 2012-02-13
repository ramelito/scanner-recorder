#!/bin/bash

scannerindex=$1

test -f /tmp/arecord${scannerindex} && kill -9 $(cat /tmp/arecord${scannerindex}.pid)
test -f /tmp/logger${scannerindex} && kill -9 $(cat /tmp/logger${scannerindex}.pid)
test -f /tmp/split${scannerindex} && kill -9 $(cat /tmp/split${scannerindex}.pid)
test -f /tmp/darkice${scannerindex} && kill -9 $(cat /tmp/darkice${scannerindex}.pid)
