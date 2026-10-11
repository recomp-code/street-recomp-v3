<#
  Instala las texturas mejoradas: copia los PNG de C:\NBAStreetRecomp\texturas_hd\hd a la carpeta
  de reemplazos que lee el juego (la misma que usa PCSX2):
  Documents\PCSX2\textures\SLUS-21126\replacements
  Los archivos deben conservar EXACTAMENTE el nombre del original (es el hash de la textura).
  Despues activa en el juego: F1 / Back+Start -> Texturas HD -> Activadas.
  Uso: texturas_instalar.ps1
#>
$hd = "C:\NBAStreetRecomp\texturas_hd\hd"
$orig = "C:\NBAStreetRecomp\texturas_hd\originales"
$dst = "$env:USERPROFILE\Documents\PCSX2\textures\SLUS-21126\replacements"
New-Item -ItemType Directory -Force $dst | Out-Null
$n = 0; $unknown = 0
$discard = "C:\NBAStreetRecomp\texturas_hd\descartadas"
foreach ($f in Get-ChildItem $hd -Filter *.png -ErrorAction SilentlyContinue) {
    # Capturas dinamicas / texturas que rompen la imagen (ver texturas_preparar.ps1): nunca se instalan.
    if (Test-Path (Join-Path $discard $f.Name)) {
        Remove-Item (Join-Path $dst $f.Name) -ErrorAction SilentlyContinue
        "omitida (descartada): $($f.Name)"; continue
    }
    if (-not (Test-Path (Join-Path $orig $f.Name))) { $unknown++; "aviso: $($f.Name) no coincide con ninguna original (cambiaste el nombre?)" }
    Copy-Item $f.FullName (Join-Path $dst $f.Name) -Force
    $n++
}
"instaladas: $n  (sin original conocida: $unknown)"
"carpeta del juego: $dst"
