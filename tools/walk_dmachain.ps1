<#
  Recorre una cadena DMA (source chain) en un volcado de RAM del EE y decodifica su contenido.
  Uso: walk_dmachain.ps1 -Dump logs\ramdump.bin.ee -Tadr 0xe9c700 [-Vif] [-MaxTags 400]
  -Vif: el canal es VIF0/VIF1 (los 64 bits altos de cada DMAtag son 2 VIFcodes y los datos son VIFcodes).
#>
param([string]$Dump, [string]$Tadr, [switch]$Vif, [switch]$Gif, [switch]$ShowAllAD, [int]$MaxTags = 400)
$ErrorActionPreference = "Stop"
$ram = [IO.File]::ReadAllBytes($Dump)
function U32([uint32]$a) { [BitConverter]::ToUInt32($ram, [int]($a -band 0x1FFFFFF)) }
function U64([uint32]$a) { [BitConverter]::ToUInt64($ram, [int]($a -band 0x1FFFFFF)) }

$ids = "refe", "cnt", "next", "ref", "refs", "call", "ret", "end"
$vifNames = @{ 0x00 = "NOP"; 0x01 = "STCYCL"; 0x02 = "OFFSET"; 0x03 = "BASE"; 0x04 = "ITOP"; 0x05 = "STMOD"; 0x06 = "MSKPATH3"; 0x07 = "MARK";
    0x10 = "FLUSHE"; 0x11 = "FLUSH"; 0x13 = "FLUSHA"; 0x14 = "MSCAL"; 0x15 = "MSCALF"; 0x17 = "MSCNT"; 0x20 = "STMASK"; 0x30 = "STROW"; 0x31 = "STCOL";
    0x4A = "MPG"; 0x50 = "DIRECT"; 0x51 = "DIRECTHL" }
$stats = @{}

$gsRegs = @{ 0 = "PRIM"; 1 = "RGBAQ"; 2 = "ST"; 3 = "UV"; 4 = "XYZF2"; 5 = "XYZ2"; 6 = "TEX0_1"; 7 = "TEX0_2"; 8 = "CLAMP_1"; 0xA = "FOG"; 0xC = "XYZF3"; 0xD = "XYZ3"; 0xE = "A+D"; 0xF = "NOP" }
$adRegs = @{ 0x00 = "PRIM"; 0x06 = "TEX0_1"; 0x14 = "TEX1_1"; 0x16 = "TEX2_1"; 0x18 = "XYOFFSET_1"; 0x1A = "PRMODECONT"; 0x3B = "TEXA"; 0x3F = "TEXFLUSH";
    0x40 = "SCISSOR_1"; 0x42 = "ALPHA_1"; 0x44 = "DIMX"; 0x45 = "DTHE"; 0x46 = "COLCLAMP"; 0x47 = "TEST_1"; 0x49 = "FBA_1"; 0x4C = "FRAME_1"; 0x4E = "ZBUF_1";
    0x50 = "BITBLTBUF"; 0x51 = "TRXPOS"; 0x52 = "TRXREG"; 0x53 = "TRXDIR"; 0x1C = "TEXCLUT"; 0x08 = "CLAMP_1"; 0x34 = "MIPTBP1_1" }
# Decodifica paquetes GIF (GIFtag + datos) en [addr, addr+bytes)
function Decode-Gif([uint32]$addr, [int]$bytes) {
    $pos = 0
    while ($pos + 16 -le $bytes) {
        $lo = U64 ($addr + $pos); $hi = U64 ($addr + $pos + 8); $pos += 16
        $nloop = [int]($lo -band 0x7FFF); $eop = ($lo -shr 15) -band 1; $pre = ($lo -shr 46) -band 1
        $prim = [int](($lo -shr 47) -band 0x7FF); $flg = [int](($lo -shr 58) -band 3); $nreg = [int](($lo -shr 60) -band 0xF); if ($nreg -eq 0) { $nreg = 16 }
        $regs = @(); for ($r = 0; $r -lt $nreg; $r++) { $regs += [int](($hi -shr (4 * $r)) -band 0xF) }
        $flgName = "PACKED", "REGLIST", "IMAGE", "IMAGE"
        $regNames = ($regs | ForEach-Object { $n = $gsRegs[$_]; if ($n) { $n } else { "r$_" } }) -join ","
        "        GIFtag {0} nloop={1} eop={2}{3} regs=[{4}]" -f $flgName[$flg], $nloop, $eop, $(if ($pre) { " prim=0x{0:x} (type {1} tme {2})" -f $prim, ($prim -band 7), (($prim -shr 4) -band 1) } else { "" }), $regNames
        if ($flg -eq 0) {
            for ($l = 0; $l -lt $nloop; $l++) {
                foreach ($r in $regs) {
                    if ($r -eq 0xE -and ($l -lt 4 -or $ShowAllAD)) {
                        $data = U64 ($addr + $pos); $reg = [int]((U64 ($addr + $pos + 8)) -band 0xFF)
                        $n = $adRegs[$reg]; if (-not $n) { $n = "0x{0:x2}" -f $reg }
                        "          A+D {0} = 0x{1:x16}" -f $n, $data
                    }
                    $pos += 16
                }
            }
        } elseif ($flg -eq 1) { $pos += [int][Math]::Ceiling($nloop * $nreg / 2.0) * 16 }
        else { $pos += $nloop * 16 }
        if ($eop) { if ($pos -lt $bytes) { continue } else { break } }
    }
}

# Decodifica VIFcodes en [addr, addr+bytes); devuelve cuantos bytes de datos quedan pendientes (no usado)
function Decode-Vif([uint32]$addr, [int]$bytes) {
    $pos = 0
    while ($pos + 4 -le $bytes) {
        $code = U32 ($addr + $pos); $pos += 4
        $cmd = ($code -shr 24) -band 0x7F; $num = ($code -shr 16) -band 0xFF; $imm = $code -band 0xFFFF
        if (($cmd -band 0x60) -eq 0x60) {
            $vn = ($cmd -shr 2) -band 3; $vl = $cmd -band 3
            $n = if ($num -eq 0) { 256 } else { $num }
            $bitsPer = (32 -shr $vl) * ($vn + 1)
            $len = [int][Math]::Ceiling($n * $bitsPer / 32.0) * 4
            $name = "UNPACK V{0}-{1}" -f ($vn + 1), (32 -shr $vl)
            $stats[$name]++
            "      {0} num={1} addr=0x{2:x} {3}{4}" -f $name, $n, ($imm -band 0x3FF), $(if ($imm -band 0x8000) { "+TOPS " } else { "" }), $(if ($cmd -band 0x10) { "MASK" } else { "" })
            $pos += $len
            continue
        }
        $name = $vifNames[$cmd]; if (-not $name) { $name = "?0x{0:x2}" -f $cmd }
        $stats[$name]++
        switch ($cmd) {
            0x14 { "      MSCAL pc=0x{0:x}" -f ($imm * 8) }
            0x15 { "      MSCALF pc=0x{0:x}" -f ($imm * 8) }
            0x4A { "      MPG num={0} addr=0x{1:x}" -f $(if ($num -eq 0) { 256 } else { $num }), ($imm * 8); $pos += $(if ($num -eq 0) { 256 } else { $num }) * 8 }
            0x50 {
                $qw = $(if ($imm -eq 0) { 65536 } else { $imm })
                "      DIRECT qw={0}" -f $qw
                if ($Gif) { Decode-Gif ($addr + $pos) ($qw * 16) }
                $pos += $qw * 16
            }
            0x51 { "      DIRECTHL qw={0}" -f $imm; $pos += $imm * 16 }
            0x20 { $pos += 4 }
            0x30 { $pos += 16 }
            0x31 { $pos += 16 }
            0x00 { }
            default { "      {0} imm=0x{1:x} num={2}" -f $name, $imm, $num }
        }
    }
}

$tag = [Convert]::ToUInt32($Tadr.Replace("0x", ""), 16)
$stack = New-Object System.Collections.Stack
for ($i = 0; $i -lt $MaxTags; $i++) {
    $lo = U64 $tag
    $qwc = [int]($lo -band 0xFFFF); $id = [int](($lo -shr 28) -band 7); $irq = ($lo -shr 31) -band 1
    $addr = [uint32](($lo -shr 32) -band 0x7FFFFFFF)
    "tag@0x{0:x} {1} qwc={2} addr=0x{3:x}{4}" -f $tag, $ids[$id], $qwc, $addr, $(if ($irq) { " IRQ" } else { "" })
    if ($Vif) { Decode-Vif ($tag + 8) 8 }
    $dataAddr = switch ($id) { 1 { $tag + 16 } 2 { $tag + 16 } 5 { $tag + 16 } 6 { $tag + 16 } 7 { $tag + 16 } default { $addr } }
    if ($Vif -and $qwc -gt 0) { Decode-Vif $dataAddr ($qwc * 16) }
    elseif ($Gif -and $qwc -gt 0) { Decode-Gif $dataAddr ($qwc * 16) }
    switch ($id) {
        0 { break }                                  # refe
        1 { $tag = $tag + 16 + $qwc * 16 }           # cnt
        2 { $tag = $addr }                           # next
        3 { $tag = $tag + 16 }                       # ref
        4 { $tag = $tag + 16 }                       # refs
        5 { $stack.Push($tag + 16 + $qwc * 16); $tag = $addr } # call
        6 { if ($stack.Count) { $tag = $stack.Pop() } else { $tag = 0 } } # ret
        7 { break }                                  # end
    }
    if ($id -eq 0 -or $id -eq 7 -or ($id -eq 6 -and $tag -eq 0)) { break }
}
"--- resumen VIFcodes"
$stats.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "{0,6} {1}" -f $_.Value, $_.Key }
