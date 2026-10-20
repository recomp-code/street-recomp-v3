<#
  Checks that the renderer works with add-ons that hook DLSS calls (for example ReShade add-ons
  for DLSS neural rendering). Plays an automatic match with Direct3D 12 + NVIDIA DLSS at
  1920x1080 from a renderer folder, then summarises what the add-on logged.

  Set up the renderer folder yourself first (a copy of C:\NBAStreetRecomp\gshost is best, so the
  normal install is untouched) with ReShade (add-on build) and the add-on you want to test.
  Nothing from NVIDIA or from third parties is downloaded or shipped by this project.

  Usage:
    powershell -ExecutionPolicy Bypass -File tools\test_dlss_addon.ps1 -HostDir C:\NBAStreetRecomp\gshost_hooktest
  Takes about 3 minutes: a window opens and closes by itself (do not close it).
#>
param([string]$HostDir = 'C:\NBAStreetRecomp\gshost', [int]$Seconds = 170, [string]$Root = 'C:\NBAStreetRecomp')
$ErrorActionPreference = 'Stop'
$exe = Join-Path $HostDir 'pcsx2-gsrunner.exe'
if (-not (Test-Path $exe)) { throw "No renderer in $HostDir (pcsx2-gsrunner.exe)" }

# Direct3D 12, 2x internal resolution, DLSS up to the 1920x1080 window, HD textures.
$ini = @'
; test_dlss_addon.ps1: Direct3D 12 + NVIDIA DLSS
[EmuCore/GS]
Renderer = 15
upscale_multiplier = 2
MaxAnisotropy = 16
filter = 2
fxaa = false
CASMode = 0
AspectRatio = 16:9
LoadTextureReplacements = true
LoadTextureReplacementsAsync = false
NbaUpscaler = 2
ScreenshotSize = 0
'@
Set-Content (Join-Path $HostDir 'nba_dlss_test.ini') $ini -Encoding ascii
$reshadeLog = Join-Path $HostDir 'ReShade.log'
$start = Get-Date

# Main menu -> GAME ON with the default choices -> a match; screenshots at 150 s and 165 s.
& (Join-Path $PSScriptRoot 'run_scripted.ps1') -Seconds $Seconds `
    -Pad '97:START,101:CROSS,104:CROSS,107:CROSS,110:CROSS,113:CROSS,116:CROSS,119:CROSS,122:CROSS,126:CROSS,130:CROSS' `
    -Shots 150, 165 -Env @{ PS2X_GSHOST = $exe; PS2X_GSHOST_ARGS = '-renderer dx12 -ini nba_dlss_test.ini'; PS2X_HOST_WINDOW = '1920x1080' }

Write-Host ''
Write-Host '== Renderer (DLSS)'
$emulog = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PCSX2\logs\emulog.txt'
if (Test-Path $emulog) {
    Select-String -Path $emulog -Pattern 'DLSS ready|upscaler:|DLSS.*fail|evaluate failed' | Select-Object -First 5 | ForEach-Object { '  ' + $_.Line.Trim() }
}

Write-Host '== Add-on (ReShade.log)'
if (-not (Test-Path $reshadeLog) -or (Get-Item $reshadeLog).LastWriteTime -lt $start) {
    Write-Host '  No new ReShade.log in the renderer folder: ReShade is not installed there (or did not load).'
}
else {
    $lines = Get-Content $reshadeLog | ForEach-Object { $_ -replace '^\S+ \[\s*\d+\] \| ', '' }
    $show = $lines | Where-Object { $_ -match 'Registered add-on|hooks installed|first NGX evaluate|feature \d+ created|injection admitted|ERROR' }
    $show | Select-Object -First 12 | ForEach-Object { '  ' + $_.Substring(0, [Math]::Min(200, $_.Length)) }
    $evals = $lines | Where-Object { $_ -match 'evaluation succeeded \(count=(\d+)' } | Select-Object -Last 1
    if ($evals) { '  last evaluation report: ' + ($evals -replace '.*(evaluation succeeded \(count=\d+).*', '$1)') }
    $lines | Where-Object { $_ -match 'telemetry t=' } | ForEach-Object {
        '  ' + ($_ -replace '.*telemetry (t=\S+).*?(fps=\S+).*?(frame_ms\[avg=[^ ]+).*?(nr\[evals=\d+).*', '$1 $2 $3 $4')
    }
}
Write-Host "== Screenshots: $Root\logs\shots (sheet.png)"
