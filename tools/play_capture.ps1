<#
  Reproduce un flujo grabado (PS2X_LIVE_RECORD) en el host sin el juego, con unos ajustes graficos,
  y saca capturas o video por numero de vsync (identico en cada pasada).
  Uso: play_capture.ps1 -Stream logs\rec.bin -Ini nba_cmp_max.ini [-Window 1920x1080]
         [-Shots 7000,7600] [-ShotDir logs\cmp\max] [-Video logs\cmp\max.mp4 -From 7000 -Frames 1200]
         [-ExitAt 8300] [-TimeoutSec 900]
#>
param([Parameter(Mandatory)][string]$Stream, [Parameter(Mandatory)][string]$Ini, [string]$Window = '1920x1080',
      [long[]]$Shots = @(), [string]$ShotDir = '', [string]$Video = '', [long]$From = 0, [long]$Frames = 600,
      [string]$CaptureSize = '', [long]$ExitAt = 0, [int]$TimeoutSec = 900)
$G = 'C:\NBAStreetRecomp\gshost'
$vars = @{
    PS2X_LIVE_PLAYBACK = (Resolve-Path $Stream).Path; PS2X_HOST_WINDOW = $Window; PS2X_HOST_NOACTIVATE = '1'
    PS2X_SHOT_FRAMES = ($Shots -join ','); PS2X_SHOT_DIR = $ShotDir
    PS2X_CAPTURE = $Video; PS2X_CAPTURE_FROM = [string]$From; PS2X_CAPTURE_FRAMES = [string]$Frames
    PS2X_CAPTURE_SIZE = $CaptureSize; PS2X_EXIT_FRAME = [string]$ExitAt; PS2X_NO_GAMEPAD = '1'
}
if ($ShotDir) { New-Item -ItemType Directory -Force $ShotDir | Out-Null }
if ($Video) { New-Item -ItemType Directory -Force (Split-Path $Video) | Out-Null; Remove-Item $Video -ErrorAction SilentlyContinue }
$saved = @{}
foreach ($k in $vars.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $vars[$k]) }
try {
    $p = Start-Process "$G\pcsx2-gsrunner.exe" -ArgumentList "-live -window -renderer vulkan -ini $Ini" -WorkingDirectory $G -PassThru
    if (-not $p.WaitForExit($TimeoutSec * 1000)) { Stop-Process -Id $p.Id -Force; "timeout" }
} finally {
    foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
}
Select-String -Path "$env:USERPROFILE\Documents\PCSX2\logs\emulog.txt" -Pattern 'capture|playback|DLSS|upscaler|rror' | Select-Object -Last 12 | ForEach-Object { $_.Line }
