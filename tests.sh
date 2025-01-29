#!/usr/bin/env bash

#Temporal Values
CURRENTYEAR=$(date +'%Y')
CURRENTMONTH=$(date +'%b')
CURRENTDAY=$(date +"%e")
HTMLOUTPUTDIR="."

CURRENTREPORT="$HTMLOUTPUTDIR"/data/"$CURRENTYEAR"-"$CURRENTMONTH"-"$CURRENTDAY".html

# Absolute path to this script. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in. /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")

echo "$SCRIPTPATH/$CURRENTREPORT"