param([string]$Iso, [string]$Out)
# Lista local de archivos de una ISO9660 (nombre, tamano, LBA). No sale nada del equipo.
$fs = [IO.File]::OpenRead($Iso)
function ReadSectors($lba, $len) { $buf = New-Object byte[] $len; $fs.Position = [int64]$lba * 2048; [void]$fs.Read($buf, 0, $len); , $buf }
$pvd = ReadSectors 16 2048
$list = New-Object Collections.Generic.List[string]
function Walk($lba, $size, $path) {
    $d = ReadSectors $lba $size; $i = 0
    while ($i -lt $size) {
        $len = $d[$i]
        if ($len -eq 0) { $i = ([math]::Floor($i / 2048) + 1) * 2048; continue }
        $el = [BitConverter]::ToUInt32($d, $i + 2); $sz = [BitConverter]::ToUInt32($d, $i + 10)
        $fl = $d[$i + 25]; $nl = $d[$i + 32]
        $n = [Text.Encoding]::ASCII.GetString($d, $i + 33, $nl)
        $semi = $n.IndexOf([char]';'); if ($semi -ge 0) { $n = $n.Substring(0, $semi) }
        if ($nl -eq 1 -and $d[$i + 33] -le 1) { }
        elseif ($fl -band 2) { Walk $el $sz ($path + '/' + $n) }
        else { $list.Add(("{0,-50} {1,12} lba={2}" -f ($path + '/' + $n), $sz, $el)) }
        $i += $len
    }
}
Walk ([BitConverter]::ToUInt32($pvd, 158)) ([BitConverter]::ToUInt32($pvd, 166)) ""
$fs.Close()
$list | Set-Content -Encoding ASCII $Out
"files=$($list.Count)"

