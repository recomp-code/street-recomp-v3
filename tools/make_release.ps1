<#
  Genera el zip de la release para GitHub (lo que descarga un jugador):
    NBAStreetV3-PC-<version>.zip = Launcher + instalador + parches + configuracion + scripts
                                   + gshost-win64.zip (render de PCSX2 ya compilado, GPL)
  NO incluye nada del juego: el juego se compila en el PC del jugador desde su propia ISO.
  Uso: tools\make_release.ps1 -Version 1.0 [-GsHostZip C:\NBAStreetRecomp\release\gshost-win64.zip]
#>
param([Parameter(Mandatory)][string]$Version, [string]$GsHostZip = "C:\NBAStreetRecomp\release\gshost-win64.zip",
      [string]$OutDir = "C:\NBAStreetRecomp\release")
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$name = "NBAStreetV3-PC-$Version"
$stage = Join-Path $OutDir $name
if (Test-Path $stage) { cmd /c rmdir /s /q "$stage" }
New-Item -ItemType Directory -Force $stage | Out-Null

# Solo lo que esta en git (nunca archivos sueltos del juego que hubiera en la carpeta).
$files = git -C $Repo ls-files
if ($LASTEXITCODE) { throw "git ls-files fallo" }
foreach ($f in $files) {
    $dst = Join-Path $stage $f
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    Copy-Item (Join-Path $Repo $f) $dst
}
if (Test-Path $GsHostZip) { Copy-Item $GsHostZip (Join-Path $stage 'gshost-win64.zip') }
else { Write-Warning "Sin ${GsHostZip}: el instalador tendra que compilar PCSX2" }

$zip = Join-Path $OutDir "$name.zip"
if (Test-Path $zip) { cmd /c del /q "$zip" }
Compress-Archive "$stage\*" $zip
cmd /c rmdir /s /q "$stage"
Get-Item $zip | Select-Object Name, @{ n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } }
