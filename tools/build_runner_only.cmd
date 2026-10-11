@echo off
set PATH=C:\NBAStreetRecomp\tools\mingit\cmd;C:\NBAStreetRecomp\tools\cmake\cmake-4.4.4-windows-x86_64\bin;%PATH%
cmake --build "C:\NBAStreetRecomp\PS2Recomp\out\build" --config Release --target ps2EntryRunner --parallel -- /v:minimal > "C:\NBAStreetRecomp\logs\cmake_build_game74.log" 2>&1
echo BUILD_EXIT=%ERRORLEVEL%>> "C:\NBAStreetRecomp\logs\cmake_build_game74.log"







