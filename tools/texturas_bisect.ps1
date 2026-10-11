# Busca por biseccion las texturas de reemplazo que meten grano en el menu principal.
# Cada prueba deja solo un subconjunto instalado (texturas_probar_subset.ps1). Resultado en -Log.
param([string]$Log = "C:\NBAStreetRecomp\logs\tex_bisect.log", [string[]]$Exclude = @('*-00002613.png'),
      [double]$PanelLimit = 6, [double]$PhotoLimit = 20, [double]$IconLimit = 2, [double]$BallLimit = 8)
$rep = "$env:USERPROFILE\Documents\PCSX2\textures\SLUS-21126\replacements"
$names = Get-ChildItem $rep -Filter *.png | % Name | ? { $n = $_; -not ($Exclude | ? { $n -like $_ }) } | Sort-Object
"inicio: $($names.Count) candidatas" | Tee-Object -FilePath $Log
$queue = New-Object System.Collections.Queue
$queue.Enqueue([string[]]$names)
$culprits = @()
while ($queue.Count -gt 0) {
    $set = [string[]]$queue.Dequeue()
    $r = (& C:\NBAStreetRecomp\tools\texturas_probar_subset.ps1 -Files $set).Split(';')
    $noisy = ([double]$r[0] -gt $PanelLimit) -or ([double]$r[1] -gt $PhotoLimit) -or ([double]$r[2] -gt $IconLimit) -or ([double]$r[3] -gt $BallLimit)
    "{0} texturas (primera {1}) -> panel {2} foto {3} iconos {4} pelota {5} {6}" -f $set.Count, $set[0], $r[0], $r[1], $r[2], $r[3], $(if ($noisy) { 'GRANO' } else { 'ok' }) | Tee-Object -FilePath $Log -Append
    if (-not $noisy) { continue }
    if ($set.Count -eq 1) { $culprits += $set[0]; "CULPABLE: $($set[0])" | Tee-Object -FilePath $Log -Append; continue }
    $half = [math]::Floor($set.Count / 2)
    $queue.Enqueue([string[]]$set[0..($half - 1)])
    $queue.Enqueue([string[]]$set[$half..($set.Count - 1)])
}
"FIN. culpables: $($culprits.Count)" | Tee-Object -FilePath $Log -Append
$culprits | Set-Content "C:\NBAStreetRecomp\logs\tex_culprits.txt"
