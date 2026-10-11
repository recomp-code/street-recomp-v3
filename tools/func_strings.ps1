<#
  Lista las cadenas de texto que referencia cada funcion (pares lui/addiu|ori|lw que forman una direccion
  que apunta a texto imprimible en el ELF). Uso: func_strings.ps1 -Elf <elf> -Csv <functions.csv> -Addrs 0x4222AC,0x29C378
#>
param([string]$Elf, [string]$Csv, [string[]]$Addrs)
$b = [IO.File]::ReadAllBytes($Elf)
$phoff = [BitConverter]::ToUInt32($b, 0x1C)
$segs = @()
$phnum = [BitConverter]::ToUInt16($b, 0x2C)
for ($i = 0; $i -lt $phnum; $i++) { $p = $phoff + $i * 32; if ([BitConverter]::ToUInt32($b, $p) -eq 1) { $segs += , @([BitConverter]::ToUInt32($b, $p + 8), [BitConverter]::ToUInt32($b, $p + 4), [BitConverter]::ToUInt32($b, $p + 16)) } }
function Off([uint32]$va) { foreach ($s in $segs) { if ($va -ge $s[0] -and $va -lt $s[0] + $s[2]) { return [int]($va - $s[0] + $s[1]) } }; return -1 }
function Str([uint32]$va) {
    $o = Off $va; if ($o -lt 0) { return $null }
    $e = $o; while ($e -lt $b.Length -and $b[$e] -ge 0x20 -and $b[$e] -lt 0x7F -and ($e - $o) -lt 120) { $e++ }
    if ($e - $o -ge 4 -and $b[$e] -eq 0) { return [Text.Encoding]::ASCII.GetString($b, $o, $e - $o) }
    return $null
}
$funcs = Import-Csv $Csv | ForEach-Object { [pscustomobject]@{ n = $_.Name; s = [Convert]::ToUInt32($_.Start.Substring(2), 16); e = [Convert]::ToUInt32($_.End.Substring(2), 16) } }
foreach ($a in $Addrs) {
    $addr = if ("$a" -match "^0x") { [Convert]::ToUInt32("$a".Substring(2), 16) } else { [uint32]"$a" }
    $f = $funcs | Where-Object { $_.s -le $addr -and $_.e -gt $addr } | Sort-Object { $_.e - $_.s } | Select-Object -First 1
    if (-not $f) { "0x{0:X}: (sin funcion)" -f $addr; continue }
    $hi = @{}; $found = New-Object System.Collections.Generic.List[string]
    for ($pc = $f.s; $pc -lt $f.e; $pc += 4) {
        $o = Off $pc; if ($o -lt 0) { break }
        $w = [BitConverter]::ToUInt32($b, $o); $op = $w -shr 26; $rs = ($w -shr 21) -band 31; $rt = ($w -shr 16) -band 31; $imm = $w -band 0xFFFF
        if ($op -eq 0xF) { $hi[$rt] = [uint32]($imm -shl 16); continue }
        if (($op -eq 9 -or $op -eq 0x23 -or $op -eq 0xD) -and $hi.ContainsKey($rs)) {
            $v = if ($op -eq 0xD) { $hi[$rs] -bor $imm } else { [uint32](($hi[$rs] + [int16]$imm) -band 0xFFFFFFFF) }
            $s = Str $v; if ($s -and -not $found.Contains($s)) { $found.Add($s) }
        }
    }
    "0x{0:X} {1} [{2:X}-{3:X}]: {4}" -f $addr, $f.n, $f.s, $f.e, (($found | Select-Object -First 8) -join " | ")
}
