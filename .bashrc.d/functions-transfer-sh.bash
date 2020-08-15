#!/usr/bin/env bash

tri(){
    transfer.sh $1 | sed -e 's@https://transfer.home.vanginderachter.be/\(.*\)@&\nhttps://transfer.office.ginsys.eu/\1\nhttps://transfer.office.ginsys.eu/inline/\1@'
    }
