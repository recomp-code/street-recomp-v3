#!/bin/sh
# build_runner.sh: the game for the app (PS2Recomp/out/build-mac-dist): macOS 14 or newer, static FFmpeg from
# build_ffmpeg.sh, so ps2EntryRunner loads only system libraries. Needs the game code (install.sh does it).
set -e
ROOT="${NBA_ROOT:-$HOME/NBAStreetRecomp}"
export PKG_CONFIG_PATH="$ROOT/macdist/ffmpeg/lib/pkgconfig"
export MACOSX_DEPLOYMENT_TARGET=14.0
cmake -S "$ROOT/PS2Recomp" -B "$ROOT/PS2Recomp/out/build-mac-dist" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 -DCMAKE_OSX_ARCHITECTURES=arm64
cmake --build "$ROOT/PS2Recomp/out/build-mac-dist" --target ps2EntryRunner
