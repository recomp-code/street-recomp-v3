#!/bin/bash
# make_dist.sh [version]: the ready-to-play Mac app, NBAStreetV3.app (+ NBAStreetV3-Mac-<version>.zip). It has no
# ISO, ELF or disc files: the launcher checks the player's own ISO and mounts it read-only while the game runs.
#   Contents/MacOS/      NBAStreetV3 (launcher), pcsx2-gsrunner (PCSX2's GS on Metal, $NBA_ROOT/gshost)
#   Contents/Helpers/    Game.app: ps2EntryRunner (the recompiled game, build_runner.sh), a UI element (no Dock icon)
#   Contents/Frameworks/ the GS host's dylibs (SDL3, freetype, png, webp...), rewritten to load from here
#   Contents/Resources/  PCSX2's resources (shaders, fonts, GameIndex.yaml), presets/ (one ini per resolution),
#                        mc0_netcnf/ (the memory card's network settings), AppIcon.icns
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
ROOT="${NBA_ROOT:-$HOME/NBAStreetRecomp}"
VERSION="${1:-1.0}"
RUNNER="${RUNNER:-$ROOT/PS2Recomp/out/build-mac-dist/ps2xRuntime/ps2EntryRunner}"
GSHOST="${GSHOST:-$ROOT/gshost}"
OUT="${OUT:-$ROOT/macdist}"
APP="$OUT/NBAStreetV3.app"
C="$APP/Contents"

rm -rf "$APP"
mkdir -p "$C/MacOS" "$C/Frameworks" "$C/Resources/presets"
sed "s/@VERSION@/$VERSION/g" "$HERE/Info.plist" > "$C/Info.plist"

# executables
# the runner goes in a helper app with LSUIElement: no Dock icon for a process without a window of its own
G="$C/Helpers/Game.app/Contents/MacOS"
mkdir -p "$G"
cat > "$C/Helpers/Game.app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>ps2EntryRunner</string>
	<key>CFBundleIdentifier</key><string>io.github.recomp-code.nba-street-v3.game</string>
	<key>CFBundleName</key><string>NBA Street V3</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
"$HERE/build_launcher.sh" "$C/MacOS/NBAStreetV3"
cp "$RUNNER" "$G/"
cp "$GSHOST/pcsx2-gsrunner" "$C/MacOS/"
strip -x "$G/ps2EntryRunner" "$C/MacOS/pcsx2-gsrunner"

# dylibs: everything outside the system, recursively, loaded from Contents/Frameworks
outside() { { otool -L "$1" | tail -n +2 | awk '{print $1}' | grep -E '^/(opt|usr/local|Users)/' || true; }; }
while :; do
    added=0
    for bin in "$G/ps2EntryRunner" "$C/MacOS/pcsx2-gsrunner" "$C"/Frameworks/*.dylib; do
        [ -f "$bin" ] || continue
        for dep in $(outside "$bin"); do
            name="$(basename "$dep")"
            if [ ! -f "$C/Frameworks/$name" ]; then
                cp -L "$dep" "$C/Frameworks/$name"
                chmod u+w "$C/Frameworks/$name"
                install_name_tool -id "@executable_path/../Frameworks/$name" "$C/Frameworks/$name" 2>/dev/null
                added=1
            fi
        done
    done
    [ $added = 0 ] && break
done
for bin in "$G/ps2EntryRunner" "$C/MacOS/pcsx2-gsrunner" "$C"/Frameworks/*.dylib; do
    [ -f "$bin" ] || continue
    for dep in $(outside "$bin"); do
        install_name_tool -change "$dep" "@executable_path/../Frameworks/$(basename "$dep")" "$bin" 2>/dev/null
    done
done
if otool -L "$C/MacOS/"* "$G/"* "$C"/Frameworks/*.dylib 2>/dev/null | grep -E '^\s/(opt|usr/local|Users)/'; then
    echo "a binary still loads a library from this Mac (above)" >&2; exit 1
fi

# resources: PCSX2's (CocoaTools::GetResourcePath = the bundle's Resources), presets, memory card network settings
cp -R "$GSHOST/resources/" "$C/Resources/"
P="$C/Resources/presets"
for s in 2 3 4 6; do
    f=nba_street_${s}x.ini; [ $s = 3 ] && f=nba_street.ini
    sed -e "s/^upscale_multiplier = 3/upscale_multiplier = $s/" "$REPO/gshost/nba_street_macos.ini" > "$P/$f"
done
cp -R "$REPO/game/mc0_netcnf" "$C/Resources/mc0_netcnf"

# icon: the repository's launcher icon
ICON="$OUT/AppIcon.iconset"
rm -rf "$ICON"; mkdir -p "$ICON"
for s in 16 32 128 256 512; do
    sips -z $s $s "$HERE/icon.png" --out "$ICON/icon_${s}x${s}.png" > /dev/null
    sips -z $((s * 2)) $((s * 2)) "$HERE/icon.png" --out "$ICON/icon_${s}x${s}@2x.png" > /dev/null
done
iconutil -c icns "$ICON" -o "$C/Resources/AppIcon.icns"
rm -rf "$ICON"

# ad-hoc signature, inside out (Apple Silicon refuses unsigned code)
codesign --force -s - "$C"/Frameworks/*.dylib
codesign --force -s - "$G/ps2EntryRunner" "$C/MacOS/pcsx2-gsrunner"
codesign --force -s - "$C/Helpers/Game.app"
codesign --force -s - "$APP"
codesign --verify --deep --strict "$APP"

du -sh "$APP"
if [ "${NOZIP:-0}" != 1 ]; then
    ZIP="$OUT/NBAStreetV3-Mac-$VERSION.zip"
    rm -f "$ZIP"
    cp "$HERE/README.txt" "$OUT/README.txt"
    (cd "$OUT" && ditto -c -k --sequesterRsrc --keepParent NBAStreetV3.app "$ZIP.tmp" && \
        zip -q "$ZIP.tmp" README.txt && mv "$ZIP.tmp" "$ZIP")
    du -sh "$ZIP"
fi
