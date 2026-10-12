# NBA Street V3 — native PC port (PS2Recomp + PCSX2 renderer)

**English** | [Español](README.es.md)

Play **NBA Street V3** (PS2) natively on Windows: high resolution, HD textures, controller support and
**working online play**. The game is statically recompiled into a native x64 program with
[PS2Recomp](https://github.com/ran-j/PS2Recomp) and drawn on your GPU by the renderer of
[PCSX2](https://github.com/PCSX2/pcsx2).

> **You need your own copy** of NBA Street V3 (USA version, SLUS-21126) as an ISO file. This project
> does not include the game: no ISO and no game code (the game is built on your PC from your copy).
> The only extra download is the fan-made HD texture pack.

| | |
|---|---|
| ![Title screen](docs/screenshots/title.jpg) | ![Loading screen](docs/screenshots/loading.jpg) |
| ![Tip-off](docs/screenshots/tipoff.jpg) | ![In a match](docs/screenshots/match.jpg) |

<sub>Captured from this port (Vulkan, 4x internal resolution, 16:9). Screenshots of NBA Street V3 © Electronic Arts.</sub>

## How to play

1. Go to [**Releases**](https://github.com/recomp-code/street-recomp-v3/releases/latest) and download
   **`NBAStreetV3-PC-1.0.zip`** (the only file you need).
2. Unzip it anywhere and double-click **`Launcher.cmd`**.
3. Click **Browse...** and choose your NBA Street V3 ISO.
4. Click **Prepare game**. This happens **only once**: it downloads the tools it needs and builds the
   game on your PC from your ISO (about 6 GB of downloads, 1-2 hours). Windows will ask once for
   permission to install the Microsoft C++ build tools. A progress window shows each step; close it
   when it says **Done**.
5. Click **PLAY**. From then on, just open the launcher and press **PLAY**.

<p align="center"><img src="docs/screenshots/launcher.png" alt="Launcher" width="420"></p>

**HD textures** are downloaded and turned on automatically during **Prepare game**, and **online**
play is always ready. In the launcher you can also choose the **resolution** (up to 5K), the
**renderer** and **fullscreen**. While playing, **F1** or **holding START** opens the graphics menu
and **Alt+Enter** switches between window and fullscreen.

Why does it build the game instead of shipping it? The program contains the game's own code
translated to C++, so it can't be distributed; it's made on your PC from your own copy.

## Features

- **Native x64 executable.** The game's MIPS code (EE) is statically recompiled to C++ and compiled
  with MSVC; no CPU emulator at run time. The IOP, SPU2 audio and the PS2 network adapter are
  emulated, VU1 microprograms run on PCSX2's microVU recompiler.
- **Modern GPU rendering** through PCSX2's GS: Vulkan, Direct3D 11/12 or OpenGL, internal resolution
  from native 480p up to 8x (5K+), texture filtering, 4:3 or stretched 16:9, fullscreen.
- **HD textures included**: downloaded and enabled automatically (see [HD textures](#hd-textures)).
- **Online play restored** against a community server: EA accounts, personas, online ballers,
  PLAY NOW matches, no port forwarding. See [Online mode](#online-mode).
- **One-click launcher**: choose your ISO, prepare once, play.
- **In-game graphics menu**: F1, Back+Start or hold START 1.5 s (works from the controller).
- **Xbox-style controllers (XInput) and keyboard**.
- **Emulated memory card** with normal saves.

## HD textures

Nothing to do: **Prepare game** downloads the HD texture pack (`NBAStreetV3-HD-Textures.zip`, about
250 MB, from the same release) and turns it on. You can switch HD textures off and on with **Use HD
textures** in the launcher or in the in-game graphics menu.

Other packs (PCSX2 format, a `.zip` or a folder of `.png` files) can be added with **Add texture
pack** in the launcher; it automatically skips the few textures known to break the image (grainy
menus, broken button icons).

<details>
<summary>Making your own pack (advanced)</summary>

1. In the in-game graphics menu set HD textures to **"Activadas + volcar originales"** (enabled +
   dump originals) and play through the menus and courts you want; the originals are dumped to
   `Documents\PCSX2\textures\SLUS-21126\dumps`.
2. Run `tools\texturas_preparar.ps1`: it copies the dumps to `C:\NBAStreetRecomp\texturas_hd\originales`
   and sets aside the textures that must not be replaced (video frames, dynamic video-memory captures
   the game rewrites every frame, invisible pages dumped with a foreign palette).
3. Upscale the PNGs with any tool (e.g. an AI upscaler), keeping the exact file names.
4. Add the folder with the upscaled PNGs from the launcher (**Add texture pack (folder)...**).

</details>

## Online mode

NBA Street V3's original EA Online service closed years ago; this port brings it back. Online is
always ready: there is nothing to set up.

How to play a match:

1. Press **PLAY** in the launcher.
2. In the game: **PLAY ONLINE** -> **YES** -> select **"1 - NBA Street Online (DHCP)"** -> connect.
   Don't use "New/Edit" on that screen.
3. First time only: create an account (user name of 4+ letters, any e-mail and password — they are
   only stored on the community server, **don't reuse a real password**), then create a **persona**.
4. Create an **online baller** (Create Baller in the online menu) and save it.
5. **PLAY** -> **PICKUP GAMES** -> **PLAY NOW**. You are matched with the next player who does the
   same; the match starts when both are in.

No router setup is needed: match traffic goes through the server. If the game stays on
"connecting", allow `ps2EntryRunner.exe` in your firewall.

<details>
<summary>How it works</summary>

- **Network adapter.** The PS2 network adapter (DEV9/SMAP) is emulated with PCSX2's "sockets" mode:
  no drivers, no admin rights. The game gets an address by DHCP and its EA host names
  (`ps2nbastreet05.ea.com`, etc.) are redirected to the configured server.
- **Server.** A community server reimplements the EA lobby protocol the game speaks: accounts,
  personas, online ballers (saved on the server), quick matches (PLAY NOW) and match setup.
  The server code is not in this repository.
- **Match traffic.** The two consoles normally talk peer-to-peer over UDP. Here each player gets a
  virtual address and all match traffic goes through the server's UDP relay (UDP 21003), so it works
  behind NAT/CGNAT. Latency is your ping to the server plus the other player's.
- **Network settings.** The launcher copies a ready-made network configuration (`game/mc0_netcnf`)
  to the emulated memory card the first time you play online.
- Problems: the log is `C:\NBAStreetRecomp\logs\play_err.log` ("cannot resolve server" = no internet
  or DNS).

</details>

## For developers

Everything below is only needed to build or modify the port by hand; players can stop reading here.

| Path | What it is |
|---|---|
| `Launcher.cmd` / `Launcher.ps1` | Launcher: pick your ISO, prepare the game once, HD textures, play |
| `tools/install.ps1` | One-step installer used by **Prepare game** (tools, sources, build) |
| `tools/install_textures.ps1` | Texture pack installer used by **Add texture pack** (with `gshost/texture_blocklist.txt`) |
| `patches/ps2recomp.patch` | Changes on top of PS2Recomp `2c5fbb9` (recompiler, runtime, IOP, DEV9 network, SPU2...) |
| `patches/pcsx2.patch` | Changes on top of PCSX2 `d073d75` (`pcsx2-gsrunner -live`: real-time renderer for the game) |
| `game/config/` | Recompiler configuration for SLUS-21126 (function list and addresses only) |
| `game/overrides/` | Game-specific fixes (`nba_street_v3_overrides.cpp`) |
| `game/mc0_netcnf/` | Network configuration for the emulated memory card (online) |
| `gshost/nba_street.ini` | Default graphics settings |
| `tools/` | Setup, build, debugging and texture scripts (`make_patches.ps1` regenerates the patches) |
| `docs/PORTING_NOTES.md` | Technical notes (Spanish): every bug found and how it was fixed |
| `Play.cmd` | Starts the game without the launcher (`set NBA_SERVER=off` for offline) |

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

**7. Play:** `nbastreet-v3-recomp\Launcher.cmd` or `Play.cmd`.

## Usage

- **Controls**: Xbox-compatible gamepad (XInput) or keyboard (arrows, WASD, Z/X/C/V, Q/E, 1/3,
  Enter = START). The gamepad only drives the window in front.
- **Graphics menu** (internal resolution, filtering, renderer, HD textures): **F1**, **Back+Start** or
  **hold START for 1.5 s**. Saved to `gshost\nba_street.ini`.
- **Fullscreen**: Alt+Enter or F11.
- **Saves**: `game\iso\mc0\` (emulated memory card).
- **HD textures**: PCSX2 format, in `Documents\PCSX2\textures\SLUS-21126\replacements`, installed by
  `tools\install_textures.ps1` (the launcher button), which skips the hashes in
  `gshost\texture_blocklist.txt` (dynamic screen captures and invisible pages that break the image).

## Status

Playable from start to finish offline: menus, videos, Create Baller, 60 fps matches with correct
physics, audio (emulated SPU2) and memory card. Online works through the emulated DEV9 network
adapter and the community server (accounts, online ballers and courts, PLAY NOW matches relayed
through the server); the server code is not part of this repository.

Performance: matches run at ~59-60 fps on a modern CPU. Version 1.2 fixed the main causes of the
earlier drops (a game thread stuck in a false DMA-timeout loop, IOP overhead and the EA sound
driver's software mixer, now run natively); see `docs/PORTING_NOTES.md` section 5.1. Short dips can
still happen in the busiest scenes, since the game's own frame work is close to the 16.7 ms budget.

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
