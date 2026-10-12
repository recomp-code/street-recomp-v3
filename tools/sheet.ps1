# Hoja de miniaturas de una carpeta de PNG (orden natural por numero). Uso: sheet.ps1 -Dir <dir> [-Out <png>] [-Cols 4]
param([Parameter(Mandatory)][string]$Dir, [string]$Out = '', [int]$Cols = 4, [int]$W = 320)
Add-Type -AssemblyName System.Drawing
if (-not $Out) { $Out = Join-Path $Dir 'sheet.png' }
$files = Get-ChildItem $Dir -Filter '*.png' | Where-Object { $_.Name -ne 'sheet.png' } | Sort-Object { [long]($_.BaseName -replace '\D', '') }
$H = [int]($W * 9 / 16); $rows = [math]::Ceiling($files.Count / $Cols)
$sheet = New-Object Drawing.Bitmap ($Cols * $W), ($rows * $H); $g = [Drawing.Graphics]::FromImage($sheet)
$font = New-Object Drawing.Font 'Arial', 12, ([Drawing.FontStyle]::Bold)
$i = 0
foreach ($f in $files) {
    $img = [Drawing.Image]::FromFile($f.FullName)
    $x = ($i % $Cols) * $W; $y = [math]::Floor($i / $Cols) * $H
    $g.DrawImage($img, $x, $y, $W, $H); $img.Dispose()
    $g.DrawString($f.BaseName, $font, [Drawing.Brushes]::Yellow, $x + 4, $y + 4); $i++
}
$g.Dispose(); $sheet.Save($Out); $sheet.Dispose(); $Out
