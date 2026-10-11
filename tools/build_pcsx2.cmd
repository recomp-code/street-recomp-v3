@echo off
rem Configura y compila PCSX2 (nucleo + pcsx2-gsrunner, sin Qt) con clang-cl.
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1
set T=C:\NBAStreetRecomp\tools
set PATH=%T%\llvm\clang+llvm-20.1.8-x86_64-pc-windows-msvc\bin;%T%\ninja;%T%\cmake\cmake-4.4.4-windows-x86_64\bin;%T%\python;%T%\portablegit\cmd;%PATH%
set P=C:\NBAStreetRecomp\pcsx2
if not exist "%P%\build\build.ninja" (
  cmake -S "%P%" -B "%P%\build" -G Ninja -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl -DCMAKE_LINKER=lld-link ^
    -DCMAKE_PREFIX_PATH="%P%\deps" -DENABLE_QT_UI=OFF -DENABLE_GSRUNNER=ON -DENABLE_TESTS=OFF ^
    -DCMAKE_RC_COMPILER=llvm-rc || exit /b 2
)
cmake --build "%P%\build" --target %1 || exit /b 3
