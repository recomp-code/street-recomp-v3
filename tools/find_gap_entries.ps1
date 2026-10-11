<#
  Busca codigo que Ghidra no metio en ninguna funcion (huecos en .text) y genera "entry_points"
  para ps2_recomp. Candidatos:
    - primer instruccion no-nula de cada hueco y la siguiente tras cada "jr $ra" + delay slot
    - cualquier palabra de .data/.rodata/.sdata que apunte dentro de un hueco (vtables, callbacks)
  Uso: find_gap_entries.ps1 -Elf <elf> -Csv <functions.csv> -Out <entries.txt>
#>
param([string]$Elf, [string]$Csv, [string]$Out)
$ErrorActionPreference = "Stop"

$b = [IO.File]::ReadAllBytes($Elf)
$phoff = [BitConverter]::ToUInt32($b, 0x1C); $phnum = [BitConverter]::ToUInt16($b, 0x2C)
$va = 0; $off = 0
for ($i = 0; $i -lt $phnum; $i++) { $p = $phoff + $i * 32; if ([BitConverter]::ToUInt32($b, $p) -eq 1) { $off = [BitConverter]::ToUInt32($b, $p + 4); $va = [BitConverter]::ToUInt32($b, $p + 8); break } }

# Secciones
$sections = @{}
$shoff = [BitConverter]::ToUInt32($b, 0x20); $shnum = [BitConverter]::ToUInt16($b, 0x30); $shstr = [BitConverter]::ToUInt16($b, 0x32)
$so = [BitConverter]::ToUInt32($b, $shoff + $shstr * 40 + 16)
for ($i = 0; $i -lt $shnum; $i++) {
    $s = $shoff + $i * 40; $e = $so + [BitConverter]::ToUInt32($b, $s); $q = $e; while ($b[$q] -ne 0) { $q++ }
    $sections[[Text.Encoding]::ASCII.GetString($b, $e, $q - $e)] = @{ addr = [BitConverter]::ToUInt32($b, $s + 12); size = [BitConverter]::ToUInt32($b, $s + 20) }
}
$textStart = [uint32]$sections[".text"].addr; $textEnd = [uint32]($textStart + $sections[".text"].size)
function Word([uint32]$a) { [BitConverter]::ToUInt32($b, [int]($a - $va + $off)) }

# Cobertura de funciones del CSV (bitmap por palabra)
$words = [int](($textEnd - $textStart) / 4)
$covered = New-Object bool[] $words
foreach ($r in (Import-Csv $Csv)) {
    $s = [Convert]::ToUInt32($r.Start.Substring(2), 16); $e = [Convert]::ToUInt32($r.End.Substring(2), 16)
    if ($e -le $s -or $s -lt $textStart -or $s -ge $textEnd) { continue }
    if ($e -gt $textEnd) { $e = $textEnd }
    for ($a = $s; $a -lt $e; $a += 4) { $covered[[int](($a - $textStart) / 4)] = $true }
}

$entries = New-Object 'System.Collections.Generic.SortedSet[uint32]'
$gapWords = 0; $gaps = 0
$i = 0
while ($i -lt $words) {
    if ($covered[$i]) { $i++; continue }
    $gaps++; $expectStart = $true; $sawJrRa = $false
    while ($i -lt $words -and -not $covered[$i]) {
        $gapWords++
        $addr = [uint32]($textStart + $i * 4); $w = Word $addr
        if ($sawJrRa) { $sawJrRa = $false; $expectStart = $true }   # delay slot de jr ra / j
        elseif ($w -eq 0) { }                                           # nop / relleno
        else {
            if ($expectStart) { [void]$entries.Add($addr); $expectStart = $false }
            if ($w -eq 0x03E00008 -or (($w -shr 26) -eq 2)) { $sawJrRa = $true }  # jr ra o j (llamada de cola)
        }
        $i++
    }
}
$fromGaps = $entries.Count

# Punteros desde datos hacia huecos. Solo cuentan si caen en un limite real de funcion
# (inicio de hueco o justo tras "jr ra"/"j" + delay slot, saltando relleno): los demas suelen
# ser "case" de un switch (tabla de saltos) y partir la funcion ahi deja saltos internos huerfanos.
function Test-FunctionBoundary([uint32]$v) {
    $p = [uint32]($v - 4)
    while ($p -ge $textStart -and -not $covered[[int](($p - $textStart) / 4)] -and (Word $p) -eq 0) { $p = [uint32]($p - 4) }
    if ($p -lt $textStart -or $covered[[int](($p - $textStart) / 4)]) { return $true }   # inicio de hueco
    $isEnd = { param($w) $w -eq 0x03E00008 -or (($w -shr 26) -eq 2) }
    if (& $isEnd (Word $p)) { return $true }                 # delay slot era nop
    if ($p - 4 -ge $textStart -and (& $isEnd (Word ([uint32]($p - 4))))) { return $true }  # p es el delay slot
    return $false
}
$fromData = 0
foreach ($name in ".data", ".rodata", ".sdata") {
    $sec = $sections[$name]; if (-not $sec) { continue }
    for ($a = [uint32]$sec.addr; $a -lt $sec.addr + $sec.size; $a += 4) {
        $v = Word $a
        if ($v -lt $textStart -or $v -ge $textEnd -or ($v % 4) -ne 0) { continue }
        if ($covered[[int](($v - $textStart) / 4)]) { continue }
        if ((Word $v) -eq 0) { continue }
        if (-not (Test-FunctionBoundary $v)) { continue }
        if ($entries.Add($v)) { $fromData++ }
    }
}

$entries | ForEach-Object { "entry_{0:x8}@0x{0:X8}" -f $_ } | Set-Content -Encoding ASCII $Out
"huecos=$gaps palabras_sin_cubrir=$gapWords candidatos_por_hueco=$fromGaps extra_por_punteros=$fromData total=$($entries.Count)"
