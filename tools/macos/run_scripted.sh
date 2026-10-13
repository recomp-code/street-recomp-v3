#!/bin/sh
# macOS version of tools/run_scripted.ps1: automated run WITHOUT touching the desktop. The game
# presses the buttons itself (PS2X_PAD_SCRIPT), the host saves frames from its own render
# (PS2X_SHOT_TIMES), the window opens without taking the focus and physical controllers are ignored.
# Uses gshost/nba_test.ini.
#   run_scripted.sh <seconds> "<pad script>" "<shot times>"   e.g. run_scripted.sh 120 "20:START,25:CROSS" "30,60"
# Logs: logs/runtime.log, logs/runtime_err.log; frames: logs/shots/shot_<n>.png.
# Extra environment (PS2X_FPS_LOG=1, PS2X_NBA_FRAME_LOG=1, ...) is passed through.
ROOT="${NBA_ROOT:-$HOME/NBAStreetRecomp}"
SECONDS_TO_RUN="${1:-120}"
PAD="${2:-}"
SHOTS="${3:-}"
if pgrep -x ps2EntryRunner > /dev/null; then
    echo "A game is running: not testing now."
    exit 2
fi
mkdir -p "$ROOT/logs/shots"
rm -f "$ROOT/logs/shots"/shot_*.png
[ -f "$ROOT/gshost/nba_test.ini" ] || cp "$ROOT/gshost/nba_street.ini" "$ROOT/gshost/nba_test.ini"
export PS2X_GS_LIVE=1 PS2X_NO_GAMEPAD=1 PS2X_HOST_NOACTIVATE=1
export PS2X_GSHOST="$ROOT/gshost/pcsx2-gsrunner" PS2X_GSHOST_ARGS="-ini nba_test.ini"
export PS2X_PAD_SCRIPT="$PAD" PS2X_SHOT_TIMES="$SHOTS" PS2X_SHOT_DIR="$ROOT/logs/shots"
export PS2X_TEST_T0="$(python3 -c 'import time; print(int(time.time() * 1000))')"
cd "$ROOT/game/iso" || exit 1
"$ROOT/PS2Recomp/out/build-mac/ps2xRuntime/ps2EntryRunner" "$ROOT/game/iso/SLUS_211.26" \
    > "$ROOT/logs/runtime.log" 2> "$ROOT/logs/runtime_err.log" &
GAME=$!
waited=0
while [ "$waited" -lt "$SECONDS_TO_RUN" ] && kill -0 "$GAME" 2> /dev/null; do
    sleep 1
    waited=$((waited + 1))
done
kill "$GAME" 2> /dev/null
sleep 2
pkill -x pcsx2-gsrunner 2> /dev/null
ls "$ROOT/logs/shots"
