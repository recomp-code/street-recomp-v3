<#
  Regenera los parches a partir de los cambios locales en C:\NBAStreetRecomp\PS2Recomp y
  C:\NBAStreetRecomp\pcsx2 (contra su commit fijado), incluidos los archivos nuevos sin seguimiento.
  No toca el indice real de git (usa una copia temporal).
  - pcsx2: patches\pcsx2.patch = todo el cambio local.
  - PS2Recomp: el arbol local lleva ps2recomp.patch + ps2recomp-web.patch (setup_sources.ps1 los
    aplica los dos). ps2recomp.patch no se toca; lo que difiere del arbol "commit fijado +
    ps2recomp.patch" va a ps2recomp-web.patch, la capa de encima que usan PC, Mac y navegador.
  Uso: powershell -ExecutionPolicy Bypass -File tools\make_patches.ps1 [-Root C:\NBAStreetRecomp]
#>
param([string]$Root = 'C:\NBAStreetRecomp')
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
foreach ($dir in "$Root\tools\mingit\cmd", "$Root\tools\portablegit\cmd") { if (Test-Path $dir) { $env:Path = "$dir;$env:Path" } }
$PS2RecompCommit = '2c5fbb9'

function MakePatch($src, $out, $exclude) {
    # git prints line-ending warnings on stderr; they must not stop the script.
    $ErrorActionPreference = 'Continue'
    $tmp = Join-Path $env:TEMP ("idx_" + [guid]::NewGuid().ToString('N'))
    Copy-Item "$src\.git\index" $tmp
    $env:GIT_INDEX_FILE = $tmp
    try {
        $untracked = git -C $src ls-files --others --exclude-standard
        if ($untracked) { $untracked | ForEach-Object { git -C $src add -N -- $_ } }
        $diffArgs = @('-C', $src, '-c', 'core.abbrev=9', 'diff', '--binary', 'HEAD', '--', '.') + ($exclude | ForEach-Object { ":(exclude)$_" })
        $patch = & git @diffArgs
        [IO.File]::WriteAllText($out, (($patch -join "`n") + "`n"), (New-Object Text.UTF8Encoding $false))
    }
    finally { Remove-Item Env:GIT_INDEX_FILE; Remove-Item $tmp -Force }
}

# PS2Recomp: the local changes on top of "pinned commit + ps2recomp.patch", built in a temporary
# worktree. register_functions.cpp is generated from the game's ELF: never in a patch.
function MakeTopPatch($src, $out) {
    $ErrorActionPreference = 'Continue'
    $full = Join-Path $env:TEMP ("full_" + [guid]::NewGuid().ToString('N') + '.patch')
    MakePatch $src $full @('ps2xRuntime/src/runner/register_functions.cpp')
    $wt = Join-Path $env:TEMP ("wt_" + [guid]::NewGuid().ToString('N'))
    git -C $src worktree add --detach $wt $PS2RecompCommit 2>&1 | Out-Null
    try {
        git -C $wt apply --whitespace=nowarn "$Repo\patches\ps2recomp.patch"
        if ($LASTEXITCODE) { throw 'ps2recomp.patch does not apply on the pinned commit' }
        git -C $wt add -A 2>&1 | Out-Null
        git -C $wt -c user.name=tmp -c user.email=tmp@tmp commit -q -m base 2>&1 | Out-Null
        $paths = Select-String -Path $full -Pattern '^diff --git a/(\S+) b/(\S+)' | ForEach-Object { $_.Matches[0].Groups[2].Value } | Sort-Object -Unique
        foreach ($p in $paths) {
            $from = Join-Path $src $p; $to = Join-Path $wt $p
            if (Test-Path $from) { New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null; Copy-Item $from $to -Force }
            elseif (Test-Path $to) { Remove-Item $to -Force }
        }
        # Files ps2recomp.patch changes that the local tree has back at the pinned version.
        $native = Select-String -Path "$Repo\patches\ps2recomp.patch" -Pattern '^diff --git a/(\S+) b/(\S+)' | ForEach-Object { $_.Matches[0].Groups[2].Value }
        foreach ($p in $native) { if ($paths -notcontains $p) { git -C $wt checkout $PS2RecompCommit -- $p 2>$null } }
        git -C $wt add -A 2>&1 | Out-Null
        $patch = git -C $wt -c core.abbrev=7 diff --binary --cached HEAD # same hash length as the original patch
        [IO.File]::WriteAllText($out, (($patch -join "`n") + "`n"), (New-Object Text.UTF8Encoding $false))
    }
    finally {
        git -C $src worktree remove --force $wt 2>&1 | Out-Null
        Remove-Item $full -Force -ErrorAction SilentlyContinue
    }
}

MakeTopPatch "$Root\PS2Recomp" "$Repo\patches\ps2recomp-web.patch"
MakePatch "$Root\pcsx2" "$Repo\patches\pcsx2.patch" @()
Get-ChildItem "$Repo\patches" | Select-Object Name, Length
