#!/bin/sh
# macOS (Apple Silicon) build of the port. Equivalent of build_recomp.cmd / build_runner*.cmd.
#   build.sh configure   CMake + Ninja into PS2Recomp/out/build-mac (Release)
#   build.sh recomp      the recompiler (ps2_recomp), needed by generate_game.py
#   build.sh lib         runtime + IOP libraries only (quick check without the game code)
#   build.sh game        the game (ps2EntryRunner); needs generate_game.py first
# Needs: Xcode Command Line Tools, CMake and Ninja (brew install cmake ninja).
# NBA_ROOT overrides the base folder (default ~/NBAStreetRecomp). Logs go to $NBA_ROOT/logs.
set -e
ROOT="${NBA_ROOT:-$HOME/NBAStreetRecomp}"
SRC="$ROOT/PS2Recomp"
BUILD="$SRC/out/build-mac"
LOGS="$ROOT/logs"
mkdir -p "$LOGS"

configure() {
    cmake -S "$SRC" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release > "$LOGS/mac_configure.log" 2>&1 \
        || { echo "CMake configure failed: $LOGS/mac_configure.log"; exit 1; }
}

build() {
    log="$LOGS/mac_build_$1.log"
    shift
    [ -f "$BUILD/build.ninja" ] || configure
    if cmake --build "$BUILD" --target "$@" > "$log" 2>&1; then
        echo "OK ($*)"
    else
        grep -E 'error:' "$log" | head -20
        echo "Build failed: $log"
        exit 1
    fi
}

case "${1:-}" in
    configure) configure; echo "Configured: $BUILD" ;;
    recomp) build recomp ps2_recomp ;;
    lib) build lib ps2_runtime ps2_iop ;;
    game)
        [ -f "$SRC/ps2xRuntime/src/runner/nba_street_v3_overrides.cpp" ] \
            || { echo "No game code: run tools/macos/generate_game.py first"; exit 1; }
        # The runner's source list is a glob: reconfigure so new generated files are picked up.
        configure
        build game ps2EntryRunner
        echo "Game: $BUILD/ps2xRuntime/ps2EntryRunner"
        ;;
    *) sed -n '2,7p' "$0"; exit 1 ;;
esac
