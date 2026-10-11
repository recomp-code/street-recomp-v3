<#
  Junta logs\keys_1..N.png en una hoja de miniaturas numeradas (logs\sheet.png).
  Uso: shot_sheet.ps1 [-Count 8] [-First 1]
#>
param([int]$Count = 8, [int]$First = 1)
Add-Type -AssemblyName System.Drawing
$cols = 2; $w = 480; $h = 272
$rows = [math]::Ceiling($Count / $cols)
$sheet = New-Object Drawing.Bitmap ($cols * $w), ($rows * $h)
$g = [Drawing.Graphics]::FromImage($sheet)
$font = New-Object Drawing.Font 'Arial', 20
for ($i = 0; $i -lt $Count; $i++) {
    $n = $First + $i
    $f = "C:\NBAStreetRecomp\logs\keys_$n.png"
    if (-not (Test-Path $f)) { continue }
    $img = [Drawing.Bitmap]::FromFile($f)
    $x = ($i % $cols) * $w; $y = [math]::Floor($i / $cols) * $h
    $g.DrawImage($img, $x, $y, $w, $h)
    $g.DrawString("$n", $font, [Drawing.Brushes]::Yellow, $x + 5, $y + 30)
    $img.Dispose()
}
$sheet.Save("C:\NBAStreetRecomp\logs\sheet.png")
$g.Dispose(); $sheet.Dispose()
"C:\NBAStreetRecomp\logs\sheet.png"
