#!/bin/sh
# One-step macOS (Apple Silicon) install: tools check, PS2Recomp + PCSX2 sources with the
# patches, your ISO, the GS host and the game. Equivalent of tools/install.ps1.
#   tools/macos/install.sh /path/to/NBAStreetV3.iso
# Run it again after updating the repository: finished steps are skipped or redone quickly.
# Needs: Xcode Command Line Tools (xcode-select --install) and Homebrew (cmake, ninja).
# Everything goes into $NBA_ROOT (default ~/NBAStreetRecomp); this repository must be inside it.
set -e
ROOT="${NBA_ROOT:-$HOME/NBAStreetRecomp}"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
ISO="$1"
step() { printf '\n==> %s\n' "$1"; }

[ "$(uname -m)" = "arm64" ] || { echo "This port needs an Apple Silicon Mac (arm64)."; exit 1; }
if [ -z "$ISO" ] && [ ! -f "$ROOT/game/NBAStreetV3.iso" ]; then
    echo "Usage: $0 /path/to/NBAStreetV3.iso   (NBA Street V3, USA, SLUS-21126)"
    exit 1
fi

step "Tools"
xcode-select -p > /dev/null 2>&1 || { echo "Install the Xcode Command Line Tools first: xcode-select --install"; exit 1; }
for tool in cmake ninja; do
    if ! command -v "$tool" > /dev/null; then
        command -v brew > /dev/null || { echo "Missing $tool. Install Homebrew (https://brew.sh) or $tool."; exit 1; }
        brew install "$tool"
    fi
done
command -v python3 > /dev/null || { echo "Missing python3 (comes with the Command Line Tools)."; exit 1; }

step "Sources (PS2Recomp 2c5fbb9, PCSX2 d073d75) + patches"
mkdir -p "$ROOT/logs" "$ROOT/game/iso"
fetch() { # name url commit patch
    dir="$ROOT/$1"
    [ -d "$dir/.git" ] || git clone "$2" "$dir"
    git -C "$dir" checkout --quiet "$3"
    if git -C "$dir" apply --check --whitespace=nowarn "$REPO/patches/$4" 2> /dev/null; then
        git -C "$dir" apply --whitespace=nowarn "$REPO/patches/$4"
        echo "  $4 applied"
    elif git -C "$dir" apply --check --reverse --whitespace=nowarn "$REPO/patches/$4" 2> /dev/null; then
        echo "  $4 already applied"
    else
        echo "  $4 does not apply on $1 $3: reset that folder (git -C \"$dir\" checkout -- . && git -C \"$dir\" clean -fd) and run again"
        exit 1
    fi
}
fetch PS2Recomp https://github.com/ran-j/PS2Recomp.git 2c5fbb9 ps2recomp.patch
fetch pcsx2 https://github.com/PCSX2/pcsx2.git d073d75 pcsx2.patch

step "Your game"
if [ -n "$ISO" ]; then
    [ -f "$ISO" ] || { echo "Not found: $ISO"; exit 1; }
    # A hard link when on the same disk (no extra space), a copy otherwise.
    ln -f "$ISO" "$ROOT/game/NBAStreetV3.iso" 2> /dev/null || cp "$ISO" "$ROOT/game/NBAStreetV3.iso"
fi
if [ ! -f "$ROOT/game/iso/SLUS_211.26" ]; then
    MOUNT="$(mktemp -d)"
    hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT" "$ROOT/game/NBAStreetV3.iso" > /dev/null
    if [ ! -f "$MOUNT/SLUS_211.26" ]; then
        hdiutil detach "$MOUNT" -quiet
        echo "This ISO is not NBA Street V3 USA (SLUS-21126)."
        exit 1
    fi
    ditto "$MOUNT" "$ROOT/game/iso"
    hdiutil detach "$MOUNT" -quiet
    chmod -R u+w "$ROOT/game/iso"
fi
echo "  $ROOT/game/iso/SLUS_211.26"

step "Graphics host (PCSX2 renderer, Metal). The first time takes ~15 minutes"
[ -f "$ROOT/deps-mac/lib/libSDL3.dylib" ] || "$REPO/tools/macos/build_pcsx2.sh" deps
"$REPO/tools/macos/build_pcsx2.sh" build
"$REPO/tools/macos/build_pcsx2.sh" gshost

step "Recompiler"
"$REPO/tools/macos/build.sh" recomp

step "Game code from your ELF (a few minutes)"
python3 "$REPO/tools/macos/generate_game.py" --root "$ROOT"

step "Game. The first time takes ~15-30 minutes"
"$REPO/tools/macos/build.sh" game

step "Done"
echo "Play: $REPO/tools/macos/play.sh"
