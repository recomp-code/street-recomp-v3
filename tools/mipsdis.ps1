<#
  Minimal MIPS R3000/R5900 disassembler for quick looks at RAM dumps (IOP or EE).
  Uso: mipsdis.ps1 -File logs\iop_match.bin -Start 0x52F00 -End 0x53100 [-Base 0]
#>
param([string]$File, [string]$Start, [string]$End, [string]$Base = '0')
$b = [IO.File]::ReadAllBytes($File)
$s = [Convert]::ToUInt32($Start, 16); $e = [Convert]::ToUInt32($End, 16); $base = [Convert]::ToUInt32($Base, 16)
$R = 'zero','at','v0','v1','a0','a1','a2','a3','t0','t1','t2','t3','t4','t5','t6','t7','s0','s1','s2','s3','s4','s5','s6','s7','t8','t9','k0','k1','gp','sp','fp','ra'
function sx16($v) { if ($v -band 0x8000) { $v - 0x10000 } else { $v } }
for ($a = $s; $a -lt $e; $a += 4) {
    $w = [BitConverter]::ToUInt32($b, [int]($a - $base))
    $op = $w -shr 26; $rs = ($w -shr 21) -band 31; $rt = ($w -shr 16) -band 31; $rd = ($w -shr 11) -band 31
    $sh = ($w -shr 6) -band 31; $fn = $w -band 63; $imm = $w -band 0xFFFF; $si = sx16 $imm
    $t = switch ($op) {
        0 { switch ($fn) {
                0 { if ($w -eq 0) { 'nop' } else { "sll $($R[$rd]), $($R[$rt]), $sh" } }
                2 { "srl $($R[$rd]), $($R[$rt]), $sh" } 3 { "sra $($R[$rd]), $($R[$rt]), $sh" }
                4 { "sllv $($R[$rd]), $($R[$rt]), $($R[$rs])" } 6 { "srlv $($R[$rd]), $($R[$rt]), $($R[$rs])" } 7 { "srav $($R[$rd]), $($R[$rt]), $($R[$rs])" }
                8 { "jr $($R[$rs])" } 9 { "jalr $($R[$rd]), $($R[$rs])" } 12 { 'syscall' } 13 { 'break' }
                16 { "mfhi $($R[$rd])" } 18 { "mflo $($R[$rd])" } 24 { "mult $($R[$rs]), $($R[$rt])" } 25 { "multu $($R[$rs]), $($R[$rt])" }
                26 { "div $($R[$rs]), $($R[$rt])" } 27 { "divu $($R[$rs]), $($R[$rt])" }
                32 { "add $($R[$rd]), $($R[$rs]), $($R[$rt])" } 33 { if ($rt -eq 0) { "move $($R[$rd]), $($R[$rs])" } else { "addu $($R[$rd]), $($R[$rs]), $($R[$rt])" } }
                34 { "sub $($R[$rd]), $($R[$rs]), $($R[$rt])" } 35 { "subu $($R[$rd]), $($R[$rs]), $($R[$rt])" }
                36 { "and $($R[$rd]), $($R[$rs]), $($R[$rt])" } 37 { "or $($R[$rd]), $($R[$rs]), $($R[$rt])" } 38 { "xor $($R[$rd]), $($R[$rs]), $($R[$rt])" } 39 { "nor $($R[$rd]), $($R[$rs]), $($R[$rt])" }
                42 { "slt $($R[$rd]), $($R[$rs]), $($R[$rt])" } 43 { "sltu $($R[$rd]), $($R[$rs]), $($R[$rt])" }
                default { 'special fn={0}' -f $fn } } }
        1 { $c = @{0='bltz';1='bgez';16='bltzal';17='bgezal'}[$rt]; "{0} {1}, 0x{2:X}" -f $c, $R[$rs], ([uint32](([int64]$a + 4 + 4 * $si) -band 0xFFFFFFFF)) }
        2 { 'j 0x{0:X}' -f ((($a + 4) -band 0xF0000000) -bor (($w -band 0x3FFFFFF) * 4)) }
        3 { 'jal 0x{0:X}' -f ((($a + 4) -band 0xF0000000) -bor (($w -band 0x3FFFFFF) * 4)) }
        4 { 'beq {0}, {1}, 0x{2:X}' -f $R[$rs], $R[$rt], ([uint32](([int64]$a + 4 + 4 * $si) -band 0xFFFFFFFF)) } 5 { 'bne {0}, {1}, 0x{2:X}' -f $R[$rs], $R[$rt], ([uint32](([int64]$a + 4 + 4 * $si) -band 0xFFFFFFFF)) }
        6 { 'blez {0}, 0x{1:X}' -f $R[$rs], ([uint32](([int64]$a + 4 + 4 * $si) -band 0xFFFFFFFF)) } 7 { 'bgtz {0}, 0x{1:X}' -f $R[$rs], ([uint32](([int64]$a + 4 + 4 * $si) -band 0xFFFFFFFF)) }
        8 { "addi $($R[$rt]), $($R[$rs]), $si" } 9 { "addiu $($R[$rt]), $($R[$rs]), $si" }
        10 { "slti $($R[$rt]), $($R[$rs]), $si" } 11 { "sltiu $($R[$rt]), $($R[$rs]), $si" }
        12 { 'andi {0}, {1}, 0x{2:X}' -f $R[$rt], $R[$rs], $imm } 13 { 'ori {0}, {1}, 0x{2:X}' -f $R[$rt], $R[$rs], $imm }
        14 { 'xori {0}, {1}, 0x{2:X}' -f $R[$rt], $R[$rs], $imm } 15 { 'lui {0}, 0x{1:X}' -f $R[$rt], $imm }
        16 { if ($rs -eq 0) { "mfc0 $($R[$rt]), `$$rd" } elseif ($rs -eq 4) { "mtc0 $($R[$rt]), `$$rd" } else { 'cop0' } }
        32 { "lb $($R[$rt]), $si($($R[$rs]))" } 33 { "lh $($R[$rt]), $si($($R[$rs]))" } 35 { "lw $($R[$rt]), $si($($R[$rs]))" }
        36 { "lbu $($R[$rt]), $si($($R[$rs]))" } 37 { "lhu $($R[$rt]), $si($($R[$rs]))" }
        40 { "sb $($R[$rt]), $si($($R[$rs]))" } 41 { "sh $($R[$rt]), $si($($R[$rs]))" } 43 { "sw $($R[$rt]), $si($($R[$rs]))" }
        default { 'op{0} 0x{1:X8}' -f $op, $w }
    }
    '{0:X6}: {1:X8}  {2}' -f $a, $w, $t
}
