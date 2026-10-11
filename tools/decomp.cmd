@echo off
rem Descompila / busca referencias en el proyecto Ghidra del ELF: decomp.cmd <salida.txt> d:0xADDR x:0xADDR s:texto ...
set W=C:\NBAStreetRecomp
set JAVA_HOME=%W%\tools\jdk\jdk-21.0.12.1+1
set PATH=%JAVA_HOME%\bin;%PATH%
call "%W%\tools\ghidra\ghidra_12.1.4_PUBLIC\support\analyzeHeadless.bat" "%W%\game\ghidra_project" NBAStreetV3 ^
  -process -noanalysis -readOnly ^
  -scriptPath "%W%\tools\ghidra_scripts" -postScript Decomp.java %* > "%W%\logs\decomp_run.log" 2>&1
exit /b %ERRORLEVEL%
