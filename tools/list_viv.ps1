# Lista el directorio de un archivo VIV/BIG de EA dentro de la ISO (solo lectura local).
# Uso: list_viv.ps1 -Lba <lba> [-Iso <ruta>]
param([long]$Lba, [string]$Iso = "C:\NBAStreetRecomp\game\NBAStreetV3.iso", [int]$Max = 400)
$fs = [IO.File]::OpenRead($Iso)
try {
    $buf = New-Object byte[] 262144
    $fs.Position = $Lba * 2048
    [void]$fs.Read($buf, 0, $buf.Length)
    function BE32([int]$p) { return ([long]$buf[$p] -shl 24) -bor ([long]$buf[$p+1] -shl 16) -bor ([long]$buf[$p+2] -shl 8) -bor [long]$buf[$p+3] }
    $magic = [Text.Encoding]::ASCII.GetString($buf, 0, 4)
    $count = BE32 8
    $hdr = BE32 12
    "magic=$magic count=$count headerLen=$hdr head=" + (($buf[0..15] | ForEach-Object { $_.ToString('x2') }) -join ' ')
    if ($count -le 0 -or $count -gt 100000) { return }
    $p = 16
    for ($i = 0; $i -lt [Math]::Min($count, $Max); $i++) {
        if ($p + 9 -ge $buf.Length) { break }
        $off = BE32 $p; $size = BE32 ($p + 4); $p += 8
        $e = $p
        while ($e -lt $buf.Length -and $buf[$e] -ne 0) { $e++ }
        $name = [Text.Encoding]::ASCII.GetString($buf, $p, $e - $p)
        $p = $e + 1
        "{0,10} {1,10} {2}" -f $off, $size, $name
    }
} finally { $fs.Close() }
