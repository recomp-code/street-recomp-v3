<#
  Recorta los "End" imposibles del CSV exportado de Ghidra. Ghidra a veces sigue un flujo falso
  y deja funciones cuyo End cae cientos de KB mas alla (incluso fuera de .text): ps2_recomp
  genera entonces una funcion C++ gigante (marco de pila enorme -> stack overflow) y le asigna
  direcciones que en realidad pertenecen a otras funciones.
  Regla: End = min(End, inicio de la siguiente funcion, fin de .text).
  Uso: fix_functions_csv.ps1 -Elf <elf> -Csv <functions.csv>   (guarda el original en *.ghidra.csv)
#>
param([string]$Elf, [string]$Csv)
$ErrorActionPreference = "Stop"

$b = [IO.File]::ReadAllBytes($Elf)
$shoff = [BitConverter]::ToUInt32($b, 0x20); $shnum = [BitConverter]::ToUInt16($b, 0x30); $shstr = [BitConverter]::ToUInt16($b, 0x32)
$so = [BitConverter]::ToUInt32($b, $shoff + $shstr * 40 + 16)
$textStart = 0; $textEnd = 0
for ($i = 0; $i -lt $shnum; $i++) {
    $s = $shoff + $i * 40; $e = $so + [BitConverter]::ToUInt32($b, $s); $q = $e; while ($b[$q] -ne 0) { $q++ }
    if ([Text.Encoding]::ASCII.GetString($b, $e, $q - $e) -eq ".text") {
        $textStart = [BitConverter]::ToUInt32($b, $s + 12); $textEnd = $textStart + [BitConverter]::ToUInt32($b, $s + 20)
    }
}

$original = [IO.Path]::ChangeExtension($Csv, ".ghidra.csv")
if (-not (Test-Path $original)) { Copy-Item $Csv $original }
$rows = Import-Csv $original
$starts = $rows | ForEach-Object { [Convert]::ToUInt32($_.Start.Substring(2), 16) } | Sort-Object -Unique
$startArr = [uint32[]]$starts

$fixed = 0
foreach ($r in $rows) {
    $s = [Convert]::ToUInt32($r.Start.Substring(2), 16); $e = [Convert]::ToUInt32($r.End.Substring(2), 16)
    $size = [uint32]$r.Size
    # Solo cuerpos claramente falsos: terminan fuera de .text o su rango es mucho mayor que su tamano real
    $bogus = ($s -ge $textStart -and $s -lt $textEnd -and $e -gt $textEnd) -or (($e - $s) -gt (4 * $size + 0x1000))
    if (-not $bogus) { continue }
    $limit = $e
    if ($s -ge $textStart -and $s -lt $textEnd -and $limit -gt $textEnd) { $limit = $textEnd }
    $idx = [Array]::BinarySearch($startArr, $s)
    if ($idx -ge 0 -and $idx + 1 -lt $startArr.Length) {
        $next = $startArr[$idx + 1]
        if ($next -lt $limit) { $limit = $next }
    }
    if ($limit -lt $e -and $limit -gt $s) {
        $r.End = "0x{0:X8}" -f $limit; $r.Size = [string]($limit - $s); $fixed++
    }
}
$rows | Export-Csv -NoTypeInformation -Encoding ASCII $Csv
# Export-Csv entrecomilla los campos; ps2_recomp espera el formato simple de Ghidra
(Get-Content $Csv) -replace '"', '' | Set-Content -Encoding ASCII $Csv
"funciones=$($rows.Count) recortadas=$fixed .text=0x{0:x}-0x{1:x}" -f $textStart, $textEnd
