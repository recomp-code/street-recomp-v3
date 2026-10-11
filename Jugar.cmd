@echo off
rem Lanza NBA Street V3 recompilado con el render de PCSX2 (Vulkan por defecto).
rem Controles teclado: flechas = cruceta, WASD = stick, Z/X/C/V = Cuadrado/Cruz/Circulo/Triangulo,
rem Q/E = L1/R1, 1/3 = L2/R2, Enter = START, Retroceso = SELECT, Alt+Enter o F11 = pantalla completa.
rem Mando Xbox/compatible: A=Cruz, B=Circulo, X=Cuadrado, Y=Triangulo.
rem Menu grafico (resolucion, filtro, renderizador, texturas HD): F1, Back+Start o mantener START 1,5 s.
rem Calidad: C:\NBAStreetRecomp\gshost\nba_street.ini. Para jugar en ventana quita -fullscreen abajo.
setlocal
set PS2X_GS_LIVE=1
if "%PS2X_GSHOST_ARGS%"=="" set PS2X_GSHOST_ARGS=-renderer vulkan -ini nba_street.ini -fullscreen
if not exist C:\NBAStreetRecomp\logs mkdir C:\NBAStreetRecomp\logs
cd /d C:\NBAStreetRecomp\game\iso
"C:\NBAStreetRecomp\PS2Recomp\out\build\ps2xRuntime\Release\ps2EntryRunner.exe" "C:\NBAStreetRecomp\game\iso\SLUS_211.26" > "C:\NBAStreetRecomp\logs\jugar.log" 2> "C:\NBAStreetRecomp\logs\jugar_err.log"
