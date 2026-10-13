<#
  Descarga PS2Recomp y PCSX2 en las versiones exactas sobre las que se hizo el port y les aplica
  los parches de este repositorio (patches\ps2recomp.patch, patches\pcsx2.patch).
  Uso (desde C:\NBAStreetRecomp, con git en el PATH):
      powershell -ExecutionPolicy Bypass -File nbastreet-v3-recomp\tools\setup_sources.ps1
#>
param([string]$Root = "C:\NBAStreetRecomp")
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force (Join-Path $Root 'logs'), (Join-Path $Root 'game\iso') | Out-Null

$sources = @(
    @{ Name = 'PS2Recomp'; Url = 'https://github.com/ran-j/PS2Recomp.git'; Commit = '2c5fbb9'; Patch = 'ps2recomp.patch' },
    @{ Name = 'pcsx2';     Url = 'https://github.com/PCSX2/pcsx2.git';     Commit = 'd073d75'; Patch = 'pcsx2.patch' }
)

# git prints to stderr even when it works (progress) and `apply --check` reports a mismatch there.
# With $ErrorActionPreference = 'Stop', Windows PowerShell 5.1 turns redirected stderr into a
# terminating error, so the checks run with 'Continue' and are judged by their exit code.
function Test-Git([string[]]$arguments) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & git @arguments 2>&1 | Out-Null; return $LASTEXITCODE -eq 0 } finally { $ErrorActionPreference = $saved }
}

foreach ($s in $sources) {
    $dir = Join-Path $Root $s.Name
    if (-not (Test-Path $dir)) {
        Write-Host "Clonando $($s.Name)..."
        git clone $s.Url $dir
        if ($LASTEXITCODE) { throw "git clone $($s.Name) fallo" }
    }
    Write-Host "Version fija $($s.Commit) de $($s.Name)"
    git -C $dir checkout --quiet $s.Commit
    if ($LASTEXITCODE) { throw "git checkout $($s.Commit) fallo en $($s.Name)" }

    $patch = Join-Path $Repo "patches\$($s.Patch)"
    if (-not (Test-Git @('-C', $dir, 'apply', '--check', '--whitespace=nowarn', $patch))) {
        # Ya aplicado (se vuelve a ejecutar el script)?
        if (-not (Test-Git @('-C', $dir, 'apply', '--check', '--reverse', '--whitespace=nowarn', $patch))) {
            throw "El parche $($s.Patch) no aplica sobre $($s.Name) $($s.Commit)"
        }
        Write-Host "  $($s.Patch) ya estaba aplicado"
        continue
    }
    git -C $dir apply --whitespace=nowarn $patch
    if ($LASTEXITCODE) { throw "No se pudo aplicar $($s.Patch)" }
    Write-Host "  $($s.Patch) aplicado"
}
Write-Host "Fuentes listas en $Root"
