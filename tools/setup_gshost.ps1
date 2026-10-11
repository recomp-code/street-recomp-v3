<#
  Monta C:\NBAStreetRecomp\gshost (la carpeta desde la que se ejecuta el render de PCSX2) despues de
  compilar pcsx2-gsrunner: exe + DLLs de las dependencias + resources + configuracion grafica.
  Uso: powershell -ExecutionPolicy Bypass -File tools\setup_gshost.ps1
#>
param([string]$Root = "C:\NBAStreetRecomp")
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$pcsx2 = Join-Path $Root 'pcsx2'
$out = Join-Path $Root 'gshost'

$exe = Join-Path $pcsx2 'build\pcsx2-gsrunner\pcsx2-gsrunner.exe'
if (-not (Test-Path $exe)) { throw "Falta ${exe}: compila con tools\build_pcsx2.cmd pcsx2-gsrunner" }
New-Item -ItemType Directory -Force $out | Out-Null
Copy-Item $exe $out -Force
Copy-Item "$pcsx2\deps\bin\*.dll" $out -Force
if (Test-Path "$pcsx2\deps\bin\D3D12") { Copy-Item "$pcsx2\deps\bin\D3D12" $out -Recurse -Force }
Copy-Item "$pcsx2\bin\resources" $out -Recurse -Force
# Configuracion grafica: solo si no existe (el menu del juego la reescribe con tus ajustes).
if (-not (Test-Path "$out\nba_street.ini")) { Copy-Item "$Repo\gshost\nba_street.ini" $out }
Write-Host "gshost listo en $out"
