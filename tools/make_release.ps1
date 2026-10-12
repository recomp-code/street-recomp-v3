<#
  Genera el zip de la release para GitHub (lo que descarga un jugador):
    NBAStreetV3-PC-<version>.zip = Launcher + instalador + parches + configuracion + scripts
                                   + gshost-win64.zip (render de PCSX2 ya compilado, GPL)
  Un solo archivo: es lo unico que se sube a la release y lo unico que baja el jugador.
  NO incluye nada del juego: el juego se compila en el PC del jugador desde su propia ISO.
  Uso: tools\make_release.ps1 -Version 1.0 [-GsHostZip C:\NBAStreetRecomp\release\gshost-win64.zip]
#>
param([Parameter(Mandatory)][string]$Version, [string]$GsHostZip = "C:\NBAStreetRecomp\release_src\gshost-win64.zip",
      [string]$OutDir = "C:\NBAStreetRecomp\release", [switch]$SplitRenderer)
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$name = "NBAStreetV3-PC-$Version"
$stage = Join-Path $OutDir $name
if (Test-Path $stage) { cmd /c rmdir /s /q "$stage" }
New-Item -ItemType Directory -Force $stage | Out-Null

# Solo lo que esta en git (nunca archivos sueltos del juego que hubiera en la carpeta).
$files = git -C $Repo ls-files
if ($LASTEXITCODE) { throw "git ls-files fallo" }
foreach ($f in $files) {
    $dst = Join-Path $stage $f
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    Copy-Item (Join-Path $Repo $f) $dst
}

# Normal: un solo zip para el jugador, con el render precompilado dentro (gshost-win64.zip).
# -SplitRenderer: el render va como assets aparte partido en zips de < 10 MB (gshost-win64-N.zip)
# que el instalador descarga solo (URLs en gshost\release_url.txt), por si hay limite de subida.
Get-ChildItem $OutDir -Filter 'gshost-win64*.zip' -ErrorAction SilentlyContinue | ForEach-Object { cmd /c del /q "$($_.FullName)" }
if ((Test-Path $GsHostZip) -and -not $SplitRenderer) {
    Copy-Item $GsHostZip (Join-Path $stage 'gshost-win64.zip')
}
elseif (Test-Path $GsHostZip) {
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    $src = [IO.Compression.ZipFile]::OpenRead($GsHostZip)
    $limit = 9MB
    $bins = New-Object System.Collections.Generic.List[object]
    foreach ($e in ($src.Entries | Where-Object { $_.Name } | Sort-Object CompressedLength -Descending)) {
        $bin = $bins | Where-Object { $_.Size + $e.CompressedLength -le $limit } | Select-Object -First 1
        if (-not $bin) { $bin = [pscustomobject]@{ Size = 0; Entries = New-Object System.Collections.Generic.List[object] }; $bins.Add($bin) }
        $bin.Size += $e.CompressedLength; $bin.Entries.Add($e)
    }
    $urls = @()
    for ($i = 0; $i -lt $bins.Count; $i++) {
        $partName = "gshost-win64-$($i + 1).zip"
        $out = [IO.Compression.ZipFile]::Open((Join-Path $OutDir $partName), 'Create')
        foreach ($e in $bins[$i].Entries) {
            $dstEntry = $out.CreateEntry($e.FullName, [IO.Compression.CompressionLevel]::Optimal)
            $in = $e.Open(); $os = $dstEntry.Open(); $in.CopyTo($os); $os.Dispose(); $in.Dispose()
        }
        $out.Dispose()
        $urls += "https://github.com/recomp-code/street-recomp-v3/releases/download/v$Version/$partName"
    }
    $src.Dispose()
    Set-Content (Join-Path $stage 'gshost\release_url.txt') $urls -Encoding ascii
}
else { Write-Warning "Sin ${GsHostZip}: el instalador tendra que compilar PCSX2" }

$zip = Join-Path $OutDir "$name.zip"
if (Test-Path $zip) { cmd /c del /q "$zip" }
Compress-Archive "$stage\*" $zip
cmd /c rmdir /s /q "$stage"
Get-ChildItem $OutDir -Filter '*.zip' | Select-Object Name, @{ n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } }
