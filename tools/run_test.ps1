<#
  Ejecuta ps2EntryRunner un tiempo fijo y resume los bloqueos tipicos del log.
  Uso: run_test.ps1 [-Seconds 90]
#>
param([int]$Seconds = 90)
$W = "C:\NBAStreetRecomp"
$exe = "$W\PS2Recomp\out\build\ps2xRuntime\Release\ps2EntryRunner.exe"
$out = "$W\logs\runtime.log"; $err = "$W\logs\runtime_err.log"
if (-not (Test-Path $exe)) { "No existe $exe"; exit 1 }

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class Win32Shot {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
# Sin esto, en pantallas con escalado (4K al 200%) las coordenadas salen reducidas.
[void][Win32Shot]::SetProcessDPIAware()
function Save-WindowShot($proc, $path) {
    $proc.Refresh(); $h = $proc.MainWindowHandle
    if ($h -eq [IntPtr]::Zero) { return $false }
    [void][Win32Shot]::SetForegroundWindow($h); Start-Sleep -Milliseconds 300
    $r = New-Object Win32Shot+RECT; [void][Win32Shot]::GetWindowRect($h, [ref]$r)
    $w = $r.R - $r.L; $hh = $r.B - $r.T; if ($w -le 0 -or $hh -le 0) { return $false }
    $bmp = New-Object Drawing.Bitmap $w, $hh; $g = [Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size); $bmp.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose(); return $true
}

$p = Start-Process $exe -ArgumentList "$W\game\iso\SLUS_211.26" -WorkingDirectory "$W\game\iso" `
     -RedirectStandardOutput $out -RedirectStandardError $err -PassThru
# El panel "Runtime Debugger" ya arranca oculto (F1 lo muestra); solo se espera a la ventana.
Add-Type -AssemblyName System.Windows.Forms
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 500; $p.Refresh()
    if ($p.MainWindowHandle -ne [IntPtr]::Zero) {
        Start-Sleep -Seconds 2
        break
    }
}
# Capturas a 1/3, 2/3 y al final del tiempo
$shots = @()
foreach ($k in 1..3) {
    if ($p.WaitForExit([int]($Seconds * 1000 / 3))) { break }
    $shot = "$W\logs\shot_$k.png"; if (Save-WindowShot $p $shot) { $shots += $shot }
}
if ($p.HasExited) { "Salio solo con codigo $($p.ExitCode)" }
else {
    "Seguia vivo a los $Seconds s (CPU $([int]$p.CPU) s); cerrado"
    try { $p.Kill() } catch { Stop-Process -Id $p.Id -Force -Confirm:$false -ErrorAction SilentlyContinue }
    if (-not $p.WaitForExit(10000)) { "AVISO: no se pudo cerrar el proceso $($p.Id)" }
}
if ($shots) { "Capturas: " + ($shots -join ", ") }
Start-Sleep 1

$all = @(Get-Content $out -ErrorAction SilentlyContinue) + @(Get-Content $err -ErrorAction SilentlyContinue)
# Los mensajes del runtime no siempre terminan en salto de linea: se separan por "[".
$msgs = ($all -join "`n") -split '(?=\[[A-Za-z][\w:/ -]*\])' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

"`n== Eventos (sin ticks ni raylib), primeros 40"
$msgs | Where-Object { $_ -notmatch '^\[run:tick\]' -and $_ -notmatch '^INFO:' } | Select-Object -First 40 | ForEach-Object { $_.Substring(0, [Math]::Min(300, $_.Length)) }

"`n== Conteo por tipo"
$msgs | ForEach-Object { if ($_ -match '^\[([^\]]+)\]') { $Matches[1] } } | Group-Object | Sort-Object Count -Descending | Select-Object -First 25 | ForEach-Object { "{0,6}  {1}" -f $_.Count, $_.Name }

"`n== Ultimos ticks"
$msgs | Where-Object { $_ -match '^\[run:tick\]' } | Select-Object -Last 3

