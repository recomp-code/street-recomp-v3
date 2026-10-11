<#
  Prueba automatica SIN tocar el escritorio del usuario: los botones los inyecta el propio juego
  (PS2X_PAD_SCRIPT) y las capturas las guarda el host desde su render (PS2X_SHOT_TIMES), con la
  ventana abierta sin robar el foco y el mando fisico ignorado. Usa gshost\nba_test.ini.
  Uso: run_scripted.ps1 -Seconds 120 -Pad "98:START,104:DOWN" -Shots 100,106 [-Env @{PS2X_NET='1'}]
  Capturas: logs\shots\shot_<n>.png (+ logs\shots\sheet.png con miniaturas).
#>
param([int]$Seconds = 120, [string]$Pad = "", [double[]]$Shots = @(), [hashtable]$Env = @{}, [switch]$Force)
$W = "C:\NBAStreetRecomp"
$exe = "$W\PS2Recomp\out\build\ps2xRuntime\Release\ps2EntryRunner.exe"
if (-not $Force -and (Get-Process ps2EntryRunner -ErrorAction SilentlyContinue)) { "Hay una partida abierta: no pruebo ahora."; exit 2 }
$shotDir = "$W\logs\shots"
New-Item -ItemType Directory -Force $shotDir | Out-Null
Get-ChildItem $shotDir -Filter *.png -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
if (-not (Test-Path "$W\gshost\nba_test.ini")) { Copy-Item "$W\gshost\nba_street.ini" "$W\gshost\nba_test.ini" }
$vars = @{
    PS2X_GS_LIVE = '1'; PS2X_NO_GAMEPAD = '1'; PS2X_HOST_NOACTIVATE = '1'
    PS2X_GSHOST_ARGS = '-renderer vulkan -ini nba_test.ini'
    PS2X_PAD_SCRIPT = $Pad; PS2X_SHOT_TIMES = ($Shots -join ','); PS2X_SHOT_DIR = $shotDir
    PS2X_TEST_T0 = [string][DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
}
foreach ($k in $Env.Keys) { $vars[$k] = $Env[$k] }
$saved = @{}
foreach ($k in $vars.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $vars[$k]) }
try {
    $p = Start-Process $exe -ArgumentList "$W\game\iso\SLUS_211.26" -WorkingDirectory "$W\game\iso" `
         -RedirectStandardOutput "$W\logs\runtime.log" -RedirectStandardError "$W\logs\runtime_err.log" -PassThru -WindowStyle Minimized
    [void]$p.WaitForExit($Seconds * 1000)
    if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
} finally {
    foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
}
# Hoja de miniaturas
Add-Type -AssemblyName System.Drawing
$files = Get-ChildItem $shotDir -Filter 'shot_*.png' | Sort-Object { [int]($_.BaseName -replace '\D', '') }
if ($files) {
    $cols = 2; $w = 480; $h = 270; $rows = [math]::Ceiling($files.Count / $cols)
    $sheet = New-Object Drawing.Bitmap ($cols * $w), ($rows * $h); $g = [Drawing.Graphics]::FromImage($sheet)
    $font = New-Object Drawing.Font 'Arial', 18
    for ($i = 0; $i -lt $files.Count; $i++) {
        $img = [Drawing.Bitmap]::FromFile($files[$i].FullName)
        $x = ($i % $cols) * $w; $y = [math]::Floor($i / $cols) * $h
        $g.DrawImage($img, $x, $y, $w, $h); $g.DrawString($files[$i].BaseName, $font, [Drawing.Brushes]::Yellow, $x + 4, $y + 4)
        $img.Dispose()
    }
    $sheet.Save("$shotDir\sheet.png"); $g.Dispose(); $sheet.Dispose()
    "capturas: $($files.Count) -> $shotDir\sheet.png"
} else { "sin capturas" }
