<#
  Lista las funciones que llaman a sceSifBindRpc (0x00542448) y el SID que piden,
  leyendo el desensamblado que ps2_recomp deja como comentarios en game\output.
#>
param([string]$OutDir = "C:\NBAStreetRecomp\game\output", [string]$Toml = "C:\NBAStreetRecomp\game\config\config.toml")
$stubbed = @{}
if ((Get-Content $Toml -Raw) -match '(?s)\nstubs\s*=\s*\[(.*?)\]') {
    $Matches[1] -split "," | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ -match '^(.+)@0x([0-9A-Fa-f]+)$' } |
        ForEach-Object { $null = $_ -match '^(.+)@0x([0-9A-Fa-f]+)$'; $stubbed[[Convert]::ToUInt32($Matches[2], 16)] = $Matches[1] }
}
$hits = Get-ChildItem $OutDir -Filter *.cpp | Select-String -Pattern "jal\s+func_542448" -List
foreach ($h in $hits) {
    $lines = Get-Content $h.Path | Where-Object { $_ -match '^\s*// 0x[0-9a-f]+: 0x[0-9a-f]+\s' }
    $sids = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'jal\s+func_542448') {
            $hi = $null; $lo = $null
            for ($k = [Math]::Max(0, $i - 6); $k -le [Math]::Min($lines.Count - 1, $i + 1); $k++) {
                if ($lines[$k] -match 'lui\s+\$a1, 0x([0-9A-F]+)') { $hi = [Convert]::ToUInt32($Matches[1], 16) }
                if ($lines[$k] -match 'ori\s+\$a1, \$a1, 0x([0-9A-F]+)') { $lo = [Convert]::ToUInt32($Matches[1], 16) }
            }
            if ($null -ne $hi) { $sids += ("0x{0:X8}" -f (($hi -shl 16) -bor [uint32]$lo)) } else { $sids += "?" }
        }
    }
    if ($h.Filename -match '^(?:FUN|entry)_0*([0-9a-f]+)_') { $start = [Convert]::ToUInt32($Matches[1], 16) } else { $start = 0 }
    [pscustomobject]@{ Funcion = $h.Filename -replace '\.cpp$', ''; SIDs = ($sids | Sort-Object -Unique) -join ","; Stub = $stubbed[$start] }
}
