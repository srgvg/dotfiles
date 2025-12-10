#!/bin/sh
ICAROOT=/opt/Citrix/ICAClient 
export ICAROOT
LD_LIBRARY_PATH=/opt/Citrix/ICAClient/lib
export LD_LIBRARY_PATH
$ICAROOT/wfica -file $1
