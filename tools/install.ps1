<#
  Full installer for the NBA Street V3 PC port, run by the launcher's "Prepare game" button.
  From your ISO to a playable game:
    1. Visual Studio 2022 Build Tools (C++ compiler), if missing  [asks for administrator rights]
    2. Portable CMake and Git in C:\NBAStreetRecomp\tools
    3. Your ISO: checks it is SLUS-21126 and copies its contents to C:\NBAStreetRecomp\game\iso
    4. PS2Recomp and PCSX2 sources with this repository's patches
    5. Recompiler -> the game's C++ code (generated on YOUR PC from YOUR ELF) -> game executable
    6. Renderer (pcsx2-gsrunner): the prebuilt one shipped in the release zip, or -BuildPcsx2
    7. HD texture pack: downloaded from the release and installed (turned on) automatically
  Every step is skipped when already done, so it can simply be run again after an error.
  Manual use:  powershell -ExecutionPolicy Bypass -File tools\install.ps1 -Iso "D:\Games\NBA Street V3.iso"
#>
param(
    [string]$Iso = "",
    [string]$Root = "C:\NBAStreetRecomp",
    [string[]]$GsHostUrl = @(),       # prebuilt renderer zip(s) to download (when not shipped next to the launcher)
    [switch]$BuildPcsx2,              # build the renderer from source instead
    [switch]$Rebuild,                 # regenerate and rebuild the game even if it exists
    [switch]$RecompilerOnly           # stop after the recompiler, no ISO needed (CI / troubleshooting)
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Repo = Split-Path -Parent $PSScriptRoot
$Tools = Join-Path $Root 'tools'
$Logs = Join-Path $Root 'logs'
New-Item -ItemType Directory -Force $Root, $Tools, $Logs, "$Tools\dl", "$Root\game\iso" | Out-Null

# Portable copies, used only when CMake / Git are not already installed (see step 2).
$CMakeDir = "$Tools\cmake\cmake-4.4.4-windows-x86_64\bin"
$GitDir = "$Tools\mingit\cmd"
$MinCMake = [version]'3.21'   # PS2Recomp's cmake_minimum_required
$Downloads = @{
    VsBuildTools = 'https://aka.ms/vs/17/release/vs_BuildTools.exe'
    CMake        = 'https://github.com/Kitware/CMake/releases/download/v4.4.4/cmake-4.4.4-windows-x86_64.zip'
    MinGit       = 'https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.2/MinGit-2.56.0.2-64-bit.zip'
}
$DlssDllUrl = 'https://raw.githubusercontent.com/NVIDIA/DLSS/main/lib/Windows_x86_64/rel/nvngx_dlss.dll'
# Fixed to the release that carries the pack, so later releases only need the small launcher zip.
$TexturePackUrl = 'https://github.com/recomp-code/street-recomp-v3/releases/download/v1.1/NBAStreetV3-HD-Textures.zip'
if (-not $GsHostUrl -and (Test-Path "$Repo\gshost\release_url.txt")) { $GsHostUrl = @(Get-Content "$Repo\gshost\release_url.txt" | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }

$Host.UI.RawUI.WindowTitle = 'NBA Street V3 - preparing the game'
function Step($text) { Write-Host ""; Write-Host "==> $text" -ForegroundColor Cyan }
function Download($url, $file) {
    if (Test-Path $file) { return }
    Write-Host "    downloading $url"
    Invoke-WebRequest -Uri $url -OutFile "$file.part" -UseBasicParsing
    Move-Item "$file.part" $file -Force
}
function Run($exe, [string[]]$arguments, $log) {
    Write-Host "    $([IO.Path]::GetFileName($exe)) $($arguments -join ' ')"
    # Native tools print warnings on stderr (CMake's deprecation notices, for one). With
    # $ErrorActionPreference = 'Stop', Windows PowerShell 5.1 turns every redirected stderr line
    # into a terminating error, so a configure that only warned stopped the install. Run them with
    # 'Continue' and judge them by their exit code alone.
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($log) {
            & $exe @arguments 2>&1 | ForEach-Object { "$_" } | Out-File -FilePath $log -Encoding utf8
        } else {
            & $exe @arguments
        }
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $saved
    }
    if ($code) { throw "$([IO.Path]::GetFileName($exe)) failed with code $code$(if ($log) { " (see $log)" })" }
}

# A tool already installed and on PATH (with a minimum version), or $null.
function Find-OnPath($name, [version]$minVersion) {
    $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { return $null }
    if ($minVersion) {
        $saved = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { $text = (& $cmd.Source --version 2>&1 | Select-Object -First 1) -as [string] } finally { $ErrorActionPreference = $saved }
        if ($text -notmatch '(\d+\.\d+(\.\d+)?)' -or [version]$Matches[1] -lt $minVersion) { return $null }
    }
    return Split-Path -Parent $cmd.Source
}

try {
# ---------------------------------------------------------------- 1. C++ compiler
Step "C++ compiler (Visual Studio 2022 Build Tools)"
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
function Find-VS { if (Test-Path $vswhere) { & $vswhere -latest -products * -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath } }
if (-not (Find-VS)) {
    Download $Downloads.VsBuildTools "$Tools\dl\vs_BuildTools.exe"
    Write-Host "    installing (about 5 GB; Windows will ask for administrator permission)..."
    $p = Start-Process "$Tools\dl\vs_BuildTools.exe" -Verb RunAs -Wait -PassThru -ArgumentList @(
        '--passive', '--wait', '--norestart',
        '--add', 'Microsoft.VisualStudio.Workload.VCTools',
        '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
        '--add', 'Microsoft.VisualStudio.Component.Windows11SDK.22621',
        '--add', 'Microsoft.VisualStudio.Component.VC.CMake.Project')
    if ($p.ExitCode -notin 0, 3010) { throw "The Build Tools installation failed ($($p.ExitCode))" }
    if (-not (Find-VS)) { throw "Build Tools not found after installing them" }
}
Write-Host "    OK: $(Find-VS)"

# ---------------------------------------------------------------- 2. portable tools
Step "CMake and Git"
# Use the ones already installed when there are; otherwise portable copies in $Tools.
if (-not (Test-Path "$CMakeDir\cmake.exe")) {
    if ($found = Find-OnPath 'cmake' $MinCMake) {
        $CMakeDir = $found
    } else {
        Download $Downloads.CMake "$Tools\dl\cmake.zip"
        Expand-Archive "$Tools\dl\cmake.zip" "$Tools\cmake" -Force
    }
}
if (-not (Test-Path "$GitDir\git.exe")) {
    if ($found = Find-OnPath 'git') {
        $GitDir = $found
    } else {
        Download $Downloads.MinGit "$Tools\dl\mingit.zip"
        Expand-Archive "$Tools\dl\mingit.zip" "$Tools\mingit" -Force
    }
}
$env:Path = "$GitDir;$CMakeDir;$env:Path"
Write-Host "    CMake: $CMakeDir"
Write-Host "    Git:   $GitDir"
# Repository scripts next to the tools (the build .cmd files look for them there).
Copy-Item "$Repo\tools\*" $Tools -Recurse -Force -Exclude 'dl'
Write-Host "    OK"

# ---------------------------------------------------------------- 3. the game (your ISO)
Step "Your copy of the game"
$isoTarget = Join-Path $Root 'game\NBAStreetV3.iso'
$elf = Join-Path $Root 'game\iso\SLUS_211.26'
if ($RecompilerOnly) {
    Write-Host "    skipped (-RecompilerOnly)"
} else {
if (-not (Test-Path $elf)) {
    if (-not $Iso) { throw "Choose your ISO in the launcher first" }
    if (-not (Test-Path $Iso)) { throw "File not found: $Iso" }
    $image = Mount-DiskImage -ImagePath (Resolve-Path $Iso).Path -PassThru
    try {
        $drive = ($image | Get-Volume).DriveLetter + ':\'
        if (-not (Test-Path (Join-Path $drive 'SLUS_211.26'))) { throw "This ISO is not NBA Street V3 NTSC-U (SLUS_211.26 is missing)" }
        Write-Host "    copying the disc contents (several GB)..."
        robocopy $drive "$Root\game\iso" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "Copying the disc failed (robocopy $LASTEXITCODE)" }
        Get-ChildItem "$Root\game\iso" -Recurse -File | ForEach-Object { $_.IsReadOnly = $false }
    } finally {
        Dismount-DiskImage -ImagePath (Resolve-Path $Iso).Path | Out-Null
    }
}
if (-not (Test-Path $isoTarget)) {
    if (-not $Iso) { throw "Choose your ISO in the launcher first" }
    $src = (Resolve-Path $Iso).Path
    if ([IO.Path]::GetPathRoot($src) -eq [IO.Path]::GetPathRoot($isoTarget)) {
        New-Item -ItemType HardLink -Path $isoTarget -Target $src | Out-Null   # same drive: no copy needed
    } else {
        Copy-Item $src $isoTarget
    }
}
Write-Host "    OK: $elf"
}

# ---------------------------------------------------------------- 4. sources
Step "PS2Recomp and PCSX2 sources (with the patches)"
& "$Repo\tools\setup_sources.ps1" -Root $Root

# ---------------------------------------------------------------- 5. recompiler and game
$build = Join-Path $Root 'PS2Recomp\out\build'
$recompExe = Join-Path $build 'ps2xRecomp\Release\ps2_recomp.exe'
$gameExe = Join-Path $build 'ps2xRuntime\Release\ps2EntryRunner.exe'
Step "Recompiler"
if (-not (Test-Path $recompExe)) {
    Run "$CMakeDir\cmake.exe" @('-S', "$Root\PS2Recomp", '-B', $build) "$Logs\install_configure.log"
    Run "$CMakeDir\cmake.exe" @('--build', $build, '--config', 'Release', '--target', 'ps2_recomp', '--parallel') "$Logs\install_recomp.log"
}
Write-Host "    OK"
if ($RecompilerOnly) {
    Write-Host ""
    Write-Host "==> Recompiler ready (-RecompilerOnly)." -ForegroundColor Green
    return
}

Step "Game code (generated from your ELF)"
$runner = Join-Path $Root 'PS2Recomp\ps2xRuntime\src\runner'
if ($Rebuild -or -not (Test-Path "$runner\nba_street_v3_overrides.cpp")) {
    & "$Repo\tools\generate_game.ps1" -Root $Root
}
Write-Host "    OK"

Step "Compiling the game (the first time this can take more than an hour)"
if ($Rebuild -or -not (Test-Path $gameExe)) {
    Run "$CMakeDir\cmake.exe" @('-S', "$Root\PS2Recomp", '-B', $build) "$Logs\install_configure2.log"
    # Some blocks of the game code need several GB each to compile: one compiler per ~2.5 GB of RAM
    # (never more than the cores), or Windows pages to disk and the build takes many hours.
    $ramGB = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    $jobs = [int][math]::Max(2, [math]::Min([Environment]::ProcessorCount, [math]::Floor($ramGB / 2.5)))
    Run "$CMakeDir\cmake.exe" @('--build', $build, '--config', 'Release', '--target', 'ps2EntryRunner', '--', '/m:1', "/p:CL_MPCount=$jobs") "$Logs\install_game.log"
}
Write-Host "    OK: $gameExe"

# ---------------------------------------------------------------- 6. renderer
Step "Renderer (PCSX2 pcsx2-gsrunner)"
$gshost = Join-Path $Root 'gshost'
# Prebuilt renderer: shipped next to the launcher in the release zip, otherwise downloaded.
$localZips = @(Get-ChildItem $Repo -Filter 'gshost-win64*.zip' -ErrorAction SilentlyContinue)
# A newer release zip (e.g. after unzipping an update over the old one) refreshes the renderer.
$rendererOutdated = (Test-Path "$gshost\pcsx2-gsrunner.exe") -and $localZips.Count -and
    ($localZips | Where-Object { $_.LastWriteTime -gt (Get-Item "$gshost\pcsx2-gsrunner.exe").LastWriteTime })
if ($rendererOutdated) { Write-Host "    updating the renderer from the new release" }
# Keep the player's graphics settings across renderer updates.
$savedIni = if (Test-Path "$gshost\nba_street.ini") { [IO.File]::ReadAllBytes("$gshost\nba_street.ini") } else { $null }
if ($rendererOutdated -or -not (Test-Path "$gshost\pcsx2-gsrunner.exe")) {
    if (-not $BuildPcsx2 -and $localZips.Count) {
        foreach ($z in $localZips) { Expand-Archive $z.FullName $gshost -Force }
    } elseif ($BuildPcsx2 -or -not $GsHostUrl) {
        if (-not $BuildPcsx2) { Write-Warning "No prebuilt renderer found: building it from source (needs LLVM, Ninja, Python and PortableGit in $Tools, see the README)" }
        Run "$Tools\build_pcsx2_deps.bat" @() "$Logs\install_pcsx2_deps.log"
        Run "$Tools\build_pcsx2.cmd" @('pcsx2-gsrunner') "$Logs\install_pcsx2.log"
        & "$Repo\tools\setup_gshost.ps1" -Root $Root
    } else {
        foreach ($url in @($GsHostUrl)) {
            $file = Join-Path "$Tools\dl" ([IO.Path]::GetFileName($url))
            Download $url $file
            Expand-Archive $file $gshost -Force
        }
    }
}
if ($savedIni) { [IO.File]::WriteAllBytes("$gshost\nba_street.ini", $savedIni) }
if (-not (Test-Path "$gshost\nba_street.ini")) { Copy-Item "$Repo\gshost\nba_street.ini" $gshost }
# NVIDIA DLSS runtime, straight from NVIDIA's official SDK repository (only used on RTX GPUs; the
# renderer falls back to AMD FSR without it). DLSS Swapper can update this file later.
if (-not (Test-Path "$gshost\nvngx_dlss.dll")) {
    try {
        Download $DlssDllUrl "$Tools\dl\nvngx_dlss.dll"
        Copy-Item "$Tools\dl\nvngx_dlss.dll" "$gshost\nvngx_dlss.dll"
    } catch {
        Write-Warning "NVIDIA DLSS runtime not downloaded ($($_.Exception.Message)); the upscaler will use AMD FSR."
    }
}
Write-Host "    OK: $gshost"

# ---------------------------------------------------------------- 7. HD textures
# The HD pack is a separate asset of the release; downloaded and installed once, automatically.
# Not fatal: without it the game simply uses its original textures.
Step "HD textures"
$textureDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PCSX2\textures\SLUS-21126\replacements'
$haveTextures = (Test-Path $textureDir) -and @(Get-ChildItem $textureDir -File -Filter *.png -ErrorAction SilentlyContinue | Select-Object -First 1).Count
if (-not $haveTextures) {
    try {
        $pack = Join-Path $Repo 'NBAStreetV3-HD-Textures.zip'   # next to the launcher, if downloaded by hand
        if (-not (Test-Path $pack)) {
            $pack = "$Tools\dl\NBAStreetV3-HD-Textures.zip"
            Write-Host "    downloading the HD texture pack (about 250 MB)..."
            Download $TexturePackUrl $pack
        }
        $result = & "$Repo\tools\install_textures.ps1" -Source $pack -Root $Root | Select-Object -Last 1
        Write-Host "    OK: $result"
    } catch {
        Write-Warning "HD textures could not be installed ($($_.Exception.Message)). The game works without them; press 'Prepare game' again later to retry."
    }
} else {
    Write-Host "    OK (already installed)"
}

# ---------------------------------------------------------------- done
Copy-Item "$Repo\Play.cmd" (Join-Path $Root 'Play.cmd') -Force
Write-Host ""
Write-Host "==> Done! You can close this window and press PLAY in the launcher." -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "==> Something went wrong: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    Press 'Prepare game' again to retry (finished steps are skipped)."
    Write-Host "    If it keeps failing, open an issue on GitHub and attach the files in $Logs."
    if ($RecompilerOnly) { exit 1 }   # CI: report the failure (the launcher never passes this)
}
