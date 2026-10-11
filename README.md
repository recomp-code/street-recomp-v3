# NBA Street V3 — port nativo para PC (PS2Recomp + render de PCSX2)

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

## Requisitos

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
DEV9 emulado, `PS2X_NET=1`) pero necesita un servidor de lobby que no forma parte de este repositorio.

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
