# NBA Street V3 test run of the online (lockstep) build: starts the game for N seconds with the shared GS host,
# asks the host for screenshots and closes it. Only the processes it starts are stopped.
#   .\run_test.ps1 -Seconds 120 -Shots 60,100 [-Tag x] [-Env @{PS2X_PAD_SCRIPT="97:START"}]
# Screenshots in <Root>\logs\<tag>\shot_*.png, game logs in stdout/stderr.log. The disc is the user's extracted copy
# (C:\NBAStreetRecomp\game\iso), never modified; each run gets its own memory card copy (PS2X_MC_ROOT).
param(
    [int]$Seconds = 120,
    [double[]]$Shots = @(),
    [string]$Tag = 'test',
    [string]$Ini = 'nba_test.ini',
    [hashtable]$Env = @{},
    [string]$Card = 'C:\NBAStreetRecomp\game\iso\mc0', # copied, not used in place
    [string]$Root = 'C:\NBAOnline'
)
$R = $Root
$rt = "$R\PS2Recomp\out\build\ps2xRuntime\Release"
$iso = if ($env:NBA_TEST_DATA) { $env:NBA_TEST_DATA } else { 'C:\NBAStreetRecomp\game\iso' }
$out = "$R\logs\$Tag"
New-Item -ItemType Directory -Force $out | Out-Null
Get-ChildItem $out -File -ErrorAction SilentlyContinue | Remove-Item -Force
$mc = "$out\mc0"
if (Test-Path $mc) { Remove-Item -Recurse -Force $mc }
if ($Card -and (Test-Path $Card)) { Copy-Item -Recurse $Card $mc } else { New-Item -ItemType Directory $mc | Out-Null }

$vars = @{
    PS2X_GS_LIVE = '1'; PS2X_GSHOST = "$R\gshost\pcsx2-gsrunner.exe"; PS2X_GSHOST_ARGS = "-renderer vulkan -ini $R\gshost\$Ini"
    PS2X_LIVE_SERIAL = 'SLUS-21126'; PS2X_LIVE_TITLE = "NBA Street V3 ($Tag)"; PS2X_HOST_WINDOW = '960x540'
    PS2X_FPS_LOG = '1'; PS2X_SHOT_DIR = $out; PS2X_HOST_NOACTIVATE = '1'; PS2X_NO_GAMEPAD = '1'; PS2X_MC_ROOT = $mc
}
foreach ($k in $Env.Keys) { $vars[$k] = $Env[$k] }
foreach ($k in $vars.Keys) { Set-Item "env:$k" ([string]$vars[$k]) } # this process only (a job or a shell of its own)
$p = Start-Process "$rt\ps2EntryRunner.exe" -ArgumentList "`"$iso\SLUS_211.26`"" -WorkingDirectory $iso `
     -RedirectStandardOutput "$out\stdout.log" -RedirectStandardError "$out\stderr.log" -PassThru -WindowStyle Minimized
$t0 = Get-Date
$pending = [System.Collections.Generic.List[double]]::new(); $Shots | ForEach-Object { $pending.Add($_) }
while (-not $p.HasExited -and ((Get-Date) - $t0).TotalSeconds -lt $Seconds) {
    $el = ((Get-Date) - $t0).TotalSeconds
    if ($pending.Count -gt 0 -and $el -ge $pending[0]) {
        [IO.File]::WriteAllText("$out\host.req", ("shot_{0:000.0}.png" -f $pending[0]).Replace(',', '.'))
        $pending.RemoveAt(0)
    }
    Start-Sleep -Milliseconds 500
}
$exited = $p.HasExited
Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'pcsx2-gsrunner.exe' -and $_.ParentProcessId -eq $p.Id } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
"exited_by_itself=$exited after {0:N0}s" -f ((Get-Date) - $t0).TotalSeconds
