<#
  Genera el codigo C++ del juego a partir de TU copia de NBA Street V3 (SLUS-21126) y lo deja listo
  para compilar. Nada de esto se sube al repositorio: es una traduccion del ejecutable del juego.

  Requisitos previos:
    - C:\NBAStreetRecomp\game\NBAStreetV3.iso  (tu ISO)
    - C:\NBAStreetRecomp\game\iso\             (la ISO extraida con 7-Zip; contiene SLUS_211.26)
    - El recompilador compilado (tools\build_recomp.cmd tras configurar, ver README)

  Pasos: ps2_recomp (config del repositorio) -> game\output -> copia a ps2xRuntime\src\runner y
  cabeceras a ps2xRuntime\include -> parches sobre el codigo generado -> override del juego.
#>
param([string]$Root = "C:\NBAStreetRecomp")
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$game = Join-Path $Root 'game'

$elf = Join-Path $game 'iso\SLUS_211.26'
if (-not (Test-Path $elf)) { throw "Falta ${elf}: extrae tu ISO en $game\iso" }
if (-not (Test-Path (Join-Path $game 'NBAStreetV3.iso'))) { Write-Warning "Falta $game\NBAStreetV3.iso (el juego la usa para leer sectores del disco)" }

# Configuracion del recompilador (direcciones de funciones; sin codigo del juego).
New-Item -ItemType Directory -Force "$game\config", "$game\output", "$game\overrides" | Out-Null
Copy-Item "$Repo\game\config\*" "$game\config\" -Force
Copy-Item "$Repo\game\overrides\*" "$game\overrides\" -Force

$recomp = Join-Path $Root 'PS2Recomp\out\build\ps2xRecomp\Release\ps2_recomp.exe'
if (-not (Test-Path $recomp)) { throw "Falta ${recomp}: compila el recompilador (tools\build_recomp.cmd)" }
Write-Host "Recompilando el ELF (tarda unos minutos)..."
& $recomp "$game\config\config.toml"
if ($LASTEXITCODE) { throw "ps2_recomp fallo ($LASTEXITCODE)" }

$runner = Join-Path $Root 'PS2Recomp\ps2xRuntime\src\runner'
$include = Join-Path $Root 'PS2Recomp\ps2xRuntime\include'
Write-Host "Copiando codigo generado a $runner"
New-Item -ItemType Directory -Force $runner | Out-Null
Copy-Item "$game\output\*.cpp" $runner -Force
Copy-Item "$game\output\*.h" $include -Force

# Parches sobre el codigo generado (idempotentes). branch64 y sqrt_s ya los hace el recompilador
# parcheado; se ejecutan igualmente por si se usa otro.
& "$Repo\tools\fix_sqrt_s.ps1" -Dir $runner
& "$Repo\tools\fix_branch64.ps1" -Dirs $runner
& "$Repo\tools\fix_cop0_count.ps1" -Dir $runner
& "$Repo\tools\fix_dnas_skip.ps1" -Dir $runner

Copy-Item "$Repo\game\overrides\nba_street_v3_overrides.cpp" $runner -Force
Write-Host "Listo. Ahora: tools\build_runner.cmd (primera vez) o tools\build_runner_only.cmd"
