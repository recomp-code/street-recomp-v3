<#
  Ejecuta el juego, pulsa teclas en momentos dados (Enter = START, X = Cruz) y captura la ventana
  justo antes de cada pulsacion y al final (logs\keys_<n>.png).
  Uso: run_with_keys.ps1 -Seconds 60 -At 20,25,30 -Keys ENTER,X [-HoldMs 800]
#>
param([int]$Seconds = 60, [int[]]$At = @(20, 25, 30), [string[]]$Keys = @("ENTER", "X"), [int]$HoldMs = 800,
      [int[]]$ShotAt = @(), [switch]$Live, [switch]$Seq)
$W = "C:\NBAStreetRecomp"
$exe = "$W\PS2Recomp\out\build\ps2xRuntime\Release\ps2EntryRunner.exe"
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class KeyInput {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowW(string cls, string title);
}
"@
[void][KeyInput]::SetProcessDPIAware()
function Get-HostWindow { $g = Get-CimInstance Win32_Process -Filter "Name='pcsx2-gsrunner.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match "-livering $($p.Id)\b" } | ForEach-Object { Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue } | Select-Object -First 1; if ($g) { $g.Refresh(); return $g.MainWindowHandle }; return [IntPtr]::Zero }
function Save-Shot($proc, $path) {
    $proc.Refresh(); $h = $proc.MainWindowHandle; if ($Live) { $h = Get-HostWindow }
    if ($h -eq [IntPtr]::Zero) { return }
    [void][KeyInput]::SetForegroundWindow($h); Start-Sleep -Milliseconds 200
    $r = New-Object KeyInput+RECT; [void][KeyInput]::GetWindowRect($h, [ref]$r)
    $w = $r.R - $r.L; $hh = $r.B - $r.T; if ($w -le 0 -or $hh -le 0) { return }
    $bmp = New-Object Drawing.Bitmap $w, $hh; $g = [Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size); $bmp.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose(); "captura $path"
}
$vk = @{ F1 = 0x70; ESC = 0x1B; ENTER = 0x0D; X = 0x58; Z = 0x5A; C = 0x43; V = 0x56; UP = 0x26; DOWN = 0x28; LEFT = 0x25; RIGHT = 0x27 }
if ($Live) { $env:PS2X_GS_LIVE = "1" } else { $env:PS2X_GS_LIVE = "" }
$p = Start-Process $exe -ArgumentList "$W\game\iso\SLUS_211.26" -WorkingDirectory "$W\game\iso" `
     -RedirectStandardOutput "$W\logs\runtime.log" -RedirectStandardError "$W\logs\runtime_err.log" -PassThru
$start = Get-Date
$n = 0
# -ShotAt: capturas sin pulsar nada (se mezclan con las pulsaciones por orden de tiempo).
# -Seq: Keys[i] se pulsa en At[i] (en vez de todas las teclas en cada instante).
$pi = 0
$events = @($At | ForEach-Object { [pscustomobject]@{ T = $_; Press = $true; I = ($pi++) } }) + @($ShotAt | ForEach-Object { [pscustomobject]@{ T = $_; Press = $false } })
foreach ($ev in ($events | Sort-Object T)) {
    $t = $ev.T
    $wait = $t - ((Get-Date) - $start).TotalSeconds
    if ($wait -gt 0) { Start-Sleep -Milliseconds ([int]($wait * 1000)) }
    if ($p.HasExited) { break }
    $n++; Save-Shot $p "$W\logs\keys_$n.png"
    if (-not $ev.Press) { continue }
    $p.Refresh(); $fw = $p.MainWindowHandle; if ($Live) { $fw = Get-HostWindow }; [void][KeyInput]::SetForegroundWindow($fw); Start-Sleep -Milliseconds 200
    $pressKeys = if ($Seq) { @($Keys[[math]::Min($ev.I, $Keys.Count - 1)]) } else { $Keys }
    foreach ($k in $pressKeys) {
        [KeyInput]::keybd_event([byte]$vk[$k], 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds $HoldMs
        [KeyInput]::keybd_event([byte]$vk[$k], 0, 2, [UIntPtr]::Zero); Start-Sleep -Milliseconds 300
    }
    "pulsado $($pressKeys -join '+') a los $t s"
}
$rest = $Seconds - ((Get-Date) - $start).TotalSeconds
if ($rest -gt 0 -and -not $p.HasExited) { [void]$p.WaitForExit([int]($rest * 1000)) }
if (-not $p.HasExited) { $n++; Save-Shot $p "$W\logs\keys_$n.png"; $p.Kill(); [void]$p.WaitForExit(10000) }

# El host (pcsx2-gsrunner) se cierra solo cuando su juego termina (vigila su PID).


