# Online lockstep (work in progress)

A second online mode, next to the EA lobby one: the game's own **2-player local match** played by two machines,
the same way as the Recomp ports of Bloody Roar 4 and DBZ Budokai Tenkaichi 4. Each machine runs the whole game;
only the pads cross the network, and both games run the same frames identically (deterministic mode), comparing a
hash of their memory every second.

- Any court and any 2-player mode, created ballers from the shared memory card, no EA account.
- Through the Recomp server's relay (works behind NAT), invitations and friends in the Recomp launcher.
- Mac and Windows play together (the runtime is integer-exact on both).

The EA online mode (PLAY ONLINE, the community lobby server) is untouched and works as before.

## Status

Two games on one PC through a local relay: intros, menus, USER SETUP with player 2 on the other machine, CHOOSE
TEAM, and a match, **226/226 equal state hashes, 0 desyncs**. Not in a release yet: the Recomp launcher profile
and packs come next.

## Build

`patches/ps2recomp-online.patch` is a layer on top of `ps2recomp.patch` + `ps2recomp-web.patch`: the runtime of the
Bloody Roar 4 port (deterministic mode, `Kernel/Net/NetPlay.*`, the live ring v2 of the shared GS host, the audio
and scheduler fixes) merged into this one. NBA Street V3 keeps its own IOP heap base (0x120000: EA's modules and
the network stack). It needs the shared GS host (ring v2), not the `pcsx2.patch` one of this repository.

What it changes for NBA Street V3:

- `sceMpegAddBs`: EA's player feeds sequence-end codes while its queue is empty; the end of a movie was taken after
  1.5 s of the host's clock. In the deterministic mode it is 1.5 s of emulated time: the number of empty feeds
  depended on the host's speed and the two games ended the EA movie one picture apart (vblank ~1038).
- Pads: online, port 2 (the other player) is open and connected from the start. The game polls port 2 before
  opening it and only opens a port that reports a pad, so player 2 never appeared.
- The game's three frame waits (0x003E3948, 0x003E3DA8, 0x003E3720) are registered as idle loops in the
  deterministic mode too (they already were in the browser), so emulated time goes on to the next event there.
- Diagnostics: `PS2X_DETCYCLES=1` prints the EE cycle at every vblank (cheap enough not to change the timing it
  looks for: the first differing vblank is where two games parted), `PS2X_PAD_TRACE=1` the pad calls on port 2+.

## Test on one machine

`tools/online/net_pair_test.ps1` starts two games (player 1 and 2) through a local copy of the server's relay
(`bloody-roar4-recomp/tools/testrelay`), each with a copy of the memory card, scripted pads per player
(`-Script1`, `-Script2`), and compares their hashes. Example, to a match:

```powershell
.\tools\online\net_pair_test.ps1 -Seconds 230 -Shots 200 `
  -Script1 '97:START,109:CROSS,114:CROSS,120:CROSS,126:CROSS,132:CROSS,138:CROSS,144:CROSS,150:CROSS,156:CROSS' `
  -Script2 '114:DOWN,116:CROSS,120:CROSS,126:CROSS,132:CROSS,138:CROSS,144:CROSS,150:CROSS,156:CROSS' `
  -Env @{ PS2X_PAD_SCRIPT_HOLD = '120' }
```

Never set `PS2X_NET` for this mode: in this port that name turns on the network adapter of the EA online mode.
