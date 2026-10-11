<#
  NBA Street V3: salta la autenticación DNAS (servidores de Sony cerrados).
  FUN_00349820 arma la configuración de red con DNASSKIP=0 (0x349968: daddu $a3,$zero,$zero en el
  delay slot de la llamada a 0x4E2270 con "DNASSKIP"); el estado 4 de 0x4F87C8 se salta el DNAS
  si vale 1. Este script cambia ese 0 por 1 en el código generado.
  Uso: fix_dnas_skip.ps1 -Dir <carpeta con los .cpp generados>
#>
param([Parameter(Mandatory)][string]$Dir)
$old = 'SET_GPR_U64(ctx, 7, (uint64_t)GPR_U64(ctx, 0) + (uint64_t)GPR_U64(ctx, 0));'
$new = 'SET_GPR_U64(ctx, 7, 1u); // ps2recomp: DNASSKIP=1 (was daddu $a3,$zero,$zero)'
$total = 0
foreach ($f in Get-ChildItem $Dir -Filter *.cpp | Where-Object { Select-String -Path $_.FullName -Pattern '0x349968: 0x382d' -Quiet }) {
    $lines = [IO.File]::ReadAllLines($f.FullName)
    $changed = 0
    for ($i = 0; $i -lt $lines.Length - 1; $i++) {
        if ($lines[$i] -match '0x349968: 0x382d' -and $lines[$i + 1].Trim() -eq $old) {
            $lines[$i + 1] = $lines[$i + 1].Replace($old, $new); $changed++
        }
    }
    if ($changed) { [IO.File]::WriteAllLines($f.FullName, $lines); "$($f.Name): $changed"; $total += $changed }
}
"total: $total"
