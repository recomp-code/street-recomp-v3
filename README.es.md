# NBA Street V3 — port nativo para PC y Mac

[English](README.md) | **Español**

Juega a **NBA Street V3** (PS2) como un programa nativo en **Windows** y **macOS (Apple Silicon)**, o
en el **navegador** (experimental): alta resolución, texturas HD, mando y **online funcionando**. El juego se recompila a código nativo con
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
- **NVIDIA DLSS bien hecho** (Vulkan y Direct3D 12): la profundidad real del juego y vectores de
  movimiento calculados en la GPU, así DLSS acumula detalle entre fotogramas; una máscara mantiene
  nítidas las piernas en movimiento rápido. En Direct3D 12 es una integración DLSS estándar que los
  add-ons de DLSS pueden enganchar. El launcher muestra la versión de DLSS y puede usar otro `nvngx_dlss.dll` (avisa antes de usar un archivo que no sea el DLSS firmado por NVIDIA).
- **Sonido fiel:** el SPU2 de PCSX2 (reverb, interpolación, barridos de volumen) mezcla el audio.
- **Texturas HD** (pack de fans, se instala solo en Windows).
- **Online** contra un servidor de la comunidad, sin configurar el router.
- **Mando** y teclado (Windows: tipo Xbox/XInput; Mac: Xbox, PlayStation o MFi).
- **Menú gráfico en el juego:** F1, Back+Start o mantener START 1,5 s.
- **Partidas guardadas** normales en una memory card emulada.
- **Versión para navegador (experimental):** el mismo juego recompilado, en WebAssembly, a 60 fps en
  Chrome o Firefox, con sonido, mando, texturas HD y **online**. El disco llega bajo demanda: solo se
  descargan las partes que el juego usa, nunca la ISO completa. Mira [qué hace](#qué-hace-la-versión-de-navegador).

## Jugar en Windows

1. Descarga **`NBAStreetV3-PC-<versión>.zip`** de
   [**Releases**](https://github.com/recomp-code/street-recomp-v3/releases/latest) y descomprímelo.
2. Doble clic en **`Launcher.cmd`**, pulsa **Browse...** y elige tu ISO.
3. Pulsa **Prepare game** (solo una vez: descarga las herramientas y compila el juego desde tu ISO,
   cerca de 1 hora; la ventana muestra los bloques compilados y el tiempo que falta).
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

`install.sh` instala con Homebrew lo que falte (CMake, Ninja, FFmpeg), descarga las fuentes y compila el render y el juego a partir de tu ISO. Vuelve a
ejecutarlo después de un `git pull` para actualizar.

## Jugar en el navegador (experimental)

Se compila en un Mac que ya hizo la instalación de arriba (reutiliza el código del juego hecho con tu
ISO). Solo para ti: sírvelo en tu ordenador o en un servidor privado, nunca en público.

```sh
nbastreet-v3-recomp/tools/web/build.sh      # una vez: Emscripten, FFmpeg, render de Play!, el juego (1-3 horas)
nbastreet-v3-recomp/tools/web/serve.sh      # después abre http://localhost:8088 en Chrome o Firefox
```

### Qué hace la versión de navegador

- **Streaming rápido, sin instalar:** el disco de 4,7 GB nunca se descarga entero. Se lee en trozos
  de 1 MB (HTTP Range) según el juego los pide. La lectura anticipada sigue cada stream (videos,
  música) y solo crece cuando el lector de verdad avanza por el disco. Un arranque en frío descarga
  unos 60 MB en los primeros 30 s, de los que 23,5 MB son el código del juego (Brotli, 280 MB sin comprimir).
- **Arranque fiable:** cada lectura del disco tiene un plazo y se reintenta (una conexión muerta tras
  un cambio de red ya no deja el juego en "Arrancando el juego…"), y las lecturas del disco no pasan
  por la caché HTTP del navegador, que hacía esperar en fila a las peticiones del archivo del disco.
- **Segunda visita al instante:** el navegador guarda el código del juego, y los trozos del disco ya
  leídos quedan en su Cache Storage entre visitas. Las lecturas del disco van en segundo plano: el
  juego nunca se congela esperando a la red.
- **60 fps con varios hilos:**
  - WebGL2 corre en su propio hilo (OffscreenCanvas);
  - un hilo trabajador ejecuta la unidad vectorial del PS2 (VU1, con un JIT a WebAssembly) y el GIF;
  - el hilo del juego duerme en los bucles de espera de cuadro del propio juego en vez de girar en
    vacío, lo que ahorra batería;
  - el flujo de gráficos entre el hilo del juego y el de la VU1 es un anillo sin bloqueos con orden
    de memoria acquire/release (en teléfonos ARM y Apple silicon una versión más débil podía leer un
    paquete viejo y congelar la imagen).
- **Código del juego más rápido:** el juego recompilado está afinado para WebAssembly: los registros
  se leen y escriben como valores de 64 bits en vez de vectores de 128, las llamadas entre funciones
  del juego toman un camino corto y el enlace final va totalmente optimizado (`-O3`). En un partido,
  en un Mac con chip M, el hilo del juego pasó de ~48% a ~31% de ocupación y el de la VU1 de ~62% a
  ~52%, que es lo que permite a los teléfonos más lentos ir al día. Cuando el juego cambia los
  microprogramas de la unidad vectorial (varias veces por cuadro) se reutilizan sus bloques ya
  compilados en vez de analizarlos otra vez.
- **Sin tirones por shaders:** todas las variantes de shaders gráficos que usa el juego se compilan
  durante las pantallas de carga, en segundo plano donde el navegador lo permite
  (`KHR_parallel_shader_compile`), en vez de a mitad de un cuadro (eso tardaba hasta ~1 s en algunos
  teléfonos). Las variantes que aparecen en un dispositivo se recuerdan (IndexedDB) y se compilan por
  adelantado en la siguiente visita.
- **Gráficos nítidos:**
  - resolución interna de 1x a 4x;
  - **AMD FidelityFX Super Resolution 1** (FSR 1: escalado EASU que sigue los bordes + nitidez RCAS)
    cuando la ventana es más grande que la imagen renderizada, por ejemplo en teléfonos a 1x: más
    nítido que el escalado normal sin costo medible (activado por defecto, ajuste "Escalado");
  - mezclas, efectos de framebuffer y paletas exactos portados a WebGL2;
  - pantalla completa.
- **Texturas HD:** el pack de fans en formato PCSX2, reconocido con el mismo hash de texturas de PCSX2
  y cargado imagen por imagen cuando el juego la muestra (el navegador la decodifica en otro hilo).
  También se reconocen las texturas dibujadas con una región de clamp (textos de menús y del HUD,
  nombres `<hash>-r<an>x<al>-…`), con el hash de región de PCSX2. El pack cubre unas 240 texturas
  distintas (camisetas, objetos de las canchas, algunos textos de menú), así que la mayor parte de
  la imagen queda con el detalle original del juego.
- **Sonido limpio:**
  - el SPU2 (procesador de sonido) de PCSX2: reverberación, ruido, modulación de tono, los tiempos
    de DMA del hardware e interpolación gaussiana, con un limitador de picos a la salida;
  - sale por un AudioWorklet con búfer adaptativo;
  - el tiempo emulado avanza de forma continua y el IOP va al paso del EE, así que la música, los
    comentarios y el sonido de los vídeos nunca se repiten, zumban ni chasquean.
- **Online:** el mismo servidor de la comunidad que la versión de PC. El adaptador de red del juego
  habla por un solo WebSocket con un pequeño relay (`tools/web/net_relay.py`) que solo puede llegar al
  servidor del juego.
- **Mandos y teclado:** cualquier mando del navegador (estándar o no) y teclado.
- **Partidas guardadas:** quedan en el navegador (OPFS) entre visitas.
- **Ajustes en la pantalla de inicio:** resolución, escalado FSR, imagen a 60/30 fps, texturas HD,
  búfer de sonido, online.
- **Diagnóstico:** un botón "Enviar diagnóstico" manda al servidor el navegador, la GPU, datos del
  sonido y las últimas líneas del registro (`tools/web/diag_server.py`, opcional), para estudiar
  dispositivos lentos.
- **Funciona en** Chrome y Firefox de escritorio y en Chrome de Android. Los teléfonos empiezan en
  resolución 1x y con más búfer de sonido.

- Pulsa **Jugar** (los navegadores solo permiten sonido tras un clic). La primera carga descarga el
  código del juego (~24 MB comprimido) y luego el navegador lo guarda; el disco llega en trozos de
  1 MB según se necesita.
- Teclas como en la tabla de abajo (START = Enter, SELECT = Retroceso); los mandos también funcionan.
  `?scale=1..4` fija la resolución interna (2 por defecto, 1 en teléfonos), `?debug` muestra
  estadísticas del render.
- **Ajustes en la pantalla de inicio** (se guardan en el navegador): resolución interna, escalado
  (FSR 1 o bilineal), cuadros por segundo de la imagen, texturas HD (el pack de fans, leído imagen
  por imagen según el juego las muestra; activas por defecto), búfer de sonido y online. También
  como parámetros: `?scale=1..4`, `?fsr=0/1`, `?fps=30`, `?hd=0/1`, `?audio=stable|normal|low`,
  `?online=0/1`.
- **El online funciona:** la red del juego va por un WebSocket (`/net`) a `tools/web/net_relay.py`
  en el servidor, que solo llega al servidor del juego. La configuración de red se pone en la
  memory card del navegador la primera vez.
- Las partidas se guardan en el navegador (OPFS).
- En un servidor hacen falta HTTPS y las cabeceras COOP/COEP: mira `tools/web/Caddyfile.server`.

Cómo funciona: el runtime y el juego corren en hilos de WebAssembly; los gráficos del PS2 (GS, VIF1,
VU1) se dibujan con el render del emulador [Play!](https://github.com/jpd002/Play-) sobre WebGL2, con
arreglos para los efectos que WebGL no tiene, texturas HD y FSR 1 (`patches/play.patch`) y un JIT de
VU1 más rápido (registros en locales de wasm, `patches/play-codegen.patch`); el sonido del SPU2 va a un
AudioWorklet. Detalles técnicos (parches, actualizar, medir): [docs/BUILDING.es.md](docs/BUILDING.es.md#versión-de-navegador-webassembly).
Piezas del servidor: el online necesita `tools/web/net_relay.py` y el botón de
diagnóstico `tools/web/diag_server.py` (ambos se configuran como indica `tools/web/Caddyfile.server`).

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
| `patches/ps2recomp-web.patch` | Versión de navegador, encima de `ps2recomp.patch` (Emscripten, plataforma web, host GS de Play!) |
| `patches/play.patch`, `play-dependencies.patch`, `play-codegen.patch` | Cambios sobre Play! `83700b2c` (arreglos del GS en WebGL2, texturas HD, excepciones wasm, JIT de VU) |
| `tools/web/` | Versión de navegador (`build.sh`, `serve.sh`, configuraciones de Caddy) |
| `docs/BUILDING.es.md` | Compilación manual en Windows, texturas HD, cómo funciona el online |
| `docs/PORTING_NOTES.md` | Notas técnicas: arquitectura y cada bug corregido |

Nunca subas archivos del juego (ISO, ELF, código generado, texturas extraídas, partidas).

## Licencia y créditos

GPL-3.0, igual que PS2Recomp y PCSX2. Basado en [PS2Recomp](https://github.com/ran-j/PS2Recomp) de
ran-j y colaboradores y en [PCSX2](https://github.com/PCSX2/pcsx2) (GS, microVU, DEV9). La versión de
Mac ejecuta el VU1 con el recompilador microVU arm64 de [ARMSX2](https://github.com/ARMSX2/ARMSX2).
NBA Street V3 es propiedad de Electronic Arts; este proyecto no está afiliado a EA y no incluye
contenido del juego.
