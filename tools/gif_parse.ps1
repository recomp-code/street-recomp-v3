<#
  Recorre un paquete GIF binario (tags + datos) y lista tags y registros A+D relevantes.
  Uso: gif_parse.ps1 <archivo.bin> [-Max 60]
#>
param([Parameter(Mandatory)][string]$File, [int]$Max = 60)
$b = [IO.File]::ReadAllBytes($File)
$regNames = @{ 0x00='PRIM'; 0x06='TEX0_1'; 0x4C='FRAME_1'; 0x4E='ZBUF_1'; 0x50='BITBLTBUF'; 0x51='TRXPOS'; 0x52='TRXREG'; 0x53='TRXDIR'; 0x3F='TEXFLUSH'; 0x18='XYOFFSET_1'; 0x40='SCISSOR_1' }
$off = 0; $n = 0
while ($off + 16 -le $b.Length -and $n -lt $Max) {
    $lo = [BitConverter]::ToUInt64($b, $off); $hi = [BitConverter]::ToUInt64($b, $off + 8)
    $nloop = $lo -band 0x7FFF; $eop = ($lo -shr 15) -band 1; $flg = ($lo -shr 58) -band 3; $nreg = ($lo -shr 60) -band 0xF; if ($nreg -eq 0) { $nreg = 16 }
    $kind = @('PACKED','REGLIST','IMAGE','IMAGE2')[$flg]
    "[{0:X6}] tag nloop={1} eop={2} {3} nreg={4} regs={5:X}" -f $off, $nloop, $eop, $kind, $nreg, $hi
    $off += 16; $n++
    if ($flg -eq 0) {
        $isAD = ($nreg -eq 1 -and ($hi -band 0xF) -eq 0xE)
        if ($isAD) {
            for ($i = 0; $i -lt $nloop -and $off + 16 -le $b.Length; $i++) {
                $data = [BitConverter]::ToUInt64($b, $off); $addr = $b[$off + 8]
                $name = $regNames[[int]$addr]; if (-not $name) { $name = "0x{0:X2}" -f $addr }
                if ($name -in 'BITBLTBUF','TRXPOS','TRXREG','TRXDIR','FRAME_1','TEX0_1') { "     A+D {0} = {1:X16}" -f $name, $data }
                $off += 16
            }
        } else { $off += $nloop * $nreg * 16 }
    } elseif ($flg -eq 1) { $off += [int][Math]::Ceiling($nloop * $nreg / 2.0) * 16 }
    else { $off += $nloop * 16 }
}
"fin en 0x{0:X} de 0x{1:X}" -f $off, $b.Length
