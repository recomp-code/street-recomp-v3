NBA Street V3 - Mac (Apple Silicon, macOS 14 or newer)
=======================================================

How to play
-----------
1. Unzip and drag NBAStreetV3.app to Applications (or anywhere you like).
2. The first time, macOS warns that the app is not from an identified developer (it is not signed with an
   Apple developer account). Open it once like this:
     - macOS 15 or newer: double-click NBAStreetV3.app, close the warning, then System Settings >
       Privacy & Security and, at the bottom, "Open Anyway" next to NBAStreetV3.
     - macOS 14: right-click (or Ctrl+click) NBAStreetV3.app > Open > Open.
   Or in Terminal:  xattr -dr com.apple.quarantine /Applications/NBAStreetV3.app
3. Click "Browse..." and choose your own NBA Street V3 ISO (USA, SLUS-21126). Only the first time.
4. Pick the resolution and click PLAY.

This package does NOT include the game: you need your own disc image. While you play, the app mounts the ISO
read-only (it does not show up in Finder) and the game reads the disc from there.

Controls
--------
Controller (Xbox, PlayStation or MFi connected to the Mac): A = Cross, B = Circle, X = Square, Y = Triangle.
Keyboard: arrows = d-pad, WASD = left stick, Z/X/C/V = Square/Cross/Circle/Triangle, Q/E = L1/R1,
          1/3 = L2/R2, Return = START, Delete = SELECT.
F1 (or Back+Start, or hold START 1.5 s) = graphics menu. Option+Return or Ctrl+Cmd+F = fullscreen. Cmd+Q = quit.

Online play uses the community server (nbas3.xellrecomp.party); untick "Online play" in the launcher to play
without network.

Saves, graphics settings and logs: ~/Library/Application Support/NBAStreetV3 ("Saves and logs..." button).
If something fails: logs/play.log.

Source code and how to build it: https://github.com/recomp-code/street-recomp-v3
