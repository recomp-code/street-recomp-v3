@echo off
rem Starts the recompiled NBA Street V3 without the launcher window (normally just use Launcher.cmd).
rem Keyboard: arrows = d-pad, WASD = left stick, Z/X/C/V = Square/Cross/Circle/Triangle,
rem Q/E = L1/R1, 1/3 = L2/R2, Enter = START, Backspace = SELECT, Alt+Enter or F11 = fullscreen.
rem Xbox-style controller: A = Cross, B = Circle, X = Square, Y = Triangle.
rem Graphics menu (resolution, filtering, renderer, HD textures): F1, Back+Start or hold START 1.5 s.
rem Online is on by default against the community server (set NBA_SERVER to change it,
rem NBA_SERVER=off to play offline). In game: PLAY ONLINE -> YES -> "1 - NBA Street Online (DHCP)".
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
"C:\NBAStreetRecomp\PS2Recomp\out\build\ps2xRuntime\Release\ps2EntryRunner.exe" "C:\NBAStreetRecomp\game\iso\SLUS_211.26" > "C:\NBAStreetRecomp\logs\play.log" 2> "C:\NBAStreetRecomp\logs\play_err.log"
