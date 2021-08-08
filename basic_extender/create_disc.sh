#!/usr/bin/env bash
echo "Create d64..."
BASENAME="bash"

fn_mkdisc () {
    BASE="$1"
    DISCNAME="${2:-$BASE}"
    PRGNAME="${3:-$BASE}"
    FILENAME="${4:-../kickout/$BASE}"
    ID="${5:-21}"

    DISCNAME="${DISCNAME}.d64"
    FILENAME="${FILENAME}.prg"

    echo "BASE=$BASE ID=$ID DISC=$DISCNAME FILE=$FILENAME PRG=$PRGNAME"
    # Use Vice c1541 uility
    c1541 <<EOF!
format ${BASE},${ID} d64 ${DISCNAME}
attach ${DISCNAME}
write ${FILENAME} ${PRGNAME}
list
quit
EOF!
}

fn_mkdisc bash
