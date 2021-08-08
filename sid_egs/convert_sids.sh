#!/usr/bin/env bash
#
# Convert sid files from https://www.hvsc.c64.org/ to c64 prg files
#
# Refer: http://psid64.sourceforge.net/index.php
# Downloaded
# $ configure
# $ make
# $ make install
#
cd $(dirname $0)
for F in *.sid
do
   O=$(basename "$F" .sid).prg
   if [ -f "$O" ]; then
      echo "Skipping: $F -> $O"
   else
      echo "Converting: $F -> $O"
      psid64 -n -v "$F"
   fi
done