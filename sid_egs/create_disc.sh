#!/usr/bin/env bash
echo "Create d64..."

# Use Vice c1541 uility
c1541 <<EOF!
format sidplayers,10 d64 sidplayers1.d64
attach sidplayers1.d64
write ../kickout/v1_player.prg v1player
write ../kickout/v2_player.prg v2player
list
format sidplayers,10 d64 sidplayers2.d64
attach sidplayers2.d64
write ../kickout/v3_player.prg v3player
write ../kickout/v4_player.prg v4player
list
quit
EOF!
