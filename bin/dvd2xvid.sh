#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

#http://straps4linux.blogspot.com/2006/11/script-dvd2xvidsh.html

. utility.sh

function printUsage {
 echo "Usage: $0 [-d dvd-device] [-t title-number] [-l language] [-o output-file-name-without-ext] [-c crop-value] [-b bitrate] [-a audio-codec] [-e audio-encoding-options] [-v volume-gain-for-lavc] [-p additional-parameters]"
 echo "-t can be passed more times to rip more titles, es -t 1 -t 2 -t 3 ..."
 echo "If not passed, required values will be prompted to the user"
}

while getopts ":d:t:l:o:c:b:v:a:e:p:" param; do
 case $param in
  d) DEVICE=$OPTARG ;;
  t) TITLE="$TITLE $OPTARG" ;;
  l) LANG=$OPTARG ;;
  o) OUTF=$OPTARG ;;
  c) CROP=$OPTARG ;;
  b) BITRATE=$OPTARG ;;
  a) OAC=$OPTARG ;;
  e) OACOPTS=$OPTARG ;;
  v) VGAIN=$OPTARG ;;
  p) PARAMS=$OPTARG ;;
  *) printUsage; exit 1;;
 esac
done

getAnswerIfNull DEVICE "DVD Device (-dvd-device)" "/dev/dvd"
lsdvd $DEVICE || exit 1

getAnswerIfNull TITLE "Title Number, specify a single title or a space separated list of titles (dvd://X)" "1"
getAnswerIfNull LANG "Language (-alang)" "it"
getAnswerIfNull OUTF "Output File Name Without Extension" "movie"

if [ ! "$CROP" ]; then
 read -p "Press Enter, Wait for 10-20 seconds, press CTRL+C and copy the crop value, than paste in the next step" RV;
 mplayer -dvd-device $DEVICE -vf cropdetect dvd://$TITLE || exit 1
 getAnswer "Enter the crop value (XX:XX:XX:XX)" ""; CROP=$RV
fi

if [ ! "$LANG" ]; then LANG="it"; echo "LANG not specified, setting to $LANG"; fi
if [ ! "$BITRATE" ]; then BITRATE="1000"; echo "BITRATE not specified, setting to $BITRATE"; fi
if [ ! "$VGAIN" ]; then VGAIN="0"; echo "VGAIN not specified, setting to $VGAIN"; fi
if [ ! "$OAC" ]; then OAC="mp3lame"; echo "OAC not specified, setting to $OAC"; fi
if [ ! "$OACOPTS" ]; then OACOPTS="-lameopts abr:br=128:vol=$VGAIN"; echo "OACOPTS not specified, setting to $OACOPTS"; fi

#sws 2 = bicubic scaling, slower but better
PARAMS="$PARAMS -sws 2 -ffourcc XVID"

for T in $TITLE; do
 echo ""
 echo "-----------------------------------------" 
 echo EXECUTING: nice -n 3 mencoder $PARAMS -oac $OAC $OACOPTS -ovc xvid -xvidencopts bitrate=$BITRATE:autoaspect -vf crop=$CROP -alang $LANG -dvd-device $DEVICE dvd://$T -o "$OUTF""_""$T"".avi"
 echo ""
 nice -n 3 mencoder $PARAMS -oac $OAC $OACOPTS -ovc xvid -xvidencopts bitrate=$BITRATE:autoaspect -vf crop=$CROP -alang $LANG -dvd-device $DEVICE dvd://$T -o "$OUTF""_""$T"".avi"
done
