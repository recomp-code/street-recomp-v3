# Compilar a mano (Windows) y detalles técnicos

[English](BUILDING.md) | **Español**

Para jugar basta el launcher (Windows) o `tools/macos/install.sh` (Mac): ver el [README](../README.es.md).
Esta página conserva la compilación manual en Windows, los detalles de las texturas HD, cómo funciona el online, el estado y cómo contribuir.

## Texturas HD

No tienes que hacer nada: **Prepare game** descarga el pack de texturas HD (`NBAStreetV3-HD-Textures.zip`,
unos 250 MB, de la misma release) y lo activa. Puedes desactivarlas y activarlas con **Use HD textures**
en el launcher o en el menú gráfico del juego.

Otros packs (formato PCSX2, un `.zip` o una carpeta de `.png`) se añaden con **Add texture pack** en el
launcher, que se salta solo las pocas texturas que estropean la imagen (menús con grano, iconos rotos).

<details>
<summary>Hacer tu propio pack (avanzado)</summary>

1. En el menú gráfico del juego pon Texturas HD en **"Activadas + volcar originales"** y recorre los
   menús y canchas que quieras; los originales se vuelcan a `Documentos\PCSX2\textures\SLUS-21126\dumps`.
2. Ejecuta `tools\texturas_preparar.ps1`: copia los volcados a `C:\NBAStreetRecomp\texturas_hd\originales`
   y aparta las texturas que no se deben reemplazar (fotogramas de vídeo, capturas dinámicas de
   memoria de vídeo que el juego reescribe cada fotograma, páginas invisibles con paleta ajena).
3. Mejora los PNG con la herramienta que quieras (p. ej. un escalador por IA), con los mismos nombres.
4. Añade la carpeta con los PNG mejorados desde el launcher (**Add texture pack (folder)...**).

</details>

## Modo online

El servicio EA Online original del juego cerró hace años; este port lo recupera. El online está
siempre listo: no hay que configurar nada.

Cómo jugar un partido:

1. Pulsa **PLAY** en el launcher.
2. En el juego: **PLAY ONLINE** -> **YES** -> **"1 - NBA Street Online (DHCP)"** -> conectar.
   No uses "New/Edit" en esa pantalla.
3. Solo la primera vez: crea una cuenta (usuario de 4+ letras, cualquier e-mail y contraseña — solo
   se guardan en el servidor de la comunidad, **no reutilices una contraseña real**) y luego una **persona**.
4. Crea un **baller online** (Create Baller en el menú online) y guárdalo.
5. **PLAY** -> **PICKUP GAMES** -> **PLAY NOW**. Te empareja con el siguiente jugador que haga lo
   mismo; el partido empieza cuando están los dos.

No hace falta configurar el router: el tráfico del partido pasa por el servidor. Si se queda en
"connecting", permite `ps2EntryRunner.exe` en tu firewall.

<details>
<summary>Cómo funciona</summary>

- **Adaptador de red.** El adaptador de red de PS2 (DEV9/SMAP) se emula con el modo "sockets" de
  PCSX2: sin drivers ni permisos de administrador. El juego obtiene IP por DHCP y sus nombres de EA
  (`ps2nbastreet05.ea.com`, etc.) se redirigen al servidor configurado.
- **Servidor.** Un servidor de la comunidad reimplementa el protocolo de lobby de EA: cuentas,
  personas, ballers online (guardados en el servidor), partidas rápidas (PLAY NOW) y montaje del
  partido. El código del servidor no está en este repositorio.
- **Tráfico del partido.** Las dos consolas hablan normalmente P2P por UDP. Aquí cada jugador recibe
  una IP virtual y todo el tráfico pasa por el relay UDP del servidor (UDP 21003): funciona detrás de
  NAT/CGNAT. La latencia es tu ping al servidor más el del rival.
- **Configuración de red.** El launcher copia una configuración lista (`game/mc0_netcnf`) a la
  memory card emulada la primera vez que juegas online.
- Problemas: el log es `C:\NBAStreetRecomp\logs\play_err.log` ("cannot resolve server" = sin internet o DNS).

</details>

## Requisitos (compilar a mano)

- Windows 10/11 x64, GPU con Vulkan (o Direct3D 11/12), ~40 GB libres, 16 GB de RAM recomendados.
- **Visual Studio 2022 Build Tools** con "Desarrollo para el escritorio con C++" (MSVC v143 + Windows SDK).
- Las rutas están fijadas a **`C:\NBAStreetRecomp`**: el proyecto debe vivir ahí.
- Herramientas portables en `C:\NBAStreetRecomp\tools\` (los scripts las buscan en estas carpetas):

| Carpeta | Herramienta |
|---|---|
| `tools\mingit\` | [MinGit](https://github.com/git-for-windows/git/releases) (o Git instalado en el PATH) |
| `tools\cmake\cmake-4.4.4-windows-x86_64\` | [CMake 4.x](https://cmake.org/download/) (zip) |
| `tools\llvm\clang+llvm-20.1.8-x86_64-pc-windows-msvc\` | [LLVM 20](https://github.com/llvm/llvm-project/releases) (clang-cl, para PCSX2) |
| `tools\ninja\` | [Ninja](https://github.com/ninja-build/ninja/releases) |
| `tools\python\` | Python 3 embebible (lo pide el build de dependencias de PCSX2) |
| `tools\portablegit\` | [PortableGit](https://github.com/git-for-windows/git/releases) (aporta `bash`/`patch` para las dependencias de PCSX2) |
| `tools\7zip\` | [7-Zip](https://www.7-zip.org/) extra (`x64\7za.exe`) |

Si prefieres herramientas instaladas en el sistema, edita las rutas al principio de los `.cmd` de `tools\`.

## Compilar

Todo desde `C:\NBAStreetRecomp`. Clona este repositorio en `C:\NBAStreetRecomp\nbastreet-v3-recomp`
y copia el contenido de su carpeta `tools\` a `C:\NBAStreetRecomp\tools\` (junto a las herramientas portables).

**1. Tu juego.** Extrae tu ISO con 7-Zip en `C:\NBAStreetRecomp\game\iso\` (debe quedar
`game\iso\SLUS_211.26`) y copia la propia ISO como `C:\NBAStreetRecomp\game\NBAStreetV3.iso`
(el juego lee sectores del disco directamente).

**2. Fuentes de PS2Recomp y PCSX2 con los parches:**
```bat
powershell -ExecutionPolicy Bypass -File nbastreet-v3-recomp\tools\setup_sources.ps1
```

**3. Compilar el recompilador:**
```bat
tools\cmake\cmake-4.4.4-windows-x86_64\bin\cmake -S PS2Recomp -B PS2Recomp\out\build
tools\build_recomp.cmd
```

**4. Generar el código del juego** desde tu ELF (unos minutos; ~100.000 archivos .cpp):
```bat
powershell -ExecutionPolicy Bypass -File nbastreet-v3-recomp\tools\generate_game.ps1
```

**5. Compilar el juego** (la primera vez tarda mucho: es el ejecutable completo del juego en C++):
```bat
tools\build_runner.cmd
```
Resultado: `PS2Recomp\out\build\ps2xRuntime\Release\ps2EntryRunner.exe`. Las siguientes veces,
`tools\build_runner_only.cmd` (incremental). Log en `logs\`.

**6. Compilar el render (PCSX2 `pcsx2-gsrunner`, sin Qt):**
```bat
tools\build_pcsx2_deps.bat
tools\build_pcsx2.cmd pcsx2-gsrunner
powershell -ExecutionPolicy Bypass -File nbastreet-v3-recomp\tools\setup_gshost.ps1
```
Las dependencias (SDL3, shaderc, etc.) solo se compilan una vez. `setup_gshost.ps1` monta
`C:\NBAStreetRecomp\gshost` con el exe, las DLL, `resources` y la configuración gráfica.

**7. Jugar:** `nbastreet-v3-recomp\Play.cmd` (cópialo donde quieras).

## Uso

- **Controles**: mando Xbox/compatible (XInput) o teclado (flechas, WASD, Z/X/C/V, Q/E, 1/3, Enter = START).
- **Menú gráfico** (resolución interna, filtro, renderizador, texturas HD): **F1**, **Back+Start** o
  **mantener START 1,5 s**. Se guarda en `gshost\nba_street.ini`.
- **Pantalla completa**: Alt+Enter o F11.
- **Partidas guardadas**: `game\iso\mc0\` (memory card emulada).
- **Texturas HD**: formato de PCSX2, en `Documentos\PCSX2\textures\SLUS-21126\replacements`.
  Las instala `tools\install_textures.ps1` (el botón del launcher), que se salta los hashes de
  `gshost\texture_blocklist.txt` (capturas dinámicas de pantalla y páginas invisibles que estropean la imagen).

## Estado

Jugable de principio a fin en offline: menús, vídeos, Create Baller, partidos a 60 fps con física
correcta, audio (SPU2 emulado) y memory card. El modo online existe en el código (adaptador de red
DEV9 emulado) y se conecta al servidor de la comunidad; el código del servidor no forma parte de este repositorio.

Rendimiento: los partidos van a ~59-60 fps en una CPU moderna. La versión 1.2 corrigió las causas
principales de las bajadas (un hilo del juego atascado en un falso timeout de DMA, la sobrecarga del
IOP y el mezclador de sonido de EA, que ahora corre nativo); ver `docs/PORTING_NOTES.md`, sección 5.1.
Aún puede haber pequeñas bajadas en las escenas más cargadas: el trabajo del propio juego por
fotograma está cerca del presupuesto de 16,7 ms.

Los bugs del recompilador encontrados (y corregidos en `patches/ps2recomp.patch`) están en
`docs/PORTING_NOTES.md`; varios afectan a cualquier juego de PS2 portado con PS2Recomp
(SQRT.S, saltos BLTZ/BGEZ de 64 bits, MMI, VU0...).

## Versión de navegador (WebAssembly)

`tools/web/build.sh` (Mac, después de `tools/macos/install.sh`) compila la versión de navegador con
fuentes en versiones fijas más los parches de `patches/`. No toca las compilaciones nativas: los
cambios web van en sus propios parches, y los pocos cambios del runtime compartidos con el código
nativo están dentro de `__EMSCRIPTEN__`.

| Pieza | Versión | Parche |
| --- | --- | --- |
| Emscripten | 6.0.12 | |
| FFmpeg (videos MPEG-2) | 7.1.2 | |
| PS2Recomp | 2c5fbb9 | `ps2recomp.patch` (compartido con nativo) + `ps2recomp-web.patch` |
| Play! (render del GS, JIT de VU1) | 83700b2c | `play.patch`, `play-codegen.patch`, `play-dependencies.patch` |

**`ps2recomp-web.patch`**
- `ps2xRuntime/web/`:
  - `web_platform.cpp`: arranque, memory card, anillo de sonido;
  - `play_gs_host.cpp`: hilo GL, hilo de la VU1, ajustes, caché de estado de WebGL;
  - `library_fetch_stream.js`: streaming del disco por HTTP Range, lectura anticipada, Cache Storage,
    plazos y reintentos, sin caché HTTP;
  - `site/index.html`: pantalla de inicio, AudioWorklet, mandos, diagnóstico.
- IOP / SPU2: interpolación gaussiana, barridos de volumen, AutoDMA a ritmo, limitador de salida.
- Planificador del EE: espera dormida con el tiempo avanzando en pasos de 1 ms, rebase del vblank
  tras atascos.
- Sockets del DEV9 por un WebSocket (online).
- Caminos rápidos solo para WebAssembly en el runtime del código recompilado:
  - macros de registros de 64 bits escalares (`ps2_runtime_macros.h`);
  - camino corto para las llamadas del juego (`dispatchGuestBranch`);
  - atómicos acquire/release en los índices del anillo del GS.

**`play.patch`** (el GS OpenGL de Play! sobre WebGL2)
- Arreglos de precisión para efectos que WebGL no tiene.
- Caché de texturas con hash de contenido y un pool de texturas.
- Imagen a media tasa (`?fps=30`).
- Packs de texturas HD en formato PCSX2 (`GSH_OpenGL_HdTextures.cpp`), incluidas las texturas con
  región de clamp (`<hash>-r<an>x<al>-…`), con el mismo hash que la ruta sin swizzle de
  `HashTextureLevel` de PCSX2.
- FSR 1 (`GSH_OpenGL_Fsr.cpp`): port a GLSL ES 3.0 de EASU + RCAS de AMD (MIT). Se aplica en
  `FlipImpl` solo cuando la ventana es más grande que la imagen mostrada.

**Los otros parches de Play!**
- `play-codegen.patch`: el backend JIT de WebAssembly pone los registros en locales de wasm (VU1
  ~20% más rápida).
- `play-dependencies.patch`: opciones de compilación para excepciones nativas de wasm + SIMD.

**Actualizar:** `git pull` y luego `tools/web/build.sh`. Los parches cambiados se vuelven a aplicar
solos (antes se restauran los archivos de Play! que toca el parche; las carpetas de compilación se
conservan). Si cambia `ps2recomp-web.patch`, se recompila el juego entero (1-3 horas);
`tools/web/build.sh game` recompila solo el juego y actualiza `web-site`.

**Regenerar los parches** (colaboradores), desde los árboles de compilación:

```sh
# REPO = tu copia de nbastreet-v3-recomp
cd ~/NBAStreetRecomp/PS2Recomp-web && git diff <commit con ps2recomp.patch aplicado> HEAD -- . \
    ':!ps2xRuntime/src/runner/register_functions.cpp' > "$REPO"/patches/ps2recomp-web.patch
cd ~/NBAStreetRecomp/play && git add -N <archivos nuevos> && git diff -- . ':!deps' > "$REPO"/patches/play.patch
git -C deps/CodeGen diff > "$REPO"/patches/play-codegen.patch
git -C deps/Dependencies diff > "$REPO"/patches/play-dependencies.patch
```

Comprueba que se aplican sobre copias limpias de los commits fijados (`git apply --check`) antes de
enviarlos.

**Medir:**
- `?debug` muestra estadísticas del render.
- Cada 5 s el registro imprime una línea `[webgs]`: fps, tiempo de GL, subidas de texturas, texturas
  HD cargadas.
- Las DevTools de Chrome pueden perfilar cada hilo por separado: el del juego, el de la VU1 y el de GL.
- Referencia, un partido en un Mac con chip M: hilo del juego ~31%, hilo de la VU1 ~52%, hilo de GL
  ~35% ocupados.

**Servidor:** HTTPS + COOP/COEP, Brotli precomprimido y `Cache-Control: private, no-cache`
(`tools/web/Caddyfile.server`); `/net` → `tools/web/net_relay.py` (online), `/diag` →
`tools/web/diag_server.py` (diagnóstico opcional). El sitio sirve tu imagen del disco: mantenlo privado.

## Contribuir

Issues y pull requests bienvenidos. Antes de nada lee `docs/PORTING_NOTES.md`: explica la
arquitectura (runtime + host de PCSX2 por un anillo de memoria compartida), las herramientas de
depuración (`tools\run_scripted.ps1` para pruebas automáticas sin tocar el escritorio,
`PS2X_IOP_RAM_DUMP`, `tools\decomp.cmd` con Ghidra, etc.) y cada problema resuelto.

**Nunca** subas archivos del juego (ISO, ELF, código generado en `game\output` o
`ps2xRuntime\src\runner`, texturas extraídas, partidas). Para cambios en PS2Recomp o PCSX2, regenera el
parche correspondiente con `git diff` sobre el commit fijado.

