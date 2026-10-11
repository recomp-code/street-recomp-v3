# Parchea el codigo ya generado: BLEZ/BGTZ/BLTZ/BGEZ (y variantes likely/and-link) deben comparar el
# registro de 64 bits, como el R5900, no solo la palabra baja. El generador ya esta corregido
# (control_flow_emitter.cpp); esto evita regenerar todo el juego.
# Sintoma que lo destapo: el qsort de la tabla de archivos del disco dejaba /XF/PLAYER2X.BH fuera de
# orden (su comparador hace DSUBU de dos hashes sin signo), el indice no cargaba y Create Baller se colgaba.
# Uso: fix_branch64.ps1 [-Dirs <carpetas>]
param([string[]]$Dirs = @("C:\NBAStreetRecomp\PS2Recomp\ps2xRuntime\src\runner", "C:\NBAStreetRecomp\game\output"))
$pattern = [regex]'(branch_taken_0x[0-9a-fA-F]+ = \()GPR_S32(\(ctx, \d+\) (?:<|>=|<=|>) 0\);)'
$utf8 = New-Object Text.UTF8Encoding $false
foreach ($dir in $Dirs) {
    if (-not (Test-Path $dir)) { continue }
    $files = 0; $branches = 0
    foreach ($file in [IO.Directory]::EnumerateFiles($dir, '*.cpp')) {
        $text = [IO.File]::ReadAllText($file)
        if ($text.IndexOf('GPR_S32(ctx, ') -lt 0) { continue }
        $count = $pattern.Matches($text).Count
        if ($count -eq 0) { continue }
        [IO.File]::WriteAllText($file, $pattern.Replace($text, '${1}GPR_S64${2}'), $utf8)
        $files++; $branches += $count
    }
    "{0}: {1} ramas en {2} archivos" -f $dir, $branches, $files
}
