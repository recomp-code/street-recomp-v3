#!/bin/sh
# macOS (Apple Silicon) build of the GS host (pcsx2-gsrunner, no Qt, Metal renderer) and its
# gshost folder. Equivalent of build_pcsx2_deps.bat + build_pcsx2.cmd + setup_gshost.ps1.
#   build_pcsx2.sh deps    PCSX2's dependencies for arm64 into $NBA_ROOT/deps-mac (once, ~15 min)
#   build_pcsx2.sh build   configure + build pcsx2-gsrunner into pcsx2/build-mac
#   build_pcsx2.sh gshost  $NBA_ROOT/gshost: runner + resources + Metal shaders + graphics settings
# The Metal shader compiler only ships with full Xcode, so the compiled shaders (.metallib) come
# from the official PCSX2 v2.8.1 macOS release: v2.8.1 is the pinned commit d073d75 and
# patches/pcsx2.patch does not touch the Metal shaders.
set -e
ROOT="${NBA_ROOT:-$HOME/NBAStreetRecomp}"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
PCSX2="$ROOT/pcsx2"
DEPS="$ROOT/deps-mac"
LOGS="$ROOT/logs"
mkdir -p "$LOGS"

METALLIB_URL="https://github.com/PCSX2/pcsx2/releases/download/v2.8.1/pcsx2-v2.8.1-macos-Qt.tar.xz"
METALLIB_SHA256="a2a59e934ee9043e89bb8df4fd649d06fa094aedc98ce000ea9f23f597c3193d"

case "${1:-}" in
    deps)
        mkdir -p "$ROOT/deps-mac-build"
        cd "$ROOT/deps-mac-build"
        PCSX2_MACOS_SCRIPTS="$PCSX2/.github/workflows/scripts/macos" \
            "$REPO/tools/macos/build_pcsx2_deps.sh" "$DEPS" > "$LOGS/mac_pcsx2_deps.log" 2>&1 \
            || { tail -20 "$LOGS/mac_pcsx2_deps.log"; exit 1; }
        echo "Dependencies in $DEPS"
        ;;
    build)
        # FFmpeg: PCSX2's bundled headers (a newer system FFmpeg does not compile with GSCapture).
        cmake -S "$PCSX2" -B "$PCSX2/build-mac" -G Ninja -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_PREFIX_PATH="$DEPS" -DCMAKE_OSX_ARCHITECTURES=arm64 \
            -DENABLE_QT_UI=OFF -DUSE_VULKAN=OFF -DENABLE_TESTS=OFF \
            -DCMAKE_DISABLE_FIND_PACKAGE_FFMPEG=ON > "$LOGS/mac_pcsx2_configure.log" 2>&1 \
            || { tail -30 "$LOGS/mac_pcsx2_configure.log"; echo "configure failed: $LOGS/mac_pcsx2_configure.log"; exit 1; }
        cmake --build "$PCSX2/build-mac" --target pcsx2-gsrunner > "$LOGS/mac_pcsx2_build.log" 2>&1 \
            || { grep -E 'error:' "$LOGS/mac_pcsx2_build.log" | head -20; tail -15 "$LOGS/mac_pcsx2_build.log"; echo "build failed: $LOGS/mac_pcsx2_build.log"; exit 1; }
        echo "OK: $PCSX2/build-mac/pcsx2-gsrunner/pcsx2-gsrunner"
        ;;
    gshost)
        OUT="$ROOT/gshost"
        EXE="$PCSX2/build-mac/pcsx2-gsrunner/pcsx2-gsrunner"
        [ -x "$EXE" ] || { echo "Missing $EXE: run build_pcsx2.sh build"; exit 1; }
        mkdir -p "$OUT"
        cp "$EXE" "$OUT/"
        rm -rf "$OUT/resources"
        cp -R "$PCSX2/bin/resources" "$OUT/resources"
        DL="$ROOT/downloads"
        mkdir -p "$DL"
        TARBALL="$DL/$(basename "$METALLIB_URL")"
        [ -f "$TARBALL" ] || curl -fL -o "$TARBALL" "$METALLIB_URL"
        echo "$METALLIB_SHA256  $TARBALL" | shasum -a 256 -c - > /dev/null \
            || { echo "Checksum mismatch: $TARBALL"; exit 1; }
        tar xf "$TARBALL" -C "$DL" 'PCSX2-v2.8.1.app/Contents/Resources/*.metallib'
        cp "$DL"/PCSX2-v2.8.1.app/Contents/Resources/*.metallib "$OUT/resources/"
        [ -f "$OUT/nba_street.ini" ] || cp "$REPO/gshost/nba_street_macos.ini" "$OUT/nba_street.ini"
        echo "gshost ready in $OUT"
        ;;
    *) sed -n '2,7p' "$0"; exit 1 ;;
esac
