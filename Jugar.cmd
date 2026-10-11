@echo off
rem Lanza NBA Street V3 recompilado (lo normal es usar Launcher.cmd).
rem Controles teclado: flechas = cruceta, WASD = stick, Z/X/C/V = Cuadrado/Cruz/Circulo/Triangulo,
rem Q/E = L1/R1, 1/3 = L2/R2, Enter = START, Retroceso = SELECT, Alt+Enter o F11 = pantalla completa.
rem Mando Xbox/compatible: A=Cruz, B=Circulo, X=Cuadrado, Y=Triangulo.
rem Menu grafico (resolucion, filtro, renderizador, texturas HD): F1, Back+Start o mantener START 1,5 s.
rem Online: activado por defecto contra el servidor de la comunidad (NBA_SERVER para cambiarlo,
rem NBA_SERVER=off para jugar sin red). En el juego: PLAY ONLINE -> YES -> "1 - NBA Street Online (DHCP)".
setlocal
if "%NBA_SERVER%"=="" set NBA_SERVER=nbas3.xellrecomp.party
set PS2X_GS_LIVE=1
if /i not "%NBA_SERVER%"=="off" (
  set PS2X_NET=1
  set PS2X_NET_SERVER=%NBA_SERVER%
  if not exist "C:\NBAStreetRecomp\game\iso\mc0\BWNETCNF\BWNETCNF" (
    mkdir "C:\NBAStreetRecomp\game\iso\mc0\BWNETCNF" 2>nul
    xcopy /Y /Q "%~dp0game\mc0_netcnf\BWNETCNF\*" "C:\NBAStreetRecomp\game\iso\mc0\BWNETCNF\" >nul
  )
)
if "%PS2X_GSHOST_ARGS%"=="" set PS2X_GSHOST_ARGS=-renderer vulkan -ini nba_street.ini -fullscreen
if not exist C:\NBAStreetRecomp\logs mkdir C:\NBAStreetRecomp\logs
cd /d C:\NBAStreetRecomp\game\iso
"C:\NBAStreetRecomp\PS2Recomp\out\build\ps2xRuntime\Release\ps2EntryRunner.exe" "C:\NBAStreetRecomp\game\iso\SLUS_211.26" > "C:\NBAStreetRecomp\logs\jugar.log" 2> "C:\NBAStreetRecomp\logs\jugar_err.log"
