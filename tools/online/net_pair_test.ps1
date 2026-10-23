# NBA Street V3 online (lockstep) test on one machine: two games, player 1 and player 2, through a local copy of the
# server's UDP relay, each with its own copy of the same memory card, then a comparison of their state hashes.
#   .\net_pair_test.ps1 -Seconds 200 [-Script1 "97:START,..."] [-Script2 "..."] [-Delay 2|auto] [-Shots 120,190]
# Logs in <Root>\logs\net_p1 and net_p2 (stderr.log has the [net] and [dethash] lines). The relay (never PS2X_NET:
# for NBA that name turns on its own network adapter) is bloody-roar4-recomp's tools\testrelay.
param(
    [int]$Seconds = 200,
    [string]$Script1 = '',
    [string]$Script2 = '',
    [string]$Delay = '2',
    [double[]]$Shots = @(120, 190),
    [string]$Rtc = '1767225600',
    [hashtable]$Env1 = @{},
    [hashtable]$Env2 = @{},
    [hashtable]$Env = @{},
    [int]$Seconds2 = 0,
    [string]$Root = 'C:\NBAOnline'
)
$R = $Root
$port = Get-Random -Minimum 20000 -Maximum 60000
$token = -join ((1..32) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
$relayExe = 'C:\BloodyRoar4Recomp\logs\testrelay.exe'
$relay = Start-Process $relayExe -ArgumentList "-listen 127.0.0.1:$port" -PassThru -WindowStyle Hidden
$tools = Split-Path -Parent $MyInvocation.MyCommand.Path
$jobs = foreach ($pl in 1, 2) {
    $e = @{ PS2X_DETERMINISTIC = '1'; PS2X_DETHASH = '60'; PS2X_RTC = $Rtc; PS2X_NET_PLAYER = "$pl"; PS2X_NET_DELAY = $Delay
            PS2X_NET_RELAY = "127.0.0.1:$port"; PS2X_NET_TOKEN = $token; PS2X_NET_STATUS_FILE = "$R\logs\net_p$pl.status" }
    foreach ($k in $Env.Keys) { $e[$k] = $Env[$k] }
    if ($pl -eq 1) { if ($Script1) { $e.PS2X_PAD_SCRIPT = $Script1 }; foreach ($k in $Env1.Keys) { $e[$k] = $Env1[$k] } }
    else { if ($Script2) { $e.PS2X_PAD_SCRIPT = $Script2 }; foreach ($k in $Env2.Keys) { $e[$k] = $Env2[$k] } }
    $sec = if ($pl -eq 2 -and $Seconds2 -gt 0) { $Seconds2 } else { $Seconds }
    Start-Job -ArgumentList "$tools\run_test.ps1", $sec, "net_p$pl", $e, $Shots, $R -ScriptBlock {
        param($script, $sec, $tag, $envs, $shots, $root)
        & $script -Seconds $sec -Tag $tag -Env $envs -Shots $shots -Root $root | Out-Null
    }
    Start-Sleep -Seconds 2
}
$jobs | Wait-Job | Remove-Job
if (-not $relay.HasExited) { Stop-Process -Id $relay.Id -Force }
foreach ($pl in 1, 2) {
    "== player $pl ($(Get-Content "$R\logs\net_p$pl.status" -ErrorAction SilentlyContinue))"
    Select-String "$R\logs\net_p$pl\stderr.log" -Pattern '^\[net\]' | Select-Object -Last 4 | ForEach-Object Line
}
$h = foreach ($pl in 1, 2) { ,@(Select-String "$R\logs\net_p$pl\stderr.log" -Pattern '^\[dethash\]' | ForEach-Object Line) }
$n = [Math]::Min($h[0].Count, $h[1].Count); $first = -1
for ($i = 0; $i -lt $n; $i++) { if ($h[0][$i] -ne $h[1][$i]) { $first = $i; break } }
if ($first -ge 0) { "hashes differ from check #$first`: $($h[0][$first]) | $($h[1][$first])" } else { "hashes equal for $n checks ($($h[0].Count) / $($h[1].Count))" }
