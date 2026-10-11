# NBA Street V3 — port nativo para PC (PS2Recomp + render de PCSX2)

[English](README.md) | **Español**

Recompilación estática de **NBA Street V3 (PS2, NTSC-U, SLUS-21126)** a un ejecutable nativo de
Windows x64 con [PS2Recomp](https://github.com/ran-j/PS2Recomp), con el render por GPU del GS de
[PCSX2](https://github.com/PCSX2/pcsx2) (Vulkan / Direct3D / OpenGL), resolución interna hasta 8x,
VU1 en microVU y paquetes de texturas HD compatibles con PCSX2.

> **Este repositorio NO contiene nada del juego**: ni ISO, ni ELF, ni código generado a partir de él,
> ni texturas. Necesitas **tu propia copia** de NBA Street V3 (SLUS-21126). El código C++ del juego se
> genera en tu PC a partir de tu ELF.

Contenido:

| Ruta | Qué es |
|---|---|
| `patches/ps2recomp.patch` | Cambios sobre PS2Recomp `2c5fbb9` (recompilador, runtime, IOP, red DEV9, SPU2...) |
| `patches/pcsx2.patch` | Cambios sobre PCSX2 `d073d75` (`pcsx2-gsrunner -live`: render en tiempo real del juego) |
| `game/config/` | Configuración del recompilador para SLUS-21126 (lista de funciones y direcciones) |
| `game/overrides/` | Ajustes específicos del juego (`nba_street_v3_overrides.cpp`) |
| `gshost/nba_street.ini` | Opciones gráficas por defecto |
| `tools/` | Scripts de preparación, compilación, depuración y texturas |
| `docs/PORTING_NOTES.md` | Notas técnicas: todos los bugs encontrados y cómo se arreglaron |
| `Jugar.cmd` | Lanzador |

## Para jugar (lo fácil): el launcher

1. Descarga `NBAStreetV3-PC-<versión>.zip` de **Releases** y descomprímelo donde quieras.
2. Abre **`Launcher.cmd`**:

   | Control | Qué hace |
   |---|---|
   | **Tu ISO... / Elegir...** | Elige tu ISO de NBA Street V3 (NTSC-U, SLUS-21126). Se recuerda. |
   | **Preparar juego** | Solo la primera vez: instala Visual Studio Build Tools, CMake y Git si faltan, extrae tu ISO en `C:\NBAStreetRecomp\game`, genera el C++ del juego desde tu ELF y lo compila. ~6 GB de descargas y 1-2 horas; el progreso sale en una ventana de consola ("Listo" = terminado). Después el botón pasa a **Reparar**. |
   | **Resolución interna** | Nativa 480p, 720p, 1080p, 1440p, 4K u 8x. |
   | **Renderizador** | Vulkan (recomendado), Direct3D 11, Direct3D 12 u OpenGL. |
   | **Pantalla completa** | Arranca a pantalla completa (Alt+Enter alterna en el juego). |
   | **Texturas HD** | Carga packs HD formato PCSX2 de `Documentos\PCSX2\textures\SLUS-21126\replacements`. |
   | **Jugar online** + **Servidor** | Activa el adaptador de red y elige el servidor (por defecto el de la comunidad, `nbas3.xellrecomp.party`). Desmárcalo para jugar sin red. |
   | **JUGAR** | Arranca el juego con esas opciones. |

   Las opciones gráficas se guardan en `C:\NBAStreetRecomp\gshost\nba_street.ini` y las del launcher en
   `%APPDATA%\NBAStreetV3Launcher.json`. En el juego: **F1**, **Back+Start** o **mantener START 1,5 s**
   abre el menú gráfico.

¿Por qué compilar? El ejecutable final contiene el código del juego traducido a C++, así que no se
puede distribuir. Todo lo distribuible (render de PCSX2, parches, herramientas) va en el zip.

`Jugar.cmd` hace lo mismo que **JUGAR** sin ventana (online por defecto; `set NBA_SERVER=off` para
jugar sin red o `set NBA_SERVER=<host o IP>` para otro servidor).

## Modo online

El servicio EA Online original del juego cerró hace años. Este port lo recupera:

- **Adaptador de red.** El adaptador de red de PS2 (DEV9/SMAP) se emula con el modo "sockets" de
  PCSX2: sin drivers, sin permisos de administrador, sin TAP/pcap. El juego obtiene IP por DHCP y sus
  nombres de EA (`ps2nbastreet05.ea.com`, etc.) se redirigen al servidor configurado.
- **Servidor.** Un servidor de la comunidad reimplementa el protocolo de lobby de EA: cuentas,
  personas, ballers online (guardados en el servidor), partidas rápidas (PLAY NOW) y montaje del
  partido. El código del servidor no está en este repositorio.
- **Tráfico del partido.** Las dos consolas hablan normalmente P2P por UDP. Aquí cada jugador recibe
  una IP virtual y todo el tráfico pasa por el relay UDP del servidor: **no hay que abrir puertos** en
  el router y funciona detrás de NAT/CGNAT. La latencia es tu ping al servidor más el del rival.
- **Configuración de red.** El launcher copia una configuración lista (`game/mc0_netcnf`) a la
  memory card emulada la primera vez que juegas online.

Cómo jugar un partido:

1. En el launcher deja **Jugar online** marcado y pulsa **JUGAR**.
2. En el juego: **PLAY ONLINE** -> **YES** -> **"1 - NBA Street Online (DHCP)"** -> conectar.
   No uses "New/Edit" en esa pantalla.
3. La primera vez: crea una cuenta EA (usuario de 4+ letras, cualquier e-mail y contraseña; solo se
   guardan en el servidor de la comunidad, no reutilices una contraseña real) y luego una **persona**.
4. Crea un **baller online** (Create Baller desde el menú online) y guárdalo.
5. **PLAY** -> **PICKUP GAMES** -> **PLAY NOW**. Te empareja con el siguiente jugador que haga lo
   mismo; el partido empieza cuando están los dos.

Problemas: "cannot resolve server" en `C:\NBAStreetRecomp\logs\jugar_err.log` = sin internet o DNS;
si se queda en "connecting", seguramente un firewall bloquea `ps2EntryRunner.exe` (TCP al servidor y
UDP 21003).

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

**7. Jugar:** `nbastreet-v3-recomp\Jugar.cmd` (cópialo donde quieras).

## Uso

- **Controles**: mando Xbox/compatible (XInput) o teclado (flechas, WASD, Z/X/C/V, Q/E, 1/3, Enter = START).
- **Menú gráfico** (resolución interna, filtro, renderizador, texturas HD): **F1**, **Back+Start** o
  **mantener START 1,5 s**. Se guarda en `gshost\nba_street.ini`.
- **Pantalla completa**: Alt+Enter o F11.
- **Partidas guardadas**: `game\iso\mc0\` (memory card emulada).
- **Texturas HD**: formato de PCSX2, en `Documentos\PCSX2\textures\SLUS-21126\replacements`.
  Ver `tools\texturas_preparar.ps1` / `texturas_instalar.ps1`: apartan solas las texturas que no se
  deben reemplazar (capturas dinámicas de pantalla y páginas invisibles), que estropean la imagen.

## Estado

Jugable de principio a fin en offline: menús, vídeos, Create Baller, partidos a 60 fps con física
correcta, audio (SPU2 emulado) y memory card. El modo online existe en el código (adaptador de red
DEV9 emulado) y se conecta al servidor de la comunidad; el código del servidor no forma parte de este repositorio.

Los bugs del recompilador encontrados (y corregidos en `patches/ps2recomp.patch`) están en
`docs/PORTING_NOTES.md`; varios afectan a cualquier juego de PS2 portado con PS2Recomp
(SQRT.S, saltos BLTZ/BGEZ de 64 bits, MMI, VU0...).

## Contribuir

Issues y pull requests bienvenidos. Antes de nada lee `docs/PORTING_NOTES.md`: explica la
arquitectura (runtime + host de PCSX2 por un anillo de memoria compartida), las herramientas de
depuración (`tools\run_scripted.ps1` para pruebas automáticas sin tocar el escritorio,
`PS2X_IOP_RAM_DUMP`, `tools\decomp.cmd` con Ghidra, etc.) y cada problema resuelto.

**Nunca** subas archivos del juego (ISO, ELF, código generado en `game\output` o
`ps2xRuntime\src\runner`, texturas extraídas, partidas). Para cambios en PS2Recomp o PCSX2, regenera el
parche correspondiente con `git diff` sobre el commit fijado.

## Licencia y créditos

GPL-3.0 (igual que PS2Recomp y PCSX2). Basado en
[PS2Recomp](https://github.com/ran-j/PS2Recomp) de ran-j y colaboradores y en
[PCSX2](https://github.com/PCSX2/pcsx2) (GS, microVU, DEV9). NBA Street V3 es propiedad de
Electronic Arts; este proyecto no está afiliado a EA y no distribuye ningún contenido del juego.
