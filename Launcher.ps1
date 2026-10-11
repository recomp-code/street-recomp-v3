<#
  Launcher de NBA Street V3 (port PC): elige tu ISO, prepara el juego la primera vez y juega.
  Se abre con Launcher.cmd. La preparacion (compilar el juego en tu PC) solo se hace una vez.
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

# ---------------------------------------------------------------- ajustes del launcher
# Servidor online por defecto (se puede cambiar en la ventana).
$DefaultServer = 'nbas3.xellrecomp.party'
$settings = @{ Iso = ''; Fullscreen = $true; Online = $true; Server = $DefaultServer }
try {
    if (Test-Path $SettingsFile) {
        $loaded = Get-Content $SettingsFile -Raw | ConvertFrom-Json
        if ($loaded.Iso) { $settings.Iso = $loaded.Iso }
        if ($null -ne $loaded.Fullscreen) { $settings.Fullscreen = [bool]$loaded.Fullscreen }
        if ($null -ne $loaded.Online) { $settings.Online = [bool]$loaded.Online }
        if ($loaded.Server) { $settings.Server = $loaded.Server }
    }
} catch {}
function Save-Settings { try { $settings | ConvertTo-Json | Set-Content $SettingsFile } catch {} }

# ---------------------------------------------------------------- nba_street.ini (opciones graficas)
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

$Resolutions = [ordered]@{ 'Nativa (480p)' = 1; '720p' = 2; '1080p' = 3; '1440p' = 4; '4K' = 6; '8x (5K+)' = 8 }
$Renderers = [ordered]@{ 'Vulkan (recomendado)' = 14; 'Direct3D 11' = 3; 'Direct3D 12' = 15; 'OpenGL' = 12 }

# ---------------------------------------------------------------- ventana
$form = New-Object Windows.Forms.Form
$form.Text = 'NBA Street V3 - PC'
$form.Size = New-Object Drawing.Size(520, 500)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$font = New-Object Drawing.Font('Segoe UI', 10)
$form.Font = $font

$title = New-Object Windows.Forms.Label
$title.Text = 'NBA Street V3'
$title.Font = New-Object Drawing.Font('Segoe UI', 18, [Drawing.FontStyle]::Bold)
$title.Location = '20,12'; $title.AutoSize = $true
$form.Controls.Add($title)

$isoLabel = New-Object Windows.Forms.Label
$isoLabel.Text = 'Tu ISO (NBA Street V3, NTSC-U SLUS-21126):'
$isoLabel.Location = '20,60'; $isoLabel.AutoSize = $true
$form.Controls.Add($isoLabel)

$isoBox = New-Object Windows.Forms.TextBox
$isoBox.Location = '20,84'; $isoBox.Size = '370,26'; $isoBox.Text = $settings.Iso
$form.Controls.Add($isoBox)

$browse = New-Object Windows.Forms.Button
$browse.Text = 'Elegir...'; $browse.Location = '398,82'; $browse.Size = '90,30'
$browse.Add_Click({
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $dialog.Filter = 'Imagen de disco (*.iso)|*.iso|Todos los archivos (*.*)|*.*'
    if ($dialog.ShowDialog() -eq 'OK') { $isoBox.Text = $dialog.FileName; $settings.Iso = $dialog.FileName; Save-Settings }
})
$form.Controls.Add($browse)

$status = New-Object Windows.Forms.Label
$status.Location = '20,124'; $status.Size = '470,44'
$form.Controls.Add($status)

$group = New-Object Windows.Forms.GroupBox
$group.Text = 'Graficos'; $group.Location = '20,172'; $group.Size = '468,120'
$form.Controls.Add($group)

$resLabel = New-Object Windows.Forms.Label
$resLabel.Text = 'Resolucion interna:'; $resLabel.Location = '12,28'; $resLabel.AutoSize = $true
$group.Controls.Add($resLabel)
$resBox = New-Object Windows.Forms.ComboBox
$resBox.DropDownStyle = 'DropDownList'; $resBox.Location = '170,24'; $resBox.Size = '180,26'
$Resolutions.Keys | ForEach-Object { [void]$resBox.Items.Add($_) }
$group.Controls.Add($resBox)

$renLabel = New-Object Windows.Forms.Label
$renLabel.Text = 'Renderizador:'; $renLabel.Location = '12,60'; $renLabel.AutoSize = $true
$group.Controls.Add($renLabel)
$renBox = New-Object Windows.Forms.ComboBox
$renBox.DropDownStyle = 'DropDownList'; $renBox.Location = '170,56'; $renBox.Size = '180,26'
$Renderers.Keys | ForEach-Object { [void]$renBox.Items.Add($_) }
$group.Controls.Add($renBox)

$fullBox = New-Object Windows.Forms.CheckBox
$fullBox.Text = 'Pantalla completa'; $fullBox.Location = '12,88'; $fullBox.AutoSize = $true
$fullBox.Checked = $settings.Fullscreen
$group.Controls.Add($fullBox)

$texBox = New-Object Windows.Forms.CheckBox
$texBox.Text = 'Texturas HD'; $texBox.Location = '200,88'; $texBox.AutoSize = $true
$group.Controls.Add($texBox)

$netGroup = New-Object Windows.Forms.GroupBox
$netGroup.Text = 'Online'; $netGroup.Location = '20,300'; $netGroup.Size = '468,76'
$form.Controls.Add($netGroup)
$onlineBox = New-Object Windows.Forms.CheckBox
$onlineBox.Text = 'Jugar online (PLAY ONLINE en el juego)'; $onlineBox.Location = '12,24'; $onlineBox.AutoSize = $true
$onlineBox.Checked = $settings.Online
$netGroup.Controls.Add($onlineBox)
$serverLabel = New-Object Windows.Forms.Label
$serverLabel.Text = 'Servidor:'; $serverLabel.Location = '12,50'; $serverLabel.AutoSize = $true
$netGroup.Controls.Add($serverLabel)
$serverBox = New-Object Windows.Forms.TextBox
$serverBox.Location = '90,46'; $serverBox.Size = '260,24'; $serverBox.Text = $settings.Server
$netGroup.Controls.Add($serverBox)

$prepare = New-Object Windows.Forms.Button
$prepare.Text = 'Preparar juego'; $prepare.Location = '20,386'; $prepare.Size = '150,44'
$form.Controls.Add($prepare)

$play = New-Object Windows.Forms.Button
$play.Text = 'JUGAR'; $play.Location = '338,386'; $play.Size = '150,44'
$play.Font = New-Object Drawing.Font('Segoe UI', 12, [Drawing.FontStyle]::Bold)
$form.Controls.Add($play)

$help = New-Object Windows.Forms.Label
$help.Text = 'En el juego: F1 o mantener START = menu grafico. Alt+Enter = ventana.'
$help.Location = '20,438'; $help.AutoSize = $true; $help.ForeColor = [Drawing.Color]::DimGray
$form.Controls.Add($help)

function Load-Graphics {
    $values = Read-Ini
    $scale = if ($values['upscale_multiplier']) { [int]$values['upscale_multiplier'] } else { 3 }
    $renderer = if ($values['Renderer']) { [int]$values['Renderer'] } else { 14 }
    $resBox.SelectedItem = ($Resolutions.Keys | Where-Object { $Resolutions[$_] -eq $scale } | Select-Object -First 1)
    if (-not $resBox.SelectedItem) { $resBox.SelectedItem = '1080p' }
    $renBox.SelectedItem = ($Renderers.Keys | Where-Object { $Renderers[$_] -eq $renderer } | Select-Object -First 1)
    if (-not $renBox.SelectedItem) { $renBox.SelectedItem = 'Vulkan (recomendado)' }
    $texBox.Checked = $values['LoadTextureReplacements'] -eq 'true'
}
function Save-Graphics {
    Write-IniValue 'upscale_multiplier' $Resolutions[$resBox.SelectedItem]
    Write-IniValue 'Renderer' $Renderers[$renBox.SelectedItem]
    Write-IniValue 'LoadTextureReplacements' $(if ($texBox.Checked) { 'true' } else { 'false' })
    $settings.Fullscreen = $fullBox.Checked
    $settings.Online = $onlineBox.Checked
    $settings.Server = $(if ($serverBox.Text.Trim()) { $serverBox.Text.Trim() } else { $DefaultServer })
    Save-Settings
}

function Update-Status {
    $ready = (Test-Path $GameExe) -and (Test-Path "$GsHost\pcsx2-gsrunner.exe") -and (Test-Path "$Root\game\iso\SLUS_211.26")
    $play.Enabled = $ready
    if ($ready) {
        $status.Text = 'Juego preparado. Pulsa JUGAR.'
        $status.ForeColor = [Drawing.Color]::DarkGreen
        $prepare.Text = 'Reparar'
    } else {
        $status.Text = "Primera vez: elige tu ISO y pulsa 'Preparar juego'. Compila el juego en tu PC (descarga ~6 GB de herramientas; la primera compilacion puede tardar 1-2 horas)."
        $status.ForeColor = [Drawing.Color]::DarkOrange
        $prepare.Text = 'Preparar juego'
    }
}

$prepare.Add_Click({
    $iso = $isoBox.Text.Trim()
    if (-not (Test-Path "$Root\game\iso\SLUS_211.26") -and -not (Test-Path $iso)) {
        [Windows.Forms.MessageBox]::Show('Elige primero tu ISO de NBA Street V3.', 'NBA Street V3') | Out-Null
        return
    }
    $settings.Iso = $iso; Save-Settings
    $arguments = @('-NoExit', '-ExecutionPolicy', 'Bypass', '-File', "`"$Repo\tools\install.ps1`"")
    if ($iso) { $arguments += @('-Iso', "`"$iso`"") }
    $form.Enabled = $false
    $status.Text = 'Preparando... sigue el progreso en la ventana negra. Puedes cerrarla cuando ponga "Listo".'
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
    if ($onlineBox.Checked) {
        # Adaptador de red emulado + servidor; la configuracion de red va en la memory card.
        $env:PS2X_NET = '1'
        $env:PS2X_NET_SERVER = $settings.Server
        $netcnf = "$Root\game\iso\mc0\BWNETCNF"
        if (-not (Test-Path "$netcnf\BWNETCNF")) {
            New-Item -ItemType Directory -Force $netcnf | Out-Null
            Copy-Item "$Repo\game\mc0_netcnf\BWNETCNF\*" $netcnf -Force
        }
    } else {
        $env:PS2X_NET = '0'
    }
    $env:PS2X_GSHOST_ARGS = '-renderer ' + $(switch ($Renderers[$renBox.SelectedItem]) { 3 { 'dx11' } 15 { 'dx12' } 12 { 'gl' } default { 'vulkan' } }) +
        ' -ini nba_street.ini' + $(if ($fullBox.Checked) { ' -fullscreen' } else { '' })
    Start-Process $GameExe -ArgumentList "`"$Root\game\iso\SLUS_211.26`"" -WorkingDirectory "$Root\game\iso" -WindowStyle Hidden `
        -RedirectStandardOutput "$Root\logs\jugar.log" -RedirectStandardError "$Root\logs\jugar_err.log"
    $form.WindowState = 'Minimized'
})

$form.Add_FormClosing({ Save-Graphics })
Load-Graphics
Update-Status
[void]$form.ShowDialog()
