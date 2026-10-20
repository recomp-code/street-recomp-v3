<#
  NBA Street V3 PC launcher: pick your ISO, prepare the game once, add HD textures, play.
  Opened by Launcher.cmd. Preparing (compiling the game on your PC) only happens once.
#>
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$Root = 'C:\NBAStreetRecomp'
$Repo = $PSScriptRoot
$GameExe = "$Root\PS2Recomp\out\build\ps2xRuntime\Release\ps2EntryRunner.exe"
$GsHost = "$Root\gshost"
$Ini = "$GsHost\nba_street.ini"
$SettingsFile = Join-Path $env:APPDATA 'NBAStreetV3Launcher.json'
$TextureDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PCSX2\textures\SLUS-21126\replacements'

# ---------------------------------------------------------------- launcher settings
# Community online server (fixed; NBA_SERVER in the environment overrides it for testing).
$Server = if ($env:NBA_SERVER) { $env:NBA_SERVER } else { 'nbas3.xellrecomp.party' }
$settings = @{ Iso = ''; Fullscreen = $true; SmoothMotion = $false }
try {
    if (Test-Path $SettingsFile) {
        $loaded = Get-Content $SettingsFile -Raw | ConvertFrom-Json
        if ($loaded.Iso) { $settings.Iso = $loaded.Iso }
        if ($null -ne $loaded.Fullscreen) { $settings.Fullscreen = [bool]$loaded.Fullscreen }
        if ($null -ne $loaded.SmoothMotion) { $settings.SmoothMotion = [bool]$loaded.SmoothMotion }
    }
} catch {}
function Save-Settings { try { $settings | ConvertTo-Json | Set-Content $SettingsFile } catch {} }

# ---------------------------------------------------------------- nba_street.ini (graphics options)
function Read-Ini {
    $values = @{}
    if (Test-Path $Ini) {
        foreach ($line in Get-Content $Ini) {
            if ($line -match '^\s*([A-Za-z_]+)\s*=\s*(.*?)\s*$') { $values[$Matches[1]] = $Matches[2] }
        }
    }
    $values
}
function Write-IniValue($key, $value) {
    if (-not (Test-Path $Ini)) {
        New-Item -ItemType Directory -Force $GsHost | Out-Null
        Copy-Item "$Repo\gshost\nba_street.ini" $Ini
    }
    $lines = [System.Collections.Generic.List[string]](Get-Content $Ini)
    $index = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match "^\s*$key\s*=") { $index = $i } }
    if ($index -ge 0) { $lines[$index] = "$key = $value" } else { $lines.Add("$key = $value") }
    Set-Content $Ini $lines -Encoding ascii
}

$Resolutions = [ordered]@{ 'Native (480p)' = 1; '720p' = 2; '1080p' = 3; '1440p' = 4; '4K' = 6; '5K+ (8x)' = 8 }
$Upscalers = [ordered]@{ 'Off' = 0; 'AMD FSR 1 (any GPU)' = 1; 'NVIDIA DLSS (RTX)' = 2 }
$Renderers = [ordered]@{ 'Vulkan (recommended)' = 14; 'Direct3D 11' = 3; 'Direct3D 12' = 15; 'OpenGL' = 12 }

# ---------------------------------------------------------------- window
$form = New-Object Windows.Forms.Form
$form.Text = 'NBA Street V3 - PC'
$form.Size = New-Object Drawing.Size(520, 646)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI', 10)

$title = New-Object Windows.Forms.Label
$title.Text = 'NBA Street V3'
$title.Font = New-Object Drawing.Font('Segoe UI', 18, [Drawing.FontStyle]::Bold)
$title.Location = '20,12'; $title.AutoSize = $true
$form.Controls.Add($title)

$isoLabel = New-Object Windows.Forms.Label
$isoLabel.Text = 'Your game disc image (NBA Street V3 USA ISO, SLUS-21126):'
$isoLabel.Location = '20,60'; $isoLabel.AutoSize = $true
$form.Controls.Add($isoLabel)

$isoBox = New-Object Windows.Forms.TextBox
$isoBox.Location = '20,84'; $isoBox.Size = '370,26'; $isoBox.Text = $settings.Iso
$form.Controls.Add($isoBox)

$browse = New-Object Windows.Forms.Button
$browse.Text = 'Browse...'; $browse.Location = '398,82'; $browse.Size = '90,30'
$browse.Add_Click({
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $dialog.Title = 'Choose your NBA Street V3 ISO'
    $dialog.Filter = 'Disc image (*.iso)|*.iso|All files (*.*)|*.*'
    if ($dialog.ShowDialog() -eq 'OK') { $isoBox.Text = $dialog.FileName; $settings.Iso = $dialog.FileName; Save-Settings }
})
$form.Controls.Add($browse)

$status = New-Object Windows.Forms.Label
$status.Location = '20,124'; $status.Size = '470,44'
$form.Controls.Add($status)

# Graphics
$group = New-Object Windows.Forms.GroupBox
$group.Text = 'Graphics'; $group.Location = '20,172'; $group.Size = '468,186'
$form.Controls.Add($group)

$resLabel = New-Object Windows.Forms.Label
$resLabel.Text = 'Resolution:'; $resLabel.Location = '12,28'; $resLabel.AutoSize = $true
$group.Controls.Add($resLabel)
$resBox = New-Object Windows.Forms.ComboBox
$resBox.DropDownStyle = 'DropDownList'; $resBox.Location = '170,24'; $resBox.Size = '200,26'
$Resolutions.Keys | ForEach-Object { [void]$resBox.Items.Add($_) }
$group.Controls.Add($resBox)

$renLabel = New-Object Windows.Forms.Label
$renLabel.Text = 'Renderer:'; $renLabel.Location = '12,60'; $renLabel.AutoSize = $true
$group.Controls.Add($renLabel)
$renBox = New-Object Windows.Forms.ComboBox
$renBox.DropDownStyle = 'DropDownList'; $renBox.Location = '170,56'; $renBox.Size = '200,26'
$Renderers.Keys | ForEach-Object { [void]$renBox.Items.Add($_) }
$group.Controls.Add($renBox)

$upLabel = New-Object Windows.Forms.Label
$upLabel.Text = 'Upscaling:'; $upLabel.Location = '12,92'; $upLabel.AutoSize = $true
$group.Controls.Add($upLabel)
$upBox = New-Object Windows.Forms.ComboBox
$upBox.DropDownStyle = 'DropDownList'; $upBox.Location = '170,88'; $upBox.Size = '200,26'
$Upscalers.Keys | ForEach-Object { [void]$upBox.Items.Add($_) }
$group.Controls.Add($upBox)
$fullBox = New-Object Windows.Forms.CheckBox
$fullBox.Text = 'Fullscreen'; $fullBox.Location = '12,120'; $fullBox.AutoSize = $true
$fullBox.Checked = $settings.Fullscreen
$group.Controls.Add($fullBox)
$smoothBox = New-Object Windows.Forms.CheckBox
$smoothBox.Text = 'NVIDIA Smooth Motion (120+ Hz screens)'; $smoothBox.Location = '150,120'; $smoothBox.AutoSize = $true
$smoothBox.Checked = $settings.SmoothMotion
$group.Controls.Add($smoothBox)
# NVIDIA DLSS runtime used by the renderer (like DLSS Swapper: the player can put in a newer one)
$dlssLabel = New-Object Windows.Forms.Label
$dlssLabel.Location = '12,154'; $dlssLabel.Size = '250,22'; $dlssLabel.ForeColor = [Drawing.Color]::DimGray
$group.Controls.Add($dlssLabel)
$dlssButton = New-Object Windows.Forms.Button
$dlssButton.Text = 'Use another DLSS DLL...'; $dlssButton.Location = '270,148'; $dlssButton.Size = '186,30'
$group.Controls.Add($dlssButton)

# HD textures
$texGroup = New-Object Windows.Forms.GroupBox
$texGroup.Text = 'HD textures'; $texGroup.Location = '20,366'; $texGroup.Size = '468,92'
$form.Controls.Add($texGroup)

$texBox = New-Object Windows.Forms.CheckBox
$texBox.Text = 'Use HD textures'; $texBox.Location = '12,26'; $texBox.AutoSize = $true
$texGroup.Controls.Add($texBox)

$texCount = New-Object Windows.Forms.Label
$texCount.Location = '200,28'; $texCount.Size = '260,22'; $texCount.ForeColor = [Drawing.Color]::DimGray
$texGroup.Controls.Add($texCount)

$texZip = New-Object Windows.Forms.Button
$texZip.Text = 'Add texture pack (.zip)...'; $texZip.Location = '12,54'; $texZip.Size = '210,30'
$texGroup.Controls.Add($texZip)

$texFolder = New-Object Windows.Forms.Button
$texFolder.Text = 'Add texture pack (folder)...'; $texFolder.Location = '232,54'; $texFolder.Size = '224,30'
$texGroup.Controls.Add($texFolder)

# Online
$netGroup = New-Object Windows.Forms.GroupBox
$netGroup.Text = 'Online'; $netGroup.Location = '20,466'; $netGroup.Size = '468,56'
$form.Controls.Add($netGroup)
$onlineLabel = New-Object Windows.Forms.Label
$onlineLabel.Text = 'Ready - choose PLAY ONLINE in the game menu.'; $onlineLabel.Location = '12,26'; $onlineLabel.AutoSize = $true
$onlineLabel.ForeColor = [Drawing.Color]::DarkGreen
$netGroup.Controls.Add($onlineLabel)

$prepare = New-Object Windows.Forms.Button
$prepare.Text = 'Prepare game'; $prepare.Location = '20,532'; $prepare.Size = '150,44'
$form.Controls.Add($prepare)

$play = New-Object Windows.Forms.Button
$play.Text = 'PLAY'; $play.Location = '338,532'; $play.Size = '150,44'
$play.Font = New-Object Drawing.Font('Segoe UI', 12, [Drawing.FontStyle]::Bold)
$form.Controls.Add($play)

$help = New-Object Windows.Forms.Label
$help.Text = 'In game: F1 or hold START = graphics menu. Alt+Enter = window/fullscreen.'
$help.Location = '20,584'; $help.AutoSize = $true; $help.ForeColor = [Drawing.Color]::DimGray
$form.Controls.Add($help)

function Update-TextureCount {
    $n = 0
    if (Test-Path $TextureDir) { $n = @(Get-ChildItem $TextureDir -Recurse -File -Include *.png, *.dds -ErrorAction SilentlyContinue).Count }
    $texCount.Text = if ($n) { "$n textures installed" } else { 'No texture pack installed yet' }
}

function Install-TexturePack($source) {
    $form.UseWaitCursor = $true
    $texCount.Text = 'Installing...'
    [Windows.Forms.Application]::DoEvents()
    try {
        $result = & "$Repo\tools\install_textures.ps1" -Source $source -Root $Root | Select-Object -Last 1
        $installed = if ($result -match 'installed=(\d+)') { [int]$Matches[1] } else { 0 }
        $skipped = if ($result -match 'skipped=(\d+)') { [int]$Matches[1] } else { 0 }
        if ($installed -gt 0) {
            $texBox.Checked = $true
            $message = "$installed HD textures installed. They will be used the next time you press PLAY."
            if ($skipped) { $message += "`n`n$skipped textures were skipped on purpose (they are known to break the image)." }
            [Windows.Forms.MessageBox]::Show($message, 'HD textures') | Out-Null
        } else {
            [Windows.Forms.MessageBox]::Show('No textures (.png or .dds files) were found in that pack.', 'HD textures') | Out-Null
        }
    } catch {
        [Windows.Forms.MessageBox]::Show("The texture pack could not be installed:`n$($_.Exception.Message)", 'HD textures') | Out-Null
    } finally {
        $form.UseWaitCursor = $false
        Update-TextureCount
    }
}

$texZip.Add_Click({
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $dialog.Title = 'Choose an HD texture pack for NBA Street V3'
    $dialog.Filter = 'Texture pack (*.zip)|*.zip'
    if ($dialog.ShowDialog() -eq 'OK') { Install-TexturePack $dialog.FileName }
})
$texFolder.Add_Click({
    $dialog = New-Object Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Choose the folder of an HD texture pack for NBA Street V3'
    if ($dialog.ShowDialog() -eq 'OK') { Install-TexturePack $dialog.SelectedPath }
})

# ---------------------------------------------------------------- NVIDIA DLSS runtime (nvngx_dlss.dll)
$DlssDll = "$GsHost\nvngx_dlss.dll"
function Update-DlssVersion {
    if (Test-Path $DlssDll) {
        $v = (Get-Item $DlssDll).VersionInfo.FileVersion -replace ',', '.' -replace ' ', ''
        $dlssLabel.Text = "NVIDIA DLSS version: $v"
    } else {
        $dlssLabel.Text = 'NVIDIA DLSS: not installed (RTX only)'
    }
}
# Only NVIDIA's own, untouched DLSS runtime is accepted: valid NVIDIA signature and the DLSS
# product name. The previous file is kept as nvngx_dlss.prev.dll.
function Install-DlssDll($file) {
    $sig = Get-AuthenticodeSignature $file
    $info = (Get-Item $file).VersionInfo
    if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=NVIDIA Corporation') {
        [Windows.Forms.MessageBox]::Show("This file is not signed by NVIDIA (or it was modified after signing), so it was not used.`n`nSignature: $($sig.Status)", 'NVIDIA DLSS') | Out-Null
        return
    }
    if ($info.ProductName -notmatch 'Deep Learning SuperSampling') {
        [Windows.Forms.MessageBox]::Show("This NVIDIA file is not the DLSS runtime (nvngx_dlss.dll):`n$($info.ProductName)", 'NVIDIA DLSS') | Out-Null
        return
    }
    try {
        New-Item -ItemType Directory -Force $GsHost | Out-Null
        if (Test-Path $DlssDll) { Copy-Item $DlssDll "$GsHost\nvngx_dlss.prev.dll" -Force }
        Copy-Item $file $DlssDll -Force
        Update-DlssVersion
        [Windows.Forms.MessageBox]::Show("DLSS $($info.FileVersion -replace ',', '.' -replace ' ', '') installed. It is used the next time you press PLAY (Upscaling: NVIDIA DLSS).", 'NVIDIA DLSS') | Out-Null
    } catch {
        [Windows.Forms.MessageBox]::Show("The DLSS file could not be installed (is the game running?):`n$($_.Exception.Message)", 'NVIDIA DLSS') | Out-Null
    }
}
$dlssButton.Add_Click({
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $dialog.Title = 'Choose an NVIDIA DLSS runtime (nvngx_dlss.dll)'
    $dialog.Filter = 'NVIDIA DLSS (nvngx_dlss.dll)|nvngx_dlss.dll|DLL files (*.dll)|*.dll'
    if ($dialog.ShowDialog() -eq 'OK') { Install-DlssDll $dialog.FileName }
})

function Load-Graphics {
    $values = Read-Ini
    $scale = if ($values['upscale_multiplier']) { [int]$values['upscale_multiplier'] } else { 3 }
    $renderer = if ($values['Renderer']) { [int]$values['Renderer'] } else { 14 }
    $resBox.SelectedItem = ($Resolutions.Keys | Where-Object { $Resolutions[$_] -eq $scale } | Select-Object -First 1)
    if (-not $resBox.SelectedItem) { $resBox.SelectedItem = '1080p' }
    $renBox.SelectedItem = ($Renderers.Keys | Where-Object { $Renderers[$_] -eq $renderer } | Select-Object -First 1)
    if (-not $renBox.SelectedItem) { $renBox.SelectedItem = 'Vulkan (recommended)' }
    $texBox.Checked = $values['LoadTextureReplacements'] -eq 'true'
    $up = if ($values['NbaUpscaler']) { [int]$values['NbaUpscaler'] } else { 0 }
    $upBox.SelectedItem = ($Upscalers.Keys | Where-Object { $Upscalers[$_] -eq $up } | Select-Object -First 1)
    if (-not $upBox.SelectedItem) { $upBox.SelectedItem = 'Off' }
}
function Save-Graphics {
    Write-IniValue 'upscale_multiplier' $Resolutions[$resBox.SelectedItem]
    Write-IniValue 'Renderer' $Renderers[$renBox.SelectedItem]
    Write-IniValue 'NbaUpscaler' $Upscalers[$upBox.SelectedItem]
    Write-IniValue 'LoadTextureReplacements' $(if ($texBox.Checked) { 'true' } else { 'false' })
    $settings.Fullscreen = $fullBox.Checked
    $settings.SmoothMotion = $smoothBox.Checked
    Save-Settings
}

function Update-Status {
    $ready = (Test-Path $GameExe) -and (Test-Path "$GsHost\pcsx2-gsrunner.exe") -and (Test-Path "$Root\game\iso\SLUS_211.26")
    $play.Enabled = $ready
    if ($ready) {
        $status.Text = 'The game is ready. Press PLAY.'
        $status.ForeColor = [Drawing.Color]::DarkGreen
        $prepare.Text = 'Repair'
    } else {
        $status.Text = "First time: choose your ISO and press 'Prepare game'. It builds the game on your PC (about 6 GB of downloads; the first time can take 1-2 hours)."
        $status.ForeColor = [Drawing.Color]::DarkOrange
        $prepare.Text = 'Prepare game'
    }
}

$prepare.Add_Click({
    $iso = $isoBox.Text.Trim()
    if (-not (Test-Path "$Root\game\iso\SLUS_211.26") -and -not (Test-Path $iso)) {
        [Windows.Forms.MessageBox]::Show('Choose your NBA Street V3 ISO first (Browse...).', 'NBA Street V3') | Out-Null
        return
    }
    $settings.Iso = $iso; Save-Settings
    $arguments = @('-NoExit', '-ExecutionPolicy', 'Bypass', '-File', "`"$Repo\tools\install.ps1`"")
    if ($iso) { $arguments += @('-Iso', "`"$iso`"") }
    $form.Enabled = $false
    $status.Text = 'Preparing... progress is shown in the other window. Close it when it says "Done".'
    $proc = Start-Process powershell -ArgumentList $arguments -PassThru
    while (-not $proc.HasExited) { [Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 200 }
    $form.Enabled = $true
    Load-Graphics
    Update-Status
})

$play.Add_Click({
    Save-Graphics
    New-Item -ItemType Directory -Force "$Root\logs" | Out-Null
    $env:PS2X_GS_LIVE = '1'
    # Online is always available: emulated network adapter + community server; the network
    # settings live on the memory card (offline modes are unaffected).
    $env:PS2X_NET = '1'
    $env:PS2X_NET_SERVER = $Server
    $netcnf = "$Root\game\iso\mc0\BWNETCNF"
    if (-not (Test-Path "$netcnf\BWNETCNF")) {
        New-Item -ItemType Directory -Force $netcnf | Out-Null
        Copy-Item "$Repo\game\mc0_netcnf\BWNETCNF\*" $netcnf -Force
    }
    # NVIDIA driver frame generation (RTX 40/50, Vulkan): doubles the frames shown on 120+ Hz
    # screens; the game itself still runs at 60. Read by the NVIDIA driver from the environment.
    $env:NVPRESENT_ENABLE_SMOOTH_MOTION = if ($smoothBox.Checked) { '1' } else { $null }
    $env:PS2X_GSHOST_ARGS = '-renderer ' + $(switch ($Renderers[$renBox.SelectedItem]) { 3 { 'dx11' } 15 { 'dx12' } 12 { 'gl' } default { 'vulkan' } }) +
        ' -ini nba_street.ini' + $(if ($fullBox.Checked) { ' -fullscreen' } else { '' })
    Start-Process $GameExe -ArgumentList "`"$Root\game\iso\SLUS_211.26`"" -WorkingDirectory "$Root\game\iso" -WindowStyle Hidden `
        -RedirectStandardOutput "$Root\logs\play.log" -RedirectStandardError "$Root\logs\play_err.log"
    $form.WindowState = 'Minimized'
})

$form.Add_FormClosing({ Save-Graphics })
Load-Graphics
Update-TextureCount
Update-DlssVersion
Update-Status
[void]$form.ShowDialog()
