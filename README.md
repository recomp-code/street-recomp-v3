# NBA Street V3 — native PC port (PS2Recomp + PCSX2 renderer)

**English** | [Español](README.es.md)

Static recompilation of **NBA Street V3 (PS2, NTSC-U, SLUS-21126)** into a native Windows x64
executable with [PS2Recomp](https://github.com/ran-j/PS2Recomp), rendered on the GPU by the GS of
[PCSX2](https://github.com/PCSX2/pcsx2) (Vulkan / Direct3D / OpenGL), with up to 8x internal
resolution, VU1 on microVU, PCSX2-compatible HD texture packs and working **online play**.

> **This repository contains NOTHING from the game**: no ISO, no ELF, no code generated from it, no
> textures. You need **your own copy** of NBA Street V3 (SLUS-21126). The game's C++ code is generated
> on your PC from your own ELF.

Contents:

| Path | What it is |
|---|---|
| `Launcher.cmd` / `Launcher.ps1` | Launcher: pick your ISO, prepare the game once, play |
| `tools/install.ps1` | One-step installer used by the launcher (tools, sources, build) |
| `patches/ps2recomp.patch` | Changes on top of PS2Recomp `2c5fbb9` (recompiler, runtime, IOP, DEV9 network, SPU2...) |
| `patches/pcsx2.patch` | Changes on top of PCSX2 `d073d75` (`pcsx2-gsrunner -live`: real-time renderer for the game) |
| `game/config/` | Recompiler configuration for SLUS-21126 (function list and addresses only) |
| `game/overrides/` | Game-specific fixes (`nba_street_v3_overrides.cpp`) |
| `game/mc0_netcnf/` | Network configuration for the emulated memory card (online) |
| `gshost/nba_street.ini` | Default graphics settings |
| `tools/` | Setup, build, debugging and texture scripts |
| `docs/PORTING_NOTES.md` | Technical notes (Spanish): every bug found and how it was fixed |
| `Jugar.cmd` | Plain launcher script (no UI) |

## Playing (the easy way): the launcher

1. Download `NBAStreetV3-PC-<version>.zip` from **Releases** and unzip it anywhere.
2. Double-click **`Launcher.cmd`**. A small window opens:

   | Control | What it does |
   |---|---|
   | **Tu ISO... / Elegir...** | Pick your NBA Street V3 ISO (NTSC-U, SLUS-21126). Remembered for next time. |
   | **Preparar juego** ("prepare game") | One-time setup: installs Visual Studio Build Tools, CMake and Git if missing, extracts your ISO into `C:\NBAStreetRecomp\game`, generates the game's C++ code from your ELF and compiles it. ~6 GB of downloads, 1-2 hours the first time; progress is shown in a console window ("Listo" = done). Once prepared, the button becomes **Reparar** (repair/rebuild). |
   | **Resolucion interna** | Internal resolution: native 480p, 720p, 1080p, 1440p, 4K or 8x. |
   | **Renderizador** | Vulkan (recommended), Direct3D 11, Direct3D 12 or OpenGL. |
   | **Pantalla completa** | Start in fullscreen (Alt+Enter toggles in game). |
   | **Texturas HD** | Load PCSX2-format HD texture packs from `Documents\PCSX2\textures\SLUS-21126\replacements`. |
   | **Jugar online** + **Servidor** | Enable the network adapter and choose the online server (default: the community server `nbas3.xellrecomp.party`). Untick to play fully offline. |
   | **JUGAR** ("play") | Starts the game with the options above. |

   Graphics options are saved in `C:\NBAStreetRecomp\gshost\nba_street.ini`, launcher options in
   `%APPDATA%\NBAStreetV3Launcher.json`. You can change graphics in game too: **F1**, **Back+Start**
   or **hold START 1.5 s** opens the graphics menu.

Why compile? The final executable contains the game's code translated to C++, so it cannot be
distributed. Everything that can be distributed (PCSX2 renderer, patches, tools) is in the zip.

`Jugar.cmd` does the same as **JUGAR** without a window (online by default; `set NBA_SERVER=off`
for offline, or `set NBA_SERVER=<host or IP>` for another server).

## Online mode

NBA Street V3's original EA Online service closed years ago. This port brings it back:

- **Network adapter.** The PS2 network adapter (DEV9/SMAP) is emulated with PCSX2's "sockets" mode:
  no drivers, no admin rights, no TAP/pcap. The game gets an address by DHCP and its EA host names
  (`ps2nbastreet05.ea.com`, etc.) are redirected to the configured server.
- **Server.** A community server reimplements the EA lobby protocol the game speaks: accounts,
  personas, online ballers (saved on the server), quick matches (PLAY NOW) and match setup.
  The server code is not in this repository.
- **Match traffic.** The two consoles normally talk peer-to-peer over UDP. Here each player gets a
  virtual address and all match traffic goes through the server's UDP relay, so **no ports need to
  be opened** on your router and it works behind NAT/CGNAT. Latency is your ping to the server plus
  the other player's.
- **Network settings.** The launcher copies a ready-made network configuration (`game/mc0_netcnf`)
  to the emulated memory card the first time you play online.

How to play a match:

1. In the launcher keep **Jugar online** ticked and press **JUGAR**.
2. In the game: **PLAY ONLINE** -> **YES** -> select **"1 - NBA Street Online (DHCP)"** -> connect.
   Do not use "New/Edit" on that screen.
3. First time: create an EA account (user name of 4+ letters, any e-mail and password; they are only
   stored on the community server, do not reuse a real password), then create a **persona**.
4. Create an **online baller** (Create Baller from the online menu) and save it.
5. **PLAY** -> **PICKUP GAMES** -> **PLAY NOW**. You are matched with the next player who does the
   same; the match starts when both are in.

Troubleshooting: "cannot resolve server" in `C:\NBAStreetRecomp\logs\jugar_err.log` means no internet
or DNS; the game staying on "connecting" usually means a firewall blocks `ps2EntryRunner.exe`
(TCP to the server and UDP 21003).
## Requirements (building by hand)

- Windows 10/11 x64, a GPU with Vulkan (or Direct3D 11/12), ~40 GB free, 16 GB RAM recommended.
- **Visual Studio 2022 Build Tools** with "Desktop development with C++" (MSVC v143 + Windows SDK).
- Paths are fixed to **`C:\NBAStreetRecomp`**: the project must live there.
- Portable tools in `C:\NBAStreetRecomp\tools\` (the scripts look for them in these folders):

| Folder | Tool |
|---|---|
| `tools\mingit\` | [MinGit](https://github.com/git-for-windows/git/releases) (or Git on the PATH) |
| `tools\cmake\cmake-4.4.4-windows-x86_64\` | [CMake 4.x](https://cmake.org/download/) (zip) |
| `tools\llvm\clang+llvm-20.1.8-x86_64-pc-windows-msvc\` | [LLVM 20](https://github.com/llvm/llvm-project/releases) (clang-cl, for PCSX2) |
| `tools\ninja\` | [Ninja](https://github.com/ninja-build/ninja/releases) |
| `tools\python\` | Embeddable Python 3 (needed by the PCSX2 dependency build) |
| `tools\portablegit\` | [PortableGit](https://github.com/git-for-windows/git/releases) (provides `bash`/`patch` for the PCSX2 dependencies) |
| `tools\7zip\` | [7-Zip](https://www.7-zip.org/) extra (`x64\7za.exe`) |

LLVM, Ninja, Python, PortableGit and 7-Zip are only needed to build the renderer yourself
(step 6); the release zip ships it prebuilt. If you prefer tools installed system-wide, edit the
paths at the top of the `.cmd` files in `tools\`.

## Building

Everything from `C:\NBAStreetRecomp`. Clone this repository into
`C:\NBAStreetRecomp\nbastreet-v3-recomp` and copy its `tools\` folder into `C:\NBAStreetRecomp\tools\`
(next to the portable tools).

**1. Your game.** Extract your ISO with 7-Zip into `C:\NBAStreetRecomp\game\iso\` (you must end up
with `game\iso\SLUS_211.26`) and copy the ISO itself to `C:\NBAStreetRecomp\game\NBAStreetV3.iso`
(the game reads disc sectors directly).

**2. PS2Recomp and PCSX2 sources with the patches applied:**
```bat
powershell -ExecutionPolicy Bypass -File nbastreet-v3-recomp\tools\setup_sources.ps1
```

**3. Build the recompiler:**
```bat
tools\cmake\cmake-4.4.4-windows-x86_64\bin\cmake -S PS2Recomp -B PS2Recomp\out\build
tools\build_recomp.cmd
```

**4. Generate the game code** from your ELF (a few minutes; ~100,000 .cpp files):
```bat
powershell -ExecutionPolicy Bypass -File nbastreet-v3-recomp\tools\generate_game.ps1
```

**5. Build the game** (slow the first time: it is the whole game as C++):
```bat
tools\build_runner.cmd
```
Output: `PS2Recomp\out\build\ps2xRuntime\Release\ps2EntryRunner.exe`. Afterwards use
`tools\build_runner_only.cmd` (incremental). Logs go to `logs\`.

**6. Build the renderer (PCSX2 `pcsx2-gsrunner`, no Qt):**
```bat
tools\build_pcsx2_deps.bat
tools\build_pcsx2.cmd pcsx2-gsrunner
powershell -ExecutionPolicy Bypass -File nbastreet-v3-recomp\tools\setup_gshost.ps1
```
The dependencies (SDL3, shaderc, etc.) are built only once. `setup_gshost.ps1` assembles
`C:\NBAStreetRecomp\gshost` with the exe, DLLs, `resources` and the graphics settings.

**7. Play:** `nbastreet-v3-recomp\Launcher.cmd` or `Jugar.cmd`.

## Usage

- **Controls**: Xbox-compatible gamepad (XInput) or keyboard (arrows, WASD, Z/X/C/V, Q/E, 1/3,
  Enter = START). The gamepad only drives the window in front.
- **Graphics menu** (internal resolution, filtering, renderer, HD textures): **F1**, **Back+Start** or
  **hold START for 1.5 s**. Saved to `gshost\nba_street.ini`.
- **Fullscreen**: Alt+Enter or F11.
- **Saves**: `game\iso\mc0\` (emulated memory card).
- **HD textures**: PCSX2 format, in `Documents\PCSX2\textures\SLUS-21126\replacements`.
  See `tools\texturas_preparar.ps1` / `texturas_instalar.ps1`: they automatically set aside textures
  that must not be replaced (dynamic screen captures and invisible pages), which break the image.

## Status

Playable from start to finish offline: menus, videos, Create Baller, 60 fps matches with correct
physics, audio (emulated SPU2) and memory card. Online works through the emulated DEV9 network
adapter and the community server (accounts, online ballers and courts, PLAY NOW matches relayed
through the server); the server code is not part of this repository.

Known issues: occasional dropped frames (57-58 fps instead of 60) caused by synchronous VU1
round-trips between the game and the renderer process; being worked on.

The recompiler bugs found (and fixed in `patches/ps2recomp.patch`) are documented in
`docs/PORTING_NOTES.md`; several affect any PS2 game ported with PS2Recomp (SQRT.S, 64-bit
BLTZ/BGEZ branches, MMI, VU0...).

## Contributing

Issues and pull requests are welcome. First read `docs/PORTING_NOTES.md` (Spanish): it explains the
architecture (runtime + PCSX2 host over a shared-memory ring), the debugging tools
(`tools\run_scripted.ps1` for automated tests without touching the desktop, `PS2X_IOP_RAM_DUMP`,
`tools\decomp.cmd` with Ghidra, etc.) and every issue solved.

**Never** commit game files (ISO, ELF, generated code in `game\output` or `ps2xRuntime\src\runner`,
extracted textures, saves). For changes to PS2Recomp or PCSX2, regenerate the corresponding patch
with `git diff` against the pinned commit.

## License and credits

GPL-3.0 (same as PS2Recomp and PCSX2). Based on [PS2Recomp](https://github.com/ran-j/PS2Recomp) by
ran-j and contributors and on [PCSX2](https://github.com/PCSX2/pcsx2) (GS, microVU, DEV9).
NBA Street V3 is the property of Electronic Arts; this project is not affiliated with EA and does
not distribute any game content.
