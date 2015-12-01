#!/bin/bash

PWD=`dirname $0`
USBRESET="usbreset"

ID=$1
MATCHES=$(lsusb | sed -n 's@Bus \([0-9]*\) Device \([0-9]*\): ID '$ID'.*@/dev/bus/usb/\1/\2@p')

if [ -z ${MATCHES} ]; then
 sudo $USBRESET $ID
else
 sudo $USBRESET $MATCHES
fi

