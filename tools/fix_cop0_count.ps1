<#
  Hace que las lecturas de COP0 Count (mfc0 $9) del codigo ya generado actualicen el reloj justo
  antes de leerlo, para no tener que actualizarlo en cada despacho de funcion.
  Uso: fix_cop0_count.ps1 [-Dir <carpeta con los .cpp generados>]
#>
param([string]$Dir = "C:\NBAStreetRecomp\PS2Recomp\ps2xRuntime\src\runner")
$pattern = '^(\s*)SET_GPR_S32\(ctx, (\d+), \(int32_t\)ctx->cop0_count\);\s*$'
$files = Select-String -Path "$Dir\*.cpp" -Pattern "\(int32_t\)ctx->cop0_count\);" -List | ForEach-Object { $_.Path }
$lines = 0
foreach ($path in $files) {
    $text = [IO.File]::ReadAllLines($path); $dirty = $false
    for ($i = 0; $i -lt $text.Length; $i++) {
        if ($text[$i] -match $pattern) {
            $text[$i] = "{0}{{ extern void ps2UpdateCop0Count(R5900Context *); ps2UpdateCop0Count(ctx); SET_GPR_S32(ctx, {1}, (int32_t)ctx->cop0_count); }}" -f $Matches[1], $Matches[2]
            $dirty = $true; $lines++
        }
    }
    if ($dirty) { [IO.File]::WriteAllLines($path, $text) }
}
"archivos: $($files.Count), lecturas parcheadas: $lines"
