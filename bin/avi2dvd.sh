#!/bin/bash

output=$1
####################
# avi     Function #
####################

function avi {
    mencoder -oac lavc -ovc lavc -of mpeg -mpegopts format=xvcd -vf scale=352:196,expand=352:240,harddup -srate 44100 -af lavcresample=44100 -lavcopts     vcodec=mpeg1video:keyint=18:vrc_buf_size=327:vrc_minrate=1152:vbitrate=1152:vrc_maxrate=1152:acodec=mp2:abitrate=224 -ofps 30000/1001 -o output.mpg "$output"
}


####################
# vcd     Function #
####################

function vcd {
    ffmpeg -i output.mpg -target ntsc-dvd -aspect 4:3 output2.mpg
}

####################
# rm1mpg Function #
####################

function rm1mpg {
    rm output.mpg
}

####################
# convert Function #
####################

function convert {
    dvdauthor -o dvd -t output2.mpg
}

####################
# rmpg     Function #
####################

function rmpg {
    rm output2.mpg
}

###################
# Rename Function #
###################

function finalize {

dvdauthor -o dvd -T

}

#####################
# ISO Function      #
#####################

function image {

mkisofs -dvd-video -o dvd.iso dvd/

}

#####################
# rm2 Function      #
#####################

function rm2 {

rm -rf dvd/

}


###############
# Script      #
###############

avi ;
vcd ;
rm1mpg ;
convert ;
rmpg ;
finalize ;
image ;
rm2 ;

exit

 