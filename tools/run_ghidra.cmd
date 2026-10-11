@echo off
rem Analiza el ELF con Ghidra headless (procesador R5900) y exporta config.toml + functions.csv
set W=C:\NBAStreetRecomp
set JAVA_HOME=%W%\tools\jdk\jdk-21.0.12.1+1
set PATH=%JAVA_HOME%\bin;%PATH%
set ELF=%~1
set TOML=%~2
set CSV=%~3
call "%W%\tools\ghidra\ghidra_12.1.4_PUBLIC\support\analyzeHeadless.bat" "%W%\game\ghidra_project" NBAStreetV3 ^
  -import "%ELF%" -overwrite ^
  -processor r5900:LE:32:default -cspec default ^
  -scriptPath "%W%\PS2Recomp\ps2xRecomp\tools\ghidra" ^
  -postScript ExportPS2Functions.java "%TOML%" "%CSV%"
exit /b %ERRORLEVEL%
