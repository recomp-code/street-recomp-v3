# NBA Street V3 — port nativo para PC y Mac

[English](README.md) | **Español**

Juega a **NBA Street V3** (PS2) como un programa nativo en **Windows** y **macOS (Apple Silicon)**:
alta resolución, texturas HD, mando y **online funcionando**. El juego se recompila a código nativo con
[PS2Recomp](https://github.com/ran-j/PS2Recomp) y se dibuja en tu GPU con el render de
[PCSX2](https://github.com/PCSX2/pcsx2).

> **Necesitas tu propia copia** de NBA Street V3 (USA, SLUS-21126) en un archivo ISO. No se incluye
> nada del juego: se compila en tu ordenador a partir de tu copia.

| | |
|---|---|
| ![Pantalla de título](docs/screenshots/title.jpg) | ![Menú principal](docs/screenshots/menu.jpg) |
| ![Salto inicial](docs/screenshots/tipoff.jpg) | ![Mate](docs/screenshots/match.jpg) |

**[▶ Video comparativo PS2 vs. este port](docs/videos/comparison.mp4)**

## Características

- **Nativo en Windows (x64) y macOS (Apple Silicon, arm64).** El código del juego se recompila a código
  nativo: no hay emulador de CPU mientras juegas.
- **Velocidad completa:** partidos a 60 fps.
- **Gráficos modernos:** hasta 8x de resolución interna (5K), filtrado de texturas, 16:9, pantalla
  completa. Windows: Vulkan, Direct3D 11/12 u OpenGL, con AMD FSR 1 o NVIDIA DLSS. Mac: Metal.
- **Texturas HD** (pack de fans, se instala solo en Windows).
- **Online** contra un servidor de la comunidad, sin configurar el router.
- **Mando** y teclado (Windows: tipo Xbox/XInput; Mac: Xbox, PlayStation o MFi).
- **Menú gráfico en el juego:** F1, Back+Start o mantener START 1,5 s.
- **Partidas guardadas** normales en una memory card emulada.

## Jugar en Windows

1. Descarga **`NBAStreetV3-PC-<versión>.zip`** de
   [**Releases**](https://github.com/recomp-code/street-recomp-v3/releases/latest) y descomprímelo.
2. Doble clic en **`Launcher.cmd`**, pulsa **Browse...** y elige tu ISO.
3. Pulsa **Prepare game** (solo una vez: descarga las herramientas y compila el juego, 1-2 horas).
4. Pulsa **PLAY**.

## Jugar en Mac

Necesitas un Mac con **Apple Silicon** (M1 o posterior), **macOS 14.4** o superior, unos **30 GB**
libres y:

```sh
xcode-select --install                     # herramientas de línea de comandos de Apple (una vez)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"   # Homebrew, si no lo tienes
```

Después:

```sh
mkdir -p ~/NBAStreetRecomp && cd ~/NBAStreetRecomp
git clone https://github.com/recomp-code/street-recomp-v3.git nbastreet-v3-recomp
nbastreet-v3-recomp/tools/macos/install.sh ~/Downloads/NBAStreetV3.iso    # una vez, ~1 hora
nbastreet-v3-recomp/tools/macos/play.sh                                    # jugar
```

`install.sh` descarga las fuentes y compila el render y el juego a partir de tu ISO. Vuelve a
ejecutarlo después de un `git pull` para actualizar.

## Controles

| | Windows | Mac |
|---|---|---|
| Cruceta / stick izquierdo | Flechas / WASD | Flechas / WASD |
| Cuadrado, Cruz, Círculo, Triángulo | Z, X, C, V | Z, X, C, V |
| L1, R1, L2, R2 | Q, E, 1, 3 | Q, E, 1, 3 |
| START / SELECT | Enter / Retroceso | Return / Delete |
| Menú gráfico | F1 | F1 |
| Pantalla completa | Alt+Enter o F11 | Option+Return o Ctrl+Cmd+F |

Mando: A = Cruz, B = Círculo, X = Cuadrado, Y = Triángulo.

## Online

En el juego: **PLAY ONLINE** → **YES** → **"1 - NBA Street Online (DHCP)"**. La primera vez crea una
cuenta (cualquier e-mail; **no reutilices una contraseña real**) y una **persona**, y luego un
**baller online**. **PLAY** → **PICKUP GAMES** → **PLAY NOW** te empareja con el siguiente jugador.

## Para desarrolladores

| Ruta | Qué es |
|---|---|
| `patches/ps2recomp.patch` | Cambios sobre PS2Recomp `2c5fbb9` (recompilador, runtime, IOP, red, audio, macOS) |
| `patches/pcsx2.patch` | Cambios sobre PCSX2 `d073d75` (render en vivo `pcsx2-gsrunner -live`, ventana de macOS, microVU arm64) |
| `game/` | Configuración del recompilador para SLUS-21126, arreglos del juego, configuración de red |
| `tools/` | Scripts de Windows (`install.ps1`, compilación, depuración, texturas) |
| `tools/macos/` | Scripts de Mac (`install.sh`, `play.sh`, `build.sh`, `build_pcsx2.sh`, `run_scripted.sh`) |
| `docs/BUILDING.es.md` | Compilación manual en Windows, texturas HD, cómo funciona el online |
| `docs/PORTING_NOTES.md` | Notas técnicas: arquitectura y cada bug corregido |

Nunca subas archivos del juego (ISO, ELF, código generado, texturas extraídas, partidas).

## Licencia y créditos

GPL-3.0, igual que PS2Recomp y PCSX2. Basado en [PS2Recomp](https://github.com/ran-j/PS2Recomp) de
ran-j y colaboradores y en [PCSX2](https://github.com/PCSX2/pcsx2) (GS, microVU, DEV9). La versión de
Mac ejecuta el VU1 con el recompilador microVU arm64 de [ARMSX2](https://github.com/ARMSX2/ARMSX2).
NBA Street V3 es propiedad de Electronic Arts; este proyecto no está afiliado a EA y no incluye
contenido del juego.
