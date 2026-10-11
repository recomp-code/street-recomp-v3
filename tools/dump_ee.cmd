@echo off
rem Desensambla rangos del volcado de RAM del IOP: dump_iop.cmd <bin> <inicio> <fin> [<inicio> <fin> ...]
set W=C:\NBAStreetRecomp
set JAVA_HOME=%W%\tools\jdk\jdk-21.0.12.1+1
set PATH=%JAVA_HOME%\bin;%PATH%
set BIN=%~1
shift
set ARGS=
:loop
if "%~1"=="" goto run
set ARGS=%ARGS% %1
shift
goto loop
:run
if not exist "%W%\game\ghidra_ee" mkdir "%W%\game\ghidra_ee"
call "%W%\tools\ghidra\ghidra_12.1.4_PUBLIC\support\analyzeHeadless.bat" "%W%\game\ghidra_ee" EE ^
  -import "%BIN%" -overwrite -loader BinaryLoader -loader-baseAddr 0x100000 ^
  -processor MIPS:LE:32:default -noanalysis ^
  -scriptPath "%W%\tools\ghidra_scripts" -postScript DumpRanges.java %ARGS% -deleteProject

