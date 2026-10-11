<#
  Corrige en el codigo ya generado (game\output) las traducciones de SQRT.S: en la R5900 el
  operando esta en el campo ft (bits 20..16), no en fs. Reescribe cada
  "ctx->f[fd] = FPU_SQRT_S(ctx->f[x]);" segun la instruccion del comentario anterior.
  Uso: fix_sqrt_s.ps1 [-WhatIf]
#>
param([switch]$WhatIf, [string]$Dir = "C:\NBAStreetRecomp\game\output")
$out = $Dir
$files = Select-String -Path "$out\*.cpp" -Pattern "FPU_SQRT_S\(" -List | ForEach-Object { $_.Path }
$changedFiles = 0; $changedLines = 0
foreach ($path in $files) {
    $lines = [IO.File]::ReadAllLines($path)
    $raw = $null; $dirty = $false
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^\s*// 0x[0-9a-fA-F]+: 0x([0-9a-fA-F]{1,8})\s') { $raw = [Convert]::ToUInt32($Matches[1], 16); continue }
        if ($lines[$i] -match '^(\s*)ctx->f\[(\d+)\] = FPU_SQRT_S\(ctx->f\[(\d+)\]\);\s*$' -and $null -ne $raw) {
            $ft = ($raw -shr 16) -band 31; $fd = ($raw -shr 6) -band 31
            $fixed = "{0}ctx->f[{1}] = FPU_SQRT_S(ctx->f[{2}]);" -f $Matches[1], $fd, $ft
            if ($fixed -ne $lines[$i]) { $lines[$i] = $fixed; $dirty = $true; $changedLines++ }
        }
    }
    if ($dirty) {
        $changedFiles++
        if (-not $WhatIf) { [IO.File]::WriteAllLines($path, $lines) }
    }
}
"archivos con SQRT.S: $($files.Count); corregidos: $changedFiles archivos, $changedLines lineas"

