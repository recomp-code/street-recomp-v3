# Convierte volcados PPM (P6) a PNG: ppm2png.ps1 -Files a.ppm,b.ppm
param([string[]]$Files)
Add-Type -AssemblyName System.Drawing
foreach ($f in $Files) {
    $bytes = [IO.File]::ReadAllBytes($f)
    $pos = 0; $tokens = @()
    while ($tokens.Count -lt 4) {
        while ([char]$bytes[$pos] -match '\s') { $pos++ }
        if ([char]$bytes[$pos] -eq '#') { while ($bytes[$pos] -ne 10) { $pos++ }; continue }
        $start = $pos
        while (-not ([char]$bytes[$pos] -match '\s')) { $pos++ }
        $tokens += [Text.Encoding]::ASCII.GetString($bytes, $start, $pos - $start)
    }
    $pos++
    $w = [int]$tokens[1]; $h = [int]$tokens[2]
    $bmp = New-Object Drawing.Bitmap $w, $h, ([Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $rect = New-Object Drawing.Rectangle 0, 0, $w, $h
    $data = $bmp.LockBits($rect, [Drawing.Imaging.ImageLockMode]::WriteOnly, $bmp.PixelFormat)
    $row = New-Object byte[] ($data.Stride)
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            $s = $pos + ($y * $w + $x) * 3
            $row[$x * 3] = $bytes[$s + 2]; $row[$x * 3 + 1] = $bytes[$s + 1]; $row[$x * 3 + 2] = $bytes[$s]
        }
        [Runtime.InteropServices.Marshal]::Copy($row, 0, [IntPtr]($data.Scan0.ToInt64() + $y * $data.Stride), $data.Stride)
    }
    $bmp.UnlockBits($data)
    $out = [IO.Path]::ChangeExtension($f, ".png")
    $bmp.Save($out, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    "$out ${w}x${h}"
}
