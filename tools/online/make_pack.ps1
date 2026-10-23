# NBA Street V3's Windows pack for the Recomp launcher (the online lockstep build): the runtime and the shared GS host,
# ready to play -- never the game. The player's ISO stays the player's: the launcher checks its ELF and copies it out;
# the IOP modules and the game's archives are read from the ISO.
#   .\make_pack.ps1 -Version 2.0 [-Out <dir>] [-HostDir <folder with pcsx2-gsrunner.exe>] [-Presets <folder>]
# Writes <Out>\NBAStreetV3_Windows_Recomp.zip and <Out>\recomp-game.json (the manifest the launcher reads).
param(
    [Parameter(Mandatory)][string]$Version,
    [string]$Out = 'C:\NBAOnline\dist',
    [string]$HostDir = 'C:\RecompTest\br4host\gshost', # the shared GS host (live ring v2), clean (never played from)
    [string]$Presets = 'C:\NBAOnline\presets',
    [string]$LauncherMin = '3.2',
    [string]$Root = 'C:\NBAOnline'
)
$ErrorActionPreference = 'Stop'
$rt = "$Root\PS2Recomp\out\build\ps2xRuntime\Release"
$stage = "$Out\pack_stage"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force "$stage\runtime", "$stage\gshost\presets", "$stage\DLSS" | Out-Null

# runtime: the runner and the DLLs next to it (not the build's .lib / .map / .pdb), plus the MSVC runtime
Copy-Item "$rt\ps2EntryRunner.exe" "$stage\runtime"
Get-ChildItem $rt -Filter *.dll | Copy-Item -Destination "$stage\runtime"
foreach ($crt in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
    if (Test-Path "$HostDir\$crt") { Copy-Item "$HostDir\$crt" "$stage\runtime" }
}

# GS host: the exe, its DLLs and resources; NBA's presets (the launcher copies them into gshost\ on first use)
Copy-Item "$HostDir\pcsx2-gsrunner.exe" "$stage\gshost"
Get-ChildItem $HostDir -Filter *.dll | Copy-Item -Destination "$stage\gshost"
Copy-Item -Recurse "$HostDir\resources" "$stage\gshost\resources"
New-Item -ItemType File "$stage\gshost\portable.ini" | Out-Null
foreach ($ini in 'nba.ini', 'nba_4x3.ini', 'nba_dlss.ini', 'nba_dlss_4x3.ini') { Copy-Item "$Presets\$ini" "$stage\gshost\presets" }
if (Test-Path "$HostDir\presets\nvngx_dlss.dll") { Copy-Item "$HostDir\presets\nvngx_dlss.dll" "$stage\gshost\presets" }
[IO.File]::WriteAllText("$stage\DLSS\LEEME.txt", "Pon aqui una nvngx_dlss.dll mas nueva (o arrastrala a la ventana de Recomp) y se usara desde la proxima partida.`r`n", [Text.Encoding]::ASCII)

# nothing of the game may be in the pack
$bad = Get-ChildItem $stage -Recurse -File | Where-Object { $_.Extension -in '.iso', '.elf', '.gs', '.map', '.lib', '.pdb', '.viv', '.irx' -or $_.Name -like 'SLUS_*' -or $_.FullName -match '\\textures\\' }
if ($bad) { throw "the pack must not contain: $($bad.FullName -join ', ')" }

$zipName = 'NBAStreetV3_Windows_Recomp.zip'
$zip = "$Out\$zipName"
if (Test-Path $zip) { Remove-Item $zip }
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
# entries written one by one with "/" (Windows PowerShell's CreateFromDirectory writes "\")
$zs = [IO.File]::Open($zip, [IO.FileMode]::CreateNew)
$za = New-Object IO.Compression.ZipArchive($zs, [IO.Compression.ZipArchiveMode]::Create)
foreach ($f in Get-ChildItem $stage -Recurse -File) {
    $name = $f.FullName.Substring($stage.Length + 1).Replace('\', '/')
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($za, $f.FullName, $name, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
}
$za.Dispose(); $zs.Dispose()
Remove-Item -Recurse -Force $stage
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
$size = (Get-Item $zip).Length
$manifest = [ordered]@{ id = 'nbastreetv3'; version = $Version; launcherMin = $LauncherMin
    packs = [ordered]@{ Windows = [ordered]@{ file = $zipName; sha256 = $hash; size = $size } } }
[IO.File]::WriteAllText("$Out\recomp-game.json", ($manifest | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
"$zipName {0:N1} MB sha256 {1}" -f ($size / 1MB), $hash
