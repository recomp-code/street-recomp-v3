# Notas de port: NBA Street V3 (SLUS_211.26) con PS2Recomp

Registro de todo lo aprendido para portar más juegos de PS2 con el mismo método.
Ruta base: `C:\NBAStreetRecomp`. Nunca subir la ISO, el ELF ni assets del juego.

## 1. Arquitectura final

```
 ps2EntryRunner.exe (juego recompilado a x64, C++)            pcsx2-gsrunner.exe -live (fork de PCSX2 2.9)
 ┌──────────────────────────────────────────────┐            ┌─────────────────────────────────────────┐
 │ EE: código del juego recompilado (src\runner) │  anillo    │ VIF1 + microVU1 (recompilador x86 de VU) │
 │ kernel/IOP/SPU2/CD/MPEG emulados (HLE + IOP)  │  memoria   │ GIF unit (PATH1/2/3)                     │
 │ VIF1 local solo para IRQs/i-bit (no VU)       │──────────▶ │ GS Vulkan (upscaling, 4K)                │
 │ PATH3 (texturas) ensamblado en paquetes GIF   │ compartida │ ventana, teclado, mando (XInput), menú F1│
 └──────────────────────────────────────────────┘ ◀────────── └─────────────────────────────────────────┘
                                                   pad / menú abierto / salir
```

* El anillo (`ps2_live_ring.h` == `pcsx2\pcsx2\Ps2LiveRing.h`, deben ser idénticos) lleva un flujo con el
  formato de dump de GS de PCSX2 (Transfer/VSync/Registers/ReadFIFO2) más paquetes propios:
  `0x10` = datos VIF1 crudos, `0x11` = escritura de registro VIF1 (FBRST/ERR/MARK).
* El VU1 corre en el host (microVU): el intérprete VU1 del runtime era ~230 ns/ciclo (3–4 fps en partido).
* Lanzador: `Jugar.cmd`. Calidad: `gshost\nba_street.ini` (lo reescribe el menú F1 / Back+Start / mantener START 1,5 s del mando).

## 2. Pipeline de recompilación

1. Extraer ISO (7-Zip), ELF `SLUS_211.26`.
2. Ghidra (headless) + extensión EE -> `functions.csv`; `tools\fix_functions_csv.ps1` (finales de función
   falsos), `tools\find_gap_entries.ps1` (entradas en huecos, solo en límites reales de función).
3. `ps2_recomp.exe game\config\config.toml` -> `game\output\*.cpp`; **la copia que se compila es
   `PS2Recomp\ps2xRuntime\src\runner`** (parchear ambas si se corrige código generado a mano).
   Parches sobre código ya generado (innecesarios si se regenera con el recompilador actual, pero
   idempotentes): `fix_sqrt_s.ps1`, `fix_branch64.ps1`, `fix_dnas_skip.ps1` (este siempre, es del juego).
4. Build: `tools\build_runner_only.cmd` (incremental, ~5 min; si cambia un header del PCH ~45 min).
   PCSX2: `tools\build_pcsx2.cmd pcsx2-gsrunner` y copiar el exe a `gshost\`.

## 3. Herramientas de depuración que pagaron

| Variable / herramienta | Uso |
|---|---|
| `PS2X_VERIFY=N`, `PS2X_VERIFY_FROM=s` | verificador diferencial: cada función recompilada vs intérprete. Encontró el bug de SQRT.S (física). Ruido esperable: funciones que leen reloj/HW. |
| `PS2X_PROFILE=1` + `tools\profile_report.ps1` | muestreo del hilo EE; `[prof:ext]` = llamador en el exe de las esperas del SO |
| `PS2X_CALL_HIST=ini,dur,archivo` | conteo de llamadas (p.ej. bucle de frame = fps lógicos) |
| `PS2X_PEEK="addr;..."` | vigilar memoria del juego (¡los valores son hex!) |
| `PS2X_SCHED_STATS=1` | tiempo ocioso/pacing del planificador EE |
| `PS2X_VU_STATS=1` | ciclos VU por segundo y ns/ciclo |
| `PS2X_CMP_MSCAL`, `PS2X_CMP_PATH1` | volcar memoria VU1 / salida PATH1 local vs host para comparar |
| `PS2X_HOST_TRACE_GS=archivo` | secuencia (path, tamaño, hash) de paquetes que recibe el GS -> diff entre modos |
| `PS2X_HOST_DUMP_PACKET_SIZE`, `tools\gif_parse.ps1` | capturar y decodificar paquetes GIF |
| `PS2X_FPS_LOG=1` (host) | FPS interno de PCSX2 cada 5 s en emulog |
| `PS2X_PAD_LOG=1` | lo que el juego lee del pad |
| crash del host | `Documents\PCSX2\crash-*.txt` (pila, registros, nota del último paquete GS) + llvm-symbolizer |
| `tools\decomp.cmd` | descompilar funciones del ELF con Ghidra (`d:0xADDR x:0xADDR ...`) |
| `tools\run_with_keys.ps1 -Live` | correr, pulsar teclas (ENTER/X/Z/C/V/F1/flechas) y capturar la ventana |

## 4. Bugs encontrados (síntoma -> causa -> arreglo)

### Recompilador
* **Física rota (shorts estirados, salto raro)** -> `SQRT.S` de la R5900 usa el campo *ft*, el traductor usaba *fs*.
  Arreglado en `fpu_translator.cpp` + `tools\fix_sqrt_s.ps1 -Dir <dir>` (144 sitios). Revisar en otros juegos
  todas las instrucciones con codificación propia del EE (RSQRT.S fd,fs,ft; VU0 macro VDIV/VSQRT ftf/fsf).
* **Create Baller se queda en LOADING (salto a 0x0 en 0x581D88)** -> `BLEZ/BGTZ/BLTZ/BGEZ` (+likely/AL) se
  generaban con `GPR_S32` (palabra baja) y el R5900 compara los **64 bits**. El comparador del qsort de la
  tabla de archivos de EA hace `LWU`+`LWU`+`DSUBU`+`BLTZ`: con 32 bits, 0x00BC4343-0xFE9E617A "era positivo",
  la tabla quedaba desordenada, la búsqueda binaria no encontraba `/XF/PLAYER2X.BH`, el índice no cargaba
  (`CFILEBIG: xf/player2x.viv FAIL`), las texturas `2x…` de la cabeza medían 0 y la textura compuesta pedía
  1,7 MB a un pool -> NULL -> vcall a 0. Arreglado en `control_flow_emitter.cpp` + `tools\fix_branch64.ps1`
  (11450 ramas). El intérprete ya usaba 64 bits. **Buscar en cada juego** cualquier condición que use solo
  32 bits donde el EE usa 64 (SLT/SLTI ya usan 64; revisar MOVZ/MOVN, BEQ/BNE ya usan 64).
* Cómo se encontró: `PS2X_IOP_RAM_DUMP` (volcado de RAM + registros en el primer salto a nulo),
  `PS2X_NBA_ASSET_TRACE=1` (peticiones del gestor de assets, índices `.bh`, y el printf de depuración vacío
  del juego 0x3C0A68 reactivado: `CFILE/CFILEBIG ... OK/FAIL`). Ojo al envolver funciones: el planificador
  puede cortar una función a mitad (`eeCheckpointDue`) y retomarla después; registrar solo si `pc == ra`.
* Antes: VRSQRT, VSQRT |x|, VDIV/0 -> FLT_MAX, DIV/0, RSQRT, CVT.W.S truncado, VCLIP, MMI 128-bit, vf0=(0,0,0,1).

### Kernel / tiempo
* **Front-end congelado** -> COP0 Count no avanzaba; `ps2UpdateCop0Count` (rdtsc a 294.912 MHz).
* **VBlank lento** -> el bucle de espera no avanzaba; saltar el tiempo emulado al plazo vencido.
* **Deadlocks aleatorios** -> el juego usa `-1` como "sin dueño" en un lock recursivo por GetThreadId; los
  hilos virtuales de callbacks empezaban en -1. Ahora empiezan en -100.
* **Callback de MPEG (NODATA) ejecutado encima de otro hilo** dentro de su sección crítica -> los callbacks
  "síncronos" se marcan con su llamador (`'CALL'<<32|tid`), GetThreadId devuelve el llamador y nunca se
  insertan sobre un hilo en ejecución; si el callback no trae datos, GetPicture vuelve sin imagen.
* IOP a 1 ciclo por despacho (20% del tiempo) -> rebanadas de 256 ciclos.

### Pad
* **Botones de acción/gatillos no funcionan en partido (sí en menús)** -> con presión activa el DualShock 2
  reporta modo `0x79`; respondíamos `0x73` y el juego ignoraba las presiones. Orden de presión: R,L,U,D,△,○,✕,□,L1,R1,L2,R2.

### VIF/GIF/GS en el host (PCSX2)
* El replayer de dumps mapea `path-1` (Path2->GIF_PATH_1...). En modo live eso metía nuestro PATH3 en el
  buffer que usa el GIF unit para los DIRECT del VIF -> corrupción de heap, objetivos gigantes, basura. Mapear bien.
* `HashBucket::find` comparaba claves antes de detectar la celda terminadora -> unpack con clave 0 saltaba a 0.
* `GSState::Transfer`: underflow de `size`/`total` al retomar un tag PACKED a mitad de loop.
* `WriteImage` PSMT4 ancho impar ignoraba `len`; `Target::Update` desbordaba el buffer de 9 MB.
* Sin BIOS, VIF1 CYCLE arranca en 0 -> inicializar CL=WL=1 (si no, los datos de UNPACK se leen como VIFcodes).
* Reenviar escrituras a VIF1 FBRST/ERR/MARK al host.
* microVU solo recarga MXCSR si difiere del FPCR del EE: fijar `FPUFPCR` en el hilo del replayer.
* PATH3 llega en trozos DMA: ensamblarlo en paquetes GIF completos (EOP) antes de mandarlo, para no
  intercalar PATH1/2 en medio de una transferencia de imagen.

### MPEG/memcard/IOP (ver historial)
NODATA callback, sceMpegIsEnd (escribir el flag), memcard GetDir, SPU2, etc.

## 5. Optimizaciones que importaron
1. VU1 al host (microVU): 3.5 -> 30+ fps en partido.
2. `processPendingEvents` con camino rápido (sin mutex/reloj/deque si no hay nada): ~14%.
3. Cadena VIF1 parada con offset en vez de copiar el resto en cada i-bit: ~15%.
4. No hacer en local lo que hace el host: UNPACK a memoria VU local, subidas de texturas del GS local.
5. Reservar los buffers de cadenas DMA por canal; logs calientes fuera (`[cd:read]`, SIF DMA).
6. COP0 Count bajo demanda: el `mfc0 $9` generado llama a `ps2UpdateCop0Count` (cop0_translator.cpp,
   `tools\fix_cop0_count.ps1`) en vez de actualizarlo en cada despacho: −9%.
7. Timers del EE en bloques de 512 ciclos (`advanceEeTimers`): 5.4% -> 1.4%.
8. GS local: sin `BeginTransfer`/subidas en modo live.
Resultado: partido a 58–60 fps internos con ~20% del hilo EE ocioso (el juego está hecho para 60; menús a 30 por diseño).

### 5.1 Bajadas a 56–58 fps en partido (segunda ronda)
Medir antes de tocar: `PS2X_NBA_FRAME_LOG=1` (override en 0x003E3920, la espera de vsync del juego:
trabajo por fotograma, CPU del hilo EE y reparto IOP/VIF1), `PS2X_THREAD_STATS=1` (tiempo por hilo
guest), `PS2X_PROFILE=1` (con `[prof:pc]`: el pc guest exacto, porque el código generado actualiza
`ctx->pc` en cada instrucción) y `PS2X_IOP_PC_STATS=1` (pc/ra/hilo del IOP). `tools\mipsdis.ps1`
desensambla volcados de RAM (IOP o EE).
- El hilo principal usa ~95% del hilo EE y el fotograma va justo (~16 ms de 16,7). El render (host)
  no es el problema (~28% ocupado).
- **Hilo del juego colgado en un bucle de error (intermitente)**: las esperas de fin de fotograma
  0x003E1910 (VIF1 hasta la etiqueta END) y 0x003E1530 (GIF) cuentan *iteraciones* (límite en
  0x005B5E28 = 300000000/200 = 1,5 M sondeos, ~1 s en PS2 con lecturas de bus lentas, ~150 ms aquí).
  Si la IRQ a mitad de la cadena VIF1 (lectura GS->EE que reanuda el handler DMAC 0x003E1358) se
  atiende más tarde, el juego da timeout y ese hilo gira para siempre en 0x003E10F8 robando CPU el
  resto de la sesión (partidas a 45–53 fps). Override: límite ilimitado antes de cada espera.
- **El IOP se comía ~20% del hilo EE**, y no por ejecutar código: `accountCycles` llamaba a
  `advanceIopEeCycles` en cada punto de control generado (~7,6 millones de veces/s) aunque el IOP solo
  avanza por tramos de 8192 ciclos EE. Ahora el planificador acumula y llama por tramos: 20% -> 6%.
- Del código IOP, ~55% era el **mezclador software del driver de sonido de EA** (IOP 0x52D50:
  remuestreo 3:4 de 2x2 bloques de 256 muestras con saturación). Sustituido por una versión nativa
  (`ps2xIOP/src/emulator/iop_hle_routines.h`), activa solo si las instrucciones coinciden y cobrando
  los mismos ciclos IOP. `PS2X_IOP_HLE=verify` ejecuta el original y compara la RAM byte a byte:
  0 diferencias en 15000 llamadas. `PS2X_IOP_HLE=0` lo desactiva.
- Inlining forzado (`PS2_FORCEINLINE`) de los accesos a registros/memoria del código generado: en
  funciones gigantes MSVC dejaba llamadas reales con `__m128i` pasado por memoria.
- Anillo de render: `SetEvent` solo si el otro lado está dormido (flags en `Ps2LiveRing.h`); los
  paquetes PATH3 completos se envían sin copiarlos antes a un vector.
- Guarda de 4096 etiquetas por cadena DMA subida a 1M (solo protege de cadenas corruptas).
- Ojo al medir: la IA juega distinto en cada partida; una sola pasada no vale para comparar. Mirar
  los porcentajes de tiempo (estables) o promediar varias pasadas.
- Resultado: partidas normales a ~59 fps sin bucle de error. **Pendiente**: en escenas muy cargadas
  (listas VIF1 de >4300 etiquetas) el trabajo por fotograma pasa de 16,7 ms y el juego cae a 30
  durante unos segundos (rama "llego tarde" de 0x003E3920: pc 0x3E3DB0/0x3E3DC0 esperando el
  siguiente VSINT). ~16% del tiempo en esas escenas es nuestro procesado de la cadena VIF1 en el EE
  (0x3E24C8 arranque del DMA, 0x3E1214/0x3E1224 reanudación tras cada i-bit): recorrido + copia en
  `chainBuf` + `processVIF1Data` + copia al anillo. Siguiente paso: no copiar la cadena dos veces y
  analizar solo lo necesario para las paradas.

### 5.2 Reescalado FSR 1 / DLSS en el host
- FSR 1 (EASU+RCAS, compute) y DLSS (NGX Vulkan) se aplican al presentar, tras CAS
  (`GSDevice::Upscale`, ini `NbaUpscaler` 0/1/2). Bug de PCSX2: `SetSpecializationValue` del
  constructor de pipelines compute nunca guardaba el valor (cualquier shader con constantes de
  especialización salía de un color plano).
- DLSS no tiene vectores de movimiento (un PS2 no los genera): `InReset=1` en cada fotograma.
- Profundidad real para DLSS (`GSRendererHW::NbaTrackDepth/GetUpscalerDepth`): NBA Street dibuja
  el 3D en un búfer trasero (0x8C0, Z en 0x1A40) y lo copia al de pantalla (0). Como el host procesa
  el flujo GS en orden, al llegar el vsync el Z del último dibujo 3D es exactamente el del fotograma
  mostrado. Para juegos con intercambio de páginas se guarda una copia del Z cuando un dibujo con
  profundidad pasa a otro búfer de color, etiquetada con su dirección. El Z del PS2 crece hacia la
  cámara: flag `DepthInverted`. Log: `PS2X_DLSS_DEPTH_LOG=1`.

### 5.3 Grabar y reproducir una sesión (videos comparativos, capturas idénticas)
- Todo lo que el host necesita llega por el anillo (GS, VIF1 para microVU, vsyncs, registros), así
  que grabar esos bytes reproduce la sesión exacta sin el juego. `PS2X_LIVE_RECORD=<archivo>` en el
  entorno del juego (el host lo hereda) los guarda: ~85 MB/s, unos 15 GB por 3 minutos.
- `tools\play_capture.ps1 -Stream <archivo> -Ini <ini>` lo reproduce sin límite de velocidad
  (3 minutos de juego en ~25 s) con otros ajustes: `-Shots` (capturas por número de vsync),
  `-Video/-From/-Frames` (video con la captura de PCSX2; necesita las DLL de FFmpeg 8.x,
  avcodec-62, junto al exe, solo en local), `-ExitAt`, `-Window WxH` (`PS2X_HOST_WINDOW`).
- El video sale de la imagen final (tras CAS/FSR/DLSS, `m_nba_final`), no de la salida interna.
  En reproducción el modo de video del replayer no es fiable: la captura se abre a 59,94 fps fijos.
- `tools\sheet.ps1 -Dir <carpeta>` hace hojas de miniaturas para localizar escenas.
- Ruta de botones probada hasta un partido real: `97:START,101:CROSS,104:CROSS,...` (GAME ON + valores
  por defecto); el partido empieza hacia el vsync 7150 de la grabación.

### 5.4 DLSS en Direct3D 12 y add-ons de DLSS 5 (2026-10-19)
- DLSS también en D3D12 (`GSDevice12::DoUpscale/InitDLSS/DoDLSS`): mismas entradas que en Vulkan
  (color, Z real del juego con `DepthInverted`, MV a cero + `InReset=1`). Tras la evaluación hay
  que volver a poner los descriptor heaps de PCSX2 (NGX pone los suyos) e `InvalidateCachedState()`.
  La profundidad D3D12 (`D32_FLOAT_S8X24_UINT`) se le pasa tal cual y NGX la acepta.
- DLSS solo actúa si la salida es mayor que la resolución interna: con ventana 1280x960 y 16:9 la
  salida mide 720 px de alto y 2x interna son 896 → no se usa (`PS2X_HOST_WINDOW=1920x1080` en pruebas).
- Verificado con ReShade 6.8 (add-on) + RenoDX "DLSS 5 Neural Rendering" en una carpeta de host
  aparte: engancha `NVSDK_NGX_D3D12_CreateFeature/EvaluateFeature/ReleaseFeature` en las dos copias
  de NGX, "first NGX evaluate intercepted", ~14 000 evaluaciones en un partido, "injection admitted".
  El pase neural no corre porque falta el `nvngx_dlssnr.dll` firmado por NVIDIA (no se usa la copia
  comunitaria modificada: su firma da HashMismatch y el driver la rechaza, 0xBAD00002). Streamline
  público 2.14.16 solo reserva `kFeatureDLSS_NR = 1004`, sin API todavía.

### 5.5 Compilar el juego sin quedarse sin memoria
- 3123 bloques unity de 32 funciones (593 MB de C++). Algunos bloques piden hasta ~8 GB por
  compilador: con 24 a la vez en 32 GB Windows paginaba a disco (138 000 páginas/s) y no avanzaba.
  Con `/p:CL_MPCount=12 /m:1` (1 por ~2,5 GB de RAM; `tools\install.ps1` lo calcula) va a ~500
  bloques/min, salvo los bloques bajos con las funciones gigantes (2–4 min cada uno). Total ~1 h.
- Los parches de macOS/navegador no se habían compilado en Windows: a `gs_dump_writer.cpp` le
  faltaba `ps2x/host_intrin.h` (ps2xStatTicks); arreglado en `ps2recomp-web.patch`, que ahora
  también aplican `setup_sources.ps1` y el CI de Windows.

## Texturas HD (packs PCSX2) — qué NO reemplazar
* Volcado: menú del host -> "Texturas HD" -> "Activadas + volcar originales"; `tools\texturas_preparar.ps1`
  copia a `texturas_hd\originales`; el usuario reescala con IA a `texturas_hd\hd`; `tools\texturas_instalar.ps1`.
* Descartar (lo hace `texturas_preparar.ps1`, van a `texturas_hd\descartadas`):
  - tiras de vídeo 16x512 (fotogramas MPEG);
  - **capturas dinámicas**: texturas sin paleta (nombre de 2 campos) con aspecto de ruido. Son copias de
    pantalla/VRAM que el juego reescribe; reemplazadas, todo el menú sale con grano
    (aquí `e30f7fa96ac7861c-00001d80`, 64x128);
  - **invisibles** (alfa máx <= 3): datos volcados con una paleta ajena (aquí 942 con CLUT `334e9e57…`);
    reemplazadas, los iconos de botones salían como bloques.
* Diagnóstico sin mirar a ojo: `tools\shot_noise.ps1` (grano + diferencia con captura limpia en zonas fijas)
  y `tools\texturas_bisect.ps1` (bisección automática instalando subconjuntos con hardlinks; ~2 min/prueba).

## 7. Entorno / pantalla
* Cada instancia usa su propio anillo (`<nombre>_<pid>`, host con `-livering <pid>`); el host vigila el PID
  del juego y se cierra solo. Se puede jugar mientras corren pruebas.
* Host per-monitor DPI aware (si no, con escala de Windows la imagen se estira y se ve borrosa).
* El GS solo puede salir a la resolución que Windows ofrezca: si el monitor 4K aparece como 1920x1080
  (cable/puerto/TV), el render interno 4K se reduce a 1080p. Comprobar con EnumDisplaySettings.
* Monitor a 75 Hz con juego a 60 fps = tirones: usar 60 Hz.
* `tools\stack_snapshot.ps1 -ProcessId <pid>`: pilas de todos los hilos de un proceso colgado.

## 8. Modo online (EA Online con servidor propio)

Cadena completa que hizo falta (en este orden aparecieron los fallos):
1. **Adaptador de red DEV9/SMAP** en el IOP: código de red de PCSX2 (`ps2xIOP/src/emulator/dev9`,
   SMAP + NAT por sockets + DHCP/DNS internos) con cabeceras sustitutas (`dev9/shim`) y la unión
   `core/iop_dev9.*` (registros 0x10000000/0x1F80146E, IRQ 13 por nivel, DMA canal 8).
   `PS2X_NET=1` lo activa; `PS2X_NET_SERVER=ip` redirige los dominios de EA; `PS2X_NET_LOG=2` traza DHCP/DNS/TCP.
2. **IOP**: argv de los módulos (argv[0]=ruta, separados por NUL; NETCNF/INETCTL rechazaban los
   argumentos), modload 16/17/18/22/23, `look_ctype_table` (INET leía `mem=96KB` como no dígito),
   printf con formato real, `ioman` con archivos (mc0:/cdrom0:/host: al host, ignorando el MCMAN real),
   `sceCdRI`/`sceCdReadClock`, **alarmas de thbase** (SMAP vigila el enlace con SetAlarm: sin ellas no
   hay DHCP) y **`wmemcopy`/`wmemset` con tamaño en bytes** (copiar palabras corrompía INET).
3. **DNAS**: `tools\fix_dnas_skip.ps1` pone `DNASSKIP=1` (0x349968).
4. **Configuración de red** en la memory card (`mc0\BWNETCNF`): índice + `net000.cnf` en claro e
   `ifc000.dat`/`dev000.dat` cifrados (`tools\netcnf_encode.ps1`, clave del iLink ID = ceros).
   Reglas del juego/DirtySock: nombre de combinación con número ("Combination1"); **tipo `nic`** en
   ifc y dev (el juego solo acepta nic: crea su objeto de red con capacidades=1); el DISCOVER de Sony no
   pide opciones -> el DHCP interno debe mandar siempre máscara/router/DNS.
5. **Red del PC**: la PS2 trata 127.x como su loopback; el DNS da la IP del PC y la capa de sockets
   conecta a 127.0.0.1 cuando el destino es una IP de este PC.
6. **SSL**: la cadena `*ps2nbastreet05.ea.com,21000` (el `*`) usa SSLv2 RC4-MD5 al puerto 21001; el
   override quita el `*` al arrancar -> TCP en claro al 21000 (`PS2X_NBA_KEEP_SSL=1` lo deja).
7. **Servidor** `server\nbastreet_server` (C++, `build.cmd`): protocolo de lobby de EA (cabecera de 12
   bytes, cuerpo KEY=VALUE). Visto del juego: `@tic RC4+MD5-V2`, `@dir VERS=PS2/NBASTREET3 SKU=14758
   SLUS=1.10`, `addr` (puerto P2P 20089), `skey`, `news NAME=7` -> pantalla "Use Existing Account /
   Create New EA Online Account". Referencia del protocolo: a-blondel/ea-nation-server (en server\ref).
   Después: HTTP al puerto 80 (TOS_URL/NEWS_URL; sin él se queda en LOADING). La página de TOS debe ser
   `%{START CMD=news ... %}texto%{%}` (la pantalla TERMS AND CONDITIONS del juego añade Don't Accept/Accept);
   una página `CMD=alrt` se toma como rechazo. Keepalive `~png` del servidor cada 20 s desde la conexión
   (el cliente responde `~png TIME=n`, NO contestar a eso: bucle infinito); sin keepalive corta a los 40 s.
   `$exit=N` = resultado de la página (intérprete en 0x4EDD60: $http/$home/$quit/$exit=/$next).
8. **Cuentas y baller online**: `acct`/`auth` (cuenta), `cper`/`pers` (persona), y el perfil del baller:
   `cbal` (BVER/RECIPE/BDATA/BLOCK/ATTR0-9/COST) y `ccrt` (CVER/COURT/CLOCK) se guardan por persona en
   `server\nbastreet_server\profiles\` y se devuelven completos; `gbal` y `gpro PERS=x` los leen.
   Con respuesta vacía el juego dice "no tienes baller online". Memory card de EA (`PSCD10088slogin`)
   se abre con flags=0x200 (CREAT sin modo): tratar como RDWR o "Save failed".
9. **Partida rápida (PLAY NOW)** `gqwk SIZE=2 OPTIMATCH=0`: la RESPUESTA debe traer la partida (IDENT,
   NAME, PARAMS, COUNT, OPPOn, ADDRn...) o sale "There was a problem joining the game session". El
   servidor une a una partida rápida abierta o crea una; al llenarse manda `+mgm` y `+ses` (inicio).
   **PARAMS** = la estructura de ajustes del desafío (6 textos + 12 números por puesto + modo; tipo de
   partida 0x19 en +0xa0). Capturado del `gcre` del propio juego:
   `,,,,,,-1,-1,-1,-1,-1,-1,,2,1,1,1,1,,,,,19,20,20%0a` (Created Court, 3 on 3, World Challenge, Street
   Rules, Public). Sin tipo 0x19 el anfitrión no aporta su cancha -> ID de cancha -1 -> en la carga
   abre `%sBall.abk` inexistente -> salto a nulo en 0x1BBF40. El anfitrión de una partida rápida manda
   `gset PARAMS=<nombre>\n`: ignorarlo (machaca los ajustes).
10. **`SELF=<persona>`** en todo mensaje con datos de partida (gqwk/+mgm/+ses...): la librería de lobby
   lo lee para saber cuál es su entrada. Sin él cada PS2 toma OPPO0 como rival y el anfitrión se
   "conecta" consigo mismo -> "cancelled due to connection problems". (La referencia lo tenía comentado.)
11. **P2P por relay** (funciona tras cualquier router y con dos instancias en un PC): el juego hace P2P
   por UDP 3658->3658 a ADDRn y además hace ping (ICMP) al rival. El servidor da a cada PS2 (por la MAC
   de `acct/auth MAC=`) una IP virtual 10.200.x.y (A/LA de +who/pers y ADDRn/LADDRn). DEV9
   (`Sessions/UDP_Session/UDP_Relay.*`) manda el UDP a 10.200.x.x al servidor (UDP 21003, cabecera
   "NBR1" + IP/puertos + MAC; "NBRH" = hola cada 5 s) y entrega lo recibido como si viniera del rival;
   los ping a 10.200.x.x se contestan en DEV9. MAC distinta por instancia (hash de `PS2X_MC_ROOT`).
   `PS2X_NET_RELAY=0` lo apaga; servidor `--relay 0` da IPs reales.
12. **IOP sysclib `bcopy`/`memcpy` con solapamiento** (memmove): con copia hacia delante se colaban
   cabeceras TCP como datos en la conexión del lobby ("bad packet length" y desconexión).
13. Al empezar el partido el juego CIERRA la conexión del lobby (`sele ROOMS=0 USERS=0` y fin): normal.
Lanzadores: `Jugar_Online.cmd` y `Jugar_Online_2.cmd` (segunda instancia: `PS2X_MC_ROOT=mc0_p2`, mando
solo en la ventana activa). Pruebas: `tools\run_duo.ps1` (dos instancias con guion de botones, hoja
`tools\duo_sheet.ps1`). "New/Edit" en LOGIN lanza NTGUI (otro ELF): no soportado.
Ruta de menús online automatizada: `97:START,101:DOWN,102.5:DOWN,104:CROSS,107:DOWN,108.5:CROSS,124:CROSS,
146:CROSS,160:CROSS,170:CROSS,178:CROSS,184:CROSS` (+ `PS2X_PAD_SCRIPT_HOLD=120`) llega a PLAY NOW.
"MY COURT" crea una sala (`room NAME=@CIUDAD.persona`) y dentro "Create Challenge" manda `gcre`.

Herramientas: `tools\run_scripted.ps1` (botones inyectados `PS2X_PAD_SCRIPT`, capturas del host
`PS2X_SHOT_TIMES`, mando ignorado `PS2X_NO_GAMEPAD=1`; NUNCA teclas globales), `PS2X_IOP_IMPORT_TRACE=lo-hi`
(+ `_SKIP=libs`, con valores de retorno), `PS2X_IOP_IOMAN_LOG=1`, `tools\refpack_unpack.ps1` (IRX de MODULES.VIV).

## 6. Checklist para el siguiente juego
1. Pipeline del punto 2; arreglar entradas faltantes hasta que bootee.
2. Modo live desde el principio (`PS2X_GS_LIVE=1`), VU remoto por defecto.
3. Correr el verificador en cada fase nueva del juego (menús, carga, partida) y revisar diferencias grandes.
4. Perfilar con `PS2X_PROFILE`; mirar `[prof:ext]` antes de suponer.
5. Comparar flujos (VU1 / GS) entre modo local y remoto si hay basura gráfica.
