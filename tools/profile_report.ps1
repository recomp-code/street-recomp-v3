<#
  Convierte las muestras "[prof] exe+0x..." de runtime_err.log en funciones usando el .map del enlazador.
  Uso: profile_report.ps1 [-Log logs\runtime_err.log] [-Map <ps2EntryRunner.map>] [-Top 40] [-Block -1]
  -Block: que bloque de 10 s usar (por defecto el ultimo).
#>
param(
    [string]$Log = "C:\NBAStreetRecomp\logs\runtime_err.log",
    [string]$Map = "C:\NBAStreetRecomp\PS2Recomp\out\build\ps2xRuntime\Release\ps2EntryRunner.map",
    [int]$Top = 40,
    [int]$Block = -1
)
$ErrorActionPreference = "Stop"

# Simbolos publicos: "  0001:00000040  ?name@@...  0000000140001040 f   obj"
$base = 0x140000000
$preferred = Select-String $Map -Pattern "Preferred load address is ([0-9a-fA-F]+)" | Select-Object -First 1
if ($preferred) { $base = [Convert]::ToUInt64($preferred.Matches[0].Groups[1].Value, 16) }
$addrs = New-Object System.Collections.Generic.List[uint64]
$names = New-Object System.Collections.Generic.List[string]
foreach ($line in [IO.File]::ReadLines($Map)) {
    if ($line -match '^\s+[0-9a-fA-F]{4}:[0-9a-fA-F]{8}\s+(\S+)\s+([0-9a-fA-F]{16})\s') {
        $abs = [Convert]::ToUInt64($Matches[2], 16); if ($abs -lt $base) { continue }; $addrs.Add($abs - $base); $names.Add($Matches[1])
    }
}
$order = [uint64[]]$addrs.ToArray(); $nameArr = $names.ToArray()
[Array]::Sort($order, $nameArr)

# Bloques de muestras
$blocks = @(); $cur = $null
foreach ($line in [IO.File]::ReadLines($Log)) {
    if ($line -match '^\[prof\] samples=(\d+)') { $cur = @{ total = [int]$Matches[1]; hits = @(); ext = @() }; $blocks += $cur }
    elseif ($cur -and $line -match '^\[prof:ext\] exe\+0x([0-9A-F]+) (\d+)') { $cur.ext += , @([Convert]::ToUInt64($Matches[1], 16), [int]$Matches[2]) }
    elseif ($cur -and $line -match '^\[prof\] exe\+0x([0-9A-F]+) (\d+)') { $cur.hits += , @([Convert]::ToUInt64($Matches[1], 16), [int]$Matches[2]) }
}
if (-not $blocks) { "Sin muestras [prof] en $Log (PS2X_PROFILE=1?)"; exit 1 }
$b = $blocks[$(if ($Block -lt 0) { $blocks.Count + $Block } else { $Block })]

$byFunc = @{}
foreach ($h in $b.hits) {
    $i = [Array]::BinarySearch($order, [uint64]$h[0]); if ($i -lt 0) { $i = (-bnot $i) - 1 }
    $n = if ($i -ge 0) { $nameArr[$i] } else { "?" }
    $byFunc[$n] += $h[1]
}
"muestras del bloque: $($b.total) (solo se listan las 60 direcciones mas calientes)"
$byFunc.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First $Top |
    ForEach-Object { "{0,6} {1,5:P1}  {2}" -f $_.Value, ($_.Value / [double]$b.total), $_.Key }

# Muestras fuera del exe (esperas del SO): primer marco del exe en la pila.
$byExt = @{}
foreach ($h in $b.ext) {
    $i = [Array]::BinarySearch($order, [uint64]$h[0]); if ($i -lt 0) { $i = (-bnot $i) - 1 }
    $n = if ($i -ge 0) { $nameArr[$i] } else { "?" }
    $byExt[$n] += $h[1]
}
if ($byExt.Count) {
    "--- llamadores (desde el exe) de las muestras fuera del exe ---"
    $byExt.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First $Top |
        ForEach-Object { "{0,6} {1,5:P1}  {2}" -f $_.Value, ($_.Value / [double]$b.total), $_.Key }
}
