# Prueba automatica: deja en la carpeta de reemplazos solo los PNG de -Files (hardlinks), arranca el
# juego hasta el menu principal y devuelve el grano medido (panel;foto). Restaura siempre la carpeta.
param([string[]]$Files)
$base = "$env:USERPROFILE\Documents\PCSX2\textures\SLUS-21126"
$rep = "$base\replacements"; $all = "$base\replacements_all"
if (Test-Path $all) { throw "ya existe $all (restaurar a mano)" }
Move-Item $rep $all
New-Item -ItemType Directory $rep | Out-Null
try {
    foreach ($f in $Files) { New-Item -ItemType HardLink -Path (Join-Path $rep $f) -Target (Join-Path $all $f) | Out-Null }
    & C:\NBAStreetRecomp\tools\run_scripted.ps1 -Seconds 106 -Pad "97:START" -Shots 104 | Out-Null
    & C:\NBAStreetRecomp\tools\shot_noise.ps1 C:\NBAStreetRecomp\logs\shots\shot_1.png
} finally {
    $trash = "$base\replacements_trash_" + [DateTime]::Now.ToString('HHmmssfff')
    Move-Item $rep $trash
    Move-Item $all $rep
}
