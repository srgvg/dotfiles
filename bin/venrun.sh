#!/bin/bash

source $(dirname $(readlink -f $0))/bin/activate
exec python ${0%.sh}.py

