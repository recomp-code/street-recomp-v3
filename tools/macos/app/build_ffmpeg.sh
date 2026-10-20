#!/bin/sh
# build_ffmpeg.sh: minimal static FFmpeg 7.1 (LGPL) for the app's runner: the game's MPEG-2 videos only.
# Homebrew's FFmpeg only loads on the macOS it was built for and pulls ~25 dylibs. -> $NBA_ROOT/macdist/ffmpeg
set -e
ROOT="${NBA_ROOT:-$HOME/NBAStreetRecomp}"
OUT="$ROOT/macdist"
VER=7.1.2
mkdir -p "$OUT" && cd "$OUT"
[ -f ffmpeg-$VER.tar.xz ] || curl -fLO https://ffmpeg.org/releases/ffmpeg-$VER.tar.xz
rm -rf ffmpeg-src && mkdir ffmpeg-src && tar xf ffmpeg-$VER.tar.xz -C ffmpeg-src --strip-components=1
cd ffmpeg-src
export MACOSX_DEPLOYMENT_TARGET=14.0
./configure --prefix="$OUT/ffmpeg" --enable-static --disable-shared --disable-programs --disable-doc --disable-network \
    --disable-autodetect --disable-everything --enable-pic \
    --enable-decoder=mpeg1video,mpeg2video --enable-parser=mpegvideo --enable-demuxer=mpegps,mpegvideo \
    --enable-protocol=file --enable-swscale --enable-swresample \
    --extra-cflags="-mmacosx-version-min=14.0" --extra-ldflags="-mmacosx-version-min=14.0"
make -j6
make install
