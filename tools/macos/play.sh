#!/bin/sh
# Starts the recompiled NBA Street V3 on macOS (equivalent of Play.cmd).
# Keyboard: arrows = d-pad, WASD = left stick, Z/X/C/V = Square/Cross/Circle/Triangle,
# Q/E = L1/R1, 1/3 = L2/R2, Return = START, Delete = SELECT, Option+Return / Ctrl+Cmd+F = fullscreen.
# Controller (Xbox / PlayStation / MFi): A = Cross, B = Circle, X = Square, Y = Triangle.
# Graphics menu: F1, Back+Start or hold START 1.5 s. Cmd+Q closes.
# NBA_SERVER=off plays without network; NBA_FULLSCREEN=1 starts fullscreen.
ROOT="${NBA_ROOT:-$HOME/NBAStreetRecomp}"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
export PS2X_GS_LIVE=1
export PS2X_NET=1
export PS2X_NET_SERVER="${NBA_SERVER:-nbas3.xellrecomp.party}"
export PS2X_GSHOST="${PS2X_GSHOST:-$ROOT/gshost/pcsx2-gsrunner}"
if [ -z "$PS2X_GSHOST_ARGS" ]; then
    PS2X_GSHOST_ARGS="-ini nba_street.ini"
    [ "${NBA_FULLSCREEN:-0}" = "1" ] && PS2X_GSHOST_ARGS="$PS2X_GSHOST_ARGS -fullscreen"
    export PS2X_GSHOST_ARGS
fi
# Network configuration on the emulated memory card (once).
if [ ! -f "$ROOT/game/iso/mc0/BWNETCNF/BWNETCNF" ]; then
    mkdir -p "$ROOT/game/iso/mc0/BWNETCNF"
    cp "$REPO/game/mc0_netcnf/BWNETCNF/"* "$ROOT/game/iso/mc0/BWNETCNF/"
fi
mkdir -p "$ROOT/logs"
cd "$ROOT/game/iso" || exit 1
exec "$ROOT/PS2Recomp/out/build-mac/ps2xRuntime/ps2EntryRunner" "$ROOT/game/iso/SLUS_211.26" \
    > "$ROOT/logs/play.log" 2> "$ROOT/logs/play_err.log"
