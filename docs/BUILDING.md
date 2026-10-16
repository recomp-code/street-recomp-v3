# Building by hand (Windows) and technical details

**English** | [Español](BUILDING.es.md)

Players only need the launcher (Windows) or `tools/macos/install.sh` (Mac): see the [README](../README.md).
This page keeps the manual Windows build, HD texture details, how online works, status and contributing.

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

## Browser build (WebAssembly)

`tools/web/build.sh` (Mac, after `tools/macos/install.sh`) builds the browser version from pinned
sources plus the patches in `patches/`. It never touches the native builds: the web changes live in
their own patches, and the few runtime changes shared with native code are behind `__EMSCRIPTEN__`.

| Piece | Version | Patch |
| --- | --- | --- |
| Emscripten | 6.0.12 | |
| FFmpeg (MPEG-2 videos) | 7.1.2 | |
| PS2Recomp | 2c5fbb9 | `ps2recomp.patch` (shared with native) + `ps2recomp-web.patch` |
| Play! (GS renderer, VU1 JIT) | 83700b2c | `play.patch`, `play-codegen.patch`, `play-dependencies.patch` |

**`ps2recomp-web.patch`**
- `ps2xRuntime/web/`:
  - `web_platform.cpp`: start-up, memory card, sound ring;
  - `play_gs_host.cpp`: GL thread, VU1 worker, settings, WebGL state cache;
  - `library_fetch_stream.js`: disc streaming over HTTP Range, read-ahead, Cache Storage, timeouts
    and retries, no HTTP cache;
  - `site/index.html`: start screen, AudioWorklet, gamepads, diagnostics;
  - `known_shaders.inc`: the game's shader variants (Play!'s `SHADERCAPS`), built at start-up
    together with the ones the browser remembers in IndexedDB.
- IOP / SPU2: Gaussian interpolation, volume sweeps, paced AutoDMA, output limiter.
- EE scheduler: idle-loop sleep with time flowing in 1 ms steps, vblank rebase after stalls.
- DEV9 sockets over a WebSocket (online).
- WebAssembly-only fast paths in the recompiled code's runtime:
  - scalar 64-bit GPR macros (`ps2_runtime_macros.h`);
  - a short path for guest calls (`dispatchGuestBranch`);
  - acquire/release atomics on the GS ring indices.

**`play.patch`** (Play!'s OpenGL GS on WebGL2)
- Accuracy fixes for effects WebGL lacks.
- Texture cache with content hashing and a texture pool.
- Half-rate picture (`?fps=30`).
- HD texture packs in PCSX2's format (`GSH_OpenGL_HdTextures.cpp`), including clamp-region textures
  (`<hash>-r<w>x<h>-…`), hashed like PCSX2's `HashTextureLevel` unswizzled path.
- FSR 1 (`GSH_OpenGL_Fsr.cpp`): a GLSL ES 3.0 port of AMD's EASU + RCAS (MIT). It runs in `FlipImpl`
  only when the window is larger than the displayed image. Colour math in mediump (FP16 on phone
  GPUs, like AMD's half-precision path); flat 2x2 neighbourhoods take a bilinear shortcut (EASU clamps
  to that range anyway), skipping 8 of the 12 reads and the edge analysis.
- Shaders built ahead of time: `PrecompileShaders` / `PumpShaderPrecompile` start the compile and
  link without waiting for their status (HD images are also uploaded two per frame, not all at once); `FinishShader` binds uniforms once a program is built
  (`KHR_parallel_shader_compile`), or right away when a draw needs it.
- Texture uploads (`GSHandler.cpp`, `SetProducerSwizzle`): host-to-local transfers of PSMCT32/PSMT8/PSMT4 in
  whole blocks are gathered on the thread that feeds the GS (VIF1/VU1 worker), swizzled into 256-byte
  GS blocks there, and the GS thread only compares and copies blocks, in the same order as before
  (anything else sent to the GS thread mid-transfer first gets the data received so far, as before).
- The GIF runs in a thread of its own (`play_gs_host.cpp`, `GifThread`; Play!'s `CGIF::IAsyncSink` lets the VIF1
  queue DIRECT packets, MSKPATH3 and read-backs): the VIF1/VU1 worker queues XGKICK packets (copied from VU1
  memory, length from the GIF tags), transfers, vsyncs and registers in order and goes on. The GIF thread is
  woken in batches (one wake per packet cost the worker ~16%) and swizzles the texture transfers above.
  The GL thread's share in a match fell from ~40% to ~29%. `[webgs] image transfers` lines count both paths;
  `[webgs] VU1 worker N% busy` and `[sched] ... game thread N% busy` show each thread's load.
- VU1 block chaining (`BasicBlock.cpp` `CompileChain`, `GenericMipsExecutor.h`, CodeGen `Emit_ExternJmpDyn`): the
  VU1 runs ~7 million blocks a second of ~6 instructions. At a block's end the next block is looked up from
  the guest pc in a per-executor table and entered with a wasm tail call (`return_call_indirect`, Chrome 112+,
  Firefox 121+, Safari 18.2+); browsers without tail calls get a dispatcher hand-off (`nextBlockFunction`).
  The chaining code sits in its own conditional block so the Jitter writes nPC back first. VU1 worker
  ~51% -> ~42% on a Mac with tail calls. `?chain=0` turns it off, `?chain=dispatch` forces the hand-off.
- VU microprograms (`ee/VuExecutor.cpp`): partitions are remembered per (micro memory contents,
  block start), so swapping microprograms back in reuses their blocks.

**The other Play! patches**
- `play-codegen.patch`: the WebAssembly JIT backend maps registers to wasm locals (VU1 ~20% faster).
- `play-dependencies.patch`: build flags for native wasm exceptions + SIMD.

**Updating:** `git pull`, then `tools/web/build.sh`. Changed patches are re-applied by themselves (Play!
files the patch touches are restored first; build folders are kept). A changed
`ps2recomp-web.patch` means a full game rebuild (1-3 hours); `tools/web/build.sh game` rebuilds only
the game and refreshes `web-site`.

**Regenerating the patches** (contributors), from the build trees:

```sh
# REPO = your nbastreet-v3-recomp checkout
cd ~/NBAStreetRecomp/PS2Recomp-web && git diff <commit with ps2recomp.patch applied> HEAD -- . \
    ':!ps2xRuntime/src/runner/register_functions.cpp' > "$REPO"/patches/ps2recomp-web.patch
cd ~/NBAStreetRecomp/play && git add -N <new files> && git diff -- . ':!deps' > "$REPO"/patches/play.patch
git -C deps/CodeGen diff > "$REPO"/patches/play-codegen.patch
git -C deps/Dependencies diff > "$REPO"/patches/play-dependencies.patch
```

Check that they apply on clean checkouts of the pinned commits (`git apply --check`) before sending.

**Measuring:**
- `?debug` shows renderer statistics.
- Every 5 s the log prints a `[webgs]` line: fps, GL time, shaders compiled on demand / ahead of time,
  texture uploads, HD textures loaded.
- `[gsh] new shader <caps>` lines name variants missing from `known_shaders.inc`; add them there.
- Chrome DevTools can profile each worker separately: the game thread, the VU1 worker, the GL thread.
- Reference, a match on an M-series Mac: game thread ~31%, VU1 worker ~52%, GL thread ~35% busy.

**Server:** HTTPS + COOP/COEP, precompressed Brotli and `Cache-Control: private, no-cache`
(`tools/web/Caddyfile.server`); `/net` → `tools/web/net_relay.py` (online), `/diag` →
`tools/web/diag_server.py` (optional diagnostics). The site serves your disc image: keep it private.

## Contributing

Issues and pull requests are welcome. First read `docs/PORTING_NOTES.md` (Spanish): it explains the
architecture (runtime + PCSX2 host over a shared-memory ring), the debugging tools
(`tools\run_scripted.ps1` for automated tests without touching the desktop, `PS2X_IOP_RAM_DUMP`,
`tools\decomp.cmd` with Ghidra, etc.) and every issue solved.

**Never** commit game files (ISO, ELF, generated code in `game\output` or `ps2xRuntime\src\runner`,
extracted textures, saves). For changes to PS2Recomp or PCSX2, regenerate the corresponding patch
with `git diff` against the pinned commit.

