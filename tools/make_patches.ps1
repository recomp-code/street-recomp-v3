<#
  Regenera patches\ps2recomp.patch y patches\pcsx2.patch a partir de los cambios locales en
  C:\NBAStreetRecomp\PS2Recomp y C:\NBAStreetRecomp\pcsx2 (contra su commit fijado), incluidos los
  archivos nuevos sin seguimiento. No toca el indice real de git (usa una copia temporal).
  Uso: powershell -ExecutionPolicy Bypass -File tools\make_patches.ps1 [-Root C:\NBAStreetRecomp]
#>
param([string]$Root = 'C:\NBAStreetRecomp')
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
foreach ($dir in "$Root\tools\mingit\cmd", "$Root\tools\portablegit\cmd") { if (Test-Path $dir) { $env:Path = "$dir;$env:Path" } }

function MakePatch($src, $out, $exclude) {
    # git prints line-ending warnings on stderr; they must not stop the script.
    $ErrorActionPreference = 'Continue'
    $tmp = Join-Path $env:TEMP ("idx_" + [guid]::NewGuid().ToString('N'))
    Copy-Item "$src\.git\index" $tmp
    $env:GIT_INDEX_FILE = $tmp
    try {
        $untracked = git -C $src ls-files --others --exclude-standard
        if ($untracked) { $untracked | ForEach-Object { git -C $src add -N -- $_ } }
        $diffArgs = @('-C', $src, 'diff', '--binary', 'HEAD', '--', '.') + ($exclude | ForEach-Object { ":(exclude)$_" })
        $patch = & git @diffArgs
        [IO.File]::WriteAllText($out, (($patch -join "`n") + "`n"), (New-Object Text.UTF8Encoding $false))
    }
    finally { Remove-Item Env:GIT_INDEX_FILE; Remove-Item $tmp -Force }
}

# register_functions.cpp lo genera el recompilador a partir del ELF del juego: nunca va en el parche.
MakePatch "$Root\PS2Recomp" "$Repo\patches\ps2recomp.patch" @('ps2xRuntime/src/runner/register_functions.cpp')
MakePatch "$Root\pcsx2" "$Repo\patches\pcsx2.patch" @()
Get-ChildItem "$Repo\patches" | Select-Object Name, Length
