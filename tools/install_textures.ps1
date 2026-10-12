<#
  Installs an HD texture pack (PCSX2 format: PNG/DDS files named after the original texture's hash)
  for NBA Street V3 from a .zip file or a folder. Used by the launcher's "Add HD texture pack" button.
   - copies every texture into Documents\PCSX2\textures\SLUS-21126\replacements, where the
     renderer loads them from (sub-folders of the pack do not matter),
   - skips the textures listed in gshost\texture_blocklist.txt (replacing those breaks the image),
   - turns "HD textures" on in gshost\nba_street.ini.
  Manual use: powershell -ExecutionPolicy Bypass -File tools\install_textures.ps1 -Source <pack.zip | folder>
  Prints one summary line: "installed=N skipped=M".
#>
param([Parameter(Mandatory)][string]$Source, [string]$Root = 'C:\NBAStreetRecomp')
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$dst = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PCSX2\textures\SLUS-21126\replacements'
New-Item -ItemType Directory -Force $dst | Out-Null

$blocked = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$listFile = Join-Path $Repo 'gshost\texture_blocklist.txt'
if (Test-Path $listFile) {
    foreach ($line in [IO.File]::ReadLines($listFile)) { if ($line -and -not $line.StartsWith('#')) { [void]$blocked.Add($line.Trim()) } }
}

$temp = $null
try {
    $folder = $Source
    if ((Test-Path $Source -PathType Leaf) -and $Source -match '\.zip$') {
        $temp = Join-Path $env:TEMP ('nbas3_pack_' + [guid]::NewGuid().ToString('N'))
        Expand-Archive $Source $temp -Force
        $folder = $temp
    }
    if (-not (Test-Path $folder -PathType Container)) { throw "Not a folder or .zip file: $Source" }
    $installed = 0; $skipped = 0
    foreach ($file in Get-ChildItem $folder -Recurse -File | Where-Object { $_.Extension -in '.png', '.dds' }) {
        if ($blocked.Contains($file.BaseName)) { $skipped++; continue }
        Copy-Item $file.FullName (Join-Path $dst $file.Name) -Force
        $installed++
    }
}
finally {
    if ($temp -and (Test-Path $temp)) { cmd /c rmdir /s /q "$temp" }
}

# Turn HD textures on (the launcher reads the same setting back).
$ini = Join-Path $Root 'gshost\nba_street.ini'
if (Test-Path $ini) {
    $lines = [System.Collections.Generic.List[string]](Get-Content $ini)
    $found = $false
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s*LoadTextureReplacements\s*=') { $lines[$i] = 'LoadTextureReplacements = true'; $found = $true } }
    if (-not $found) { $lines.Add('LoadTextureReplacements = true') }
    Set-Content $ini $lines -Encoding ascii
}
"installed=$installed skipped=$skipped"
