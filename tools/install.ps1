<#
  Instalador completo de NBA Street V3 (port PC). Desde tu ISO hasta el juego listo para jugar:
    1. Visual Studio 2022 Build Tools (compilador C++), si faltan  [pide permisos de administrador]
    2. CMake y Git portables en C:\NBAStreetRecomp\tools
    3. Tu ISO: comprueba que es SLUS-21126 y extrae su contenido en C:\NBAStreetRecomp\game\iso
    4. Fuentes de PS2Recomp y PCSX2 con los parches de este repositorio
    5. Recompilador -> codigo C++ del juego (generado en TU PC desde TU ELF) -> ejecutable del juego
    6. Render (pcsx2-gsrunner): descarga la version ya compilada, o -BuildPcsx2 para compilarlo
  Cada paso se salta si ya esta hecho: se puede relanzar tras un error o una interrupcion.
  Uso:  powershell -ExecutionPolicy Bypass -File tools\install.ps1 -Iso "D:\juegos\NBA Street V3.iso"
#>
param(
    [string]$Iso = "",
    [string]$Root = "C:\NBAStreetRecomp",
    [string]$GsHostUrl = "",          # zip del render ya compilado (Release del repositorio)
    [switch]$BuildPcsx2,              # compilar el render desde las fuentes en lugar de descargarlo
    [switch]$Rebuild                  # regenerar y recompilar el juego aunque ya exista
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Repo = Split-Path -Parent $PSScriptRoot
$Tools = Join-Path $Root 'tools'
$Logs = Join-Path $Root 'logs'
New-Item -ItemType Directory -Force $Root, $Tools, $Logs, "$Tools\dl", "$Root\game\iso" | Out-Null

$CMakeDir = "$Tools\cmake\cmake-4.4.4-windows-x86_64\bin"
$GitDir = "$Tools\mingit\cmd"
$Downloads = @{
    VsBuildTools = 'https://aka.ms/vs/17/release/vs_BuildTools.exe'
    CMake        = 'https://github.com/Kitware/CMake/releases/download/v4.4.4/cmake-4.4.4-windows-x86_64.zip'
    MinGit       = 'https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.2/MinGit-2.56.0.2-64-bit.zip'
}
if (-not $GsHostUrl -and (Test-Path "$Repo\gshost\release_url.txt")) { $GsHostUrl = (Get-Content "$Repo\gshost\release_url.txt" -TotalCount 1).Trim() }

function Step($text) { Write-Host ""; Write-Host "==> $text" -ForegroundColor Cyan }
function Download($url, $file) {
    if (Test-Path $file) { return }
    Write-Host "    descargando $url"
    Invoke-WebRequest -Uri $url -OutFile "$file.part" -UseBasicParsing
    Move-Item "$file.part" $file -Force
}
function Run($exe, [string[]]$arguments, $log) {
    Write-Host "    $([IO.Path]::GetFileName($exe)) $($arguments -join ' ')"
    if ($log) {
        & $exe @arguments *> $log
    } else {
        & $exe @arguments
    }
    if ($LASTEXITCODE) { throw "$exe termino con codigo $LASTEXITCODE$(if ($log) { " (ver $log)" })" }
}

# ---------------------------------------------------------------- 1. compilador C++
Step "Compilador C++ (Visual Studio 2022 Build Tools)"
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
function Find-VS { if (Test-Path $vswhere) { & $vswhere -latest -products * -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath } }
if (-not (Find-VS)) {
    Download $Downloads.VsBuildTools "$Tools\dl\vs_BuildTools.exe"
    Write-Host "    instalando (unos 5 GB; Windows pedira permiso de administrador)..."
    $p = Start-Process "$Tools\dl\vs_BuildTools.exe" -Verb RunAs -Wait -PassThru -ArgumentList @(
        '--passive', '--wait', '--norestart',
        '--add', 'Microsoft.VisualStudio.Workload.VCTools',
        '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
        '--add', 'Microsoft.VisualStudio.Component.Windows11SDK.22621',
        '--add', 'Microsoft.VisualStudio.Component.VC.CMake.Project')
    if ($p.ExitCode -notin 0, 3010) { throw "La instalacion de Build Tools fallo ($($p.ExitCode))" }
    if (-not (Find-VS)) { throw "No se encuentran las Build Tools tras instalarlas" }
}
Write-Host "    OK: $(Find-VS)"

# ---------------------------------------------------------------- 2. herramientas portables
Step "CMake y Git portables"
if (-not (Test-Path "$CMakeDir\cmake.exe")) {
    Download $Downloads.CMake "$Tools\dl\cmake.zip"
    Expand-Archive "$Tools\dl\cmake.zip" "$Tools\cmake" -Force
}
if (-not (Test-Path "$GitDir\git.exe")) {
    Download $Downloads.MinGit "$Tools\dl\mingit.zip"
    Expand-Archive "$Tools\dl\mingit.zip" "$Tools\mingit" -Force
}
$env:Path = "$GitDir;$CMakeDir;$env:Path"
# Scripts del repositorio junto a las herramientas (los .cmd de compilacion los buscan ahi).
Copy-Item "$Repo\tools\*" $Tools -Recurse -Force -Exclude 'dl'
Write-Host "    OK"

# ---------------------------------------------------------------- 3. el juego (tu ISO)
Step "Tu copia del juego"
$isoTarget = Join-Path $Root 'game\NBAStreetV3.iso'
$elf = Join-Path $Root 'game\iso\SLUS_211.26'
if (-not (Test-Path $elf)) {
    if (-not $Iso) { throw "Indica tu ISO: -Iso <ruta a NBA Street V3 (SLUS-21126).iso>" }
    if (-not (Test-Path $Iso)) { throw "No existe $Iso" }
    $image = Mount-DiskImage -ImagePath (Resolve-Path $Iso).Path -PassThru
    try {
        $drive = ($image | Get-Volume).DriveLetter + ':\'
        if (-not (Test-Path (Join-Path $drive 'SLUS_211.26'))) { throw "Esta ISO no es NBA Street V3 NTSC-U (falta SLUS_211.26)" }
        Write-Host "    copiando el contenido del disco (varios GB)..."
        robocopy $drive "$Root\game\iso" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "robocopy fallo ($LASTEXITCODE)" }
        Get-ChildItem "$Root\game\iso" -Recurse -File | ForEach-Object { $_.IsReadOnly = $false }
    } finally {
        Dismount-DiskImage -ImagePath (Resolve-Path $Iso).Path | Out-Null
    }
}
if (-not (Test-Path $isoTarget)) {
    if (-not $Iso) { throw "Falta ${isoTarget}: indica tu ISO con -Iso" }
    $src = (Resolve-Path $Iso).Path
    if ([IO.Path]::GetPathRoot($src) -eq [IO.Path]::GetPathRoot($isoTarget)) {
        New-Item -ItemType HardLink -Path $isoTarget -Target $src | Out-Null   # misma unidad: sin copiar
    } else {
        Copy-Item $src $isoTarget
    }
}
Write-Host "    OK: $elf"

# ---------------------------------------------------------------- 4. fuentes
Step "Fuentes de PS2Recomp y PCSX2 (con los parches)"
& "$Repo\tools\setup_sources.ps1" -Root $Root

# ---------------------------------------------------------------- 5. recompilador y juego
$build = Join-Path $Root 'PS2Recomp\out\build'
$recompExe = Join-Path $build 'ps2xRecomp\Release\ps2_recomp.exe'
$gameExe = Join-Path $build 'ps2xRuntime\Release\ps2EntryRunner.exe'
Step "Recompilador"
if (-not (Test-Path $recompExe)) {
    Run "$CMakeDir\cmake.exe" @('-S', "$Root\PS2Recomp", '-B', $build) "$Logs\install_configure.log"
    Run "$CMakeDir\cmake.exe" @('--build', $build, '--config', 'Release', '--target', 'ps2_recomp', '--parallel') "$Logs\install_recomp.log"
}
Write-Host "    OK"

Step "Codigo del juego (generado desde tu ELF)"
$runner = Join-Path $Root 'PS2Recomp\ps2xRuntime\src\runner'
if ($Rebuild -or -not (Test-Path "$runner\nba_street_v3_overrides.cpp")) {
    & "$Repo\tools\generate_game.ps1" -Root $Root
}
Write-Host "    OK"

Step "Compilando el juego (la primera vez puede tardar mas de una hora)"
if ($Rebuild -or -not (Test-Path $gameExe)) {
    Run "$CMakeDir\cmake.exe" @('-S', "$Root\PS2Recomp", '-B', $build) "$Logs\install_configure2.log"
    Run "$CMakeDir\cmake.exe" @('--build', $build, '--config', 'Release', '--target', 'ps2EntryRunner', '--parallel') "$Logs\install_game.log"
}
Write-Host "    OK: $gameExe"

# ---------------------------------------------------------------- 6. render
Step "Render (PCSX2 pcsx2-gsrunner)"
$gshost = Join-Path $Root 'gshost'
if (-not (Test-Path "$gshost\pcsx2-gsrunner.exe")) {
    $localZip = Join-Path $Repo 'gshost-win64.zip'   # incluido en el zip de la release
    if (-not $BuildPcsx2 -and (Test-Path $localZip)) {
        Expand-Archive $localZip $gshost -Force
    } elseif ($BuildPcsx2 -or -not $GsHostUrl) {
        if (-not $BuildPcsx2) { Write-Warning "No hay URL del render precompilado: se compila desde las fuentes (necesita LLVM, Ninja, Python y PortableGit en $Tools, ver README)" }
        Run "$Tools\build_pcsx2_deps.bat" @() "$Logs\install_pcsx2_deps.log"
        Run "$Tools\build_pcsx2.cmd" @('pcsx2-gsrunner') "$Logs\install_pcsx2.log"
        & "$Repo\tools\setup_gshost.ps1" -Root $Root
    } else {
        Download $GsHostUrl "$Tools\dl\gshost-win64.zip"
        Expand-Archive "$Tools\dl\gshost-win64.zip" $gshost -Force
    }
}
if (-not (Test-Path "$gshost\nba_street.ini")) { Copy-Item "$Repo\gshost\nba_street.ini" $gshost }
Write-Host "    OK: $gshost"

# ---------------------------------------------------------------- listo
Copy-Item "$Repo\Jugar.cmd" (Join-Path $Root 'Jugar.cmd') -Force
Step "Listo. Juega con $Root\Jugar.cmd o con el launcher (Launcher.cmd)."
