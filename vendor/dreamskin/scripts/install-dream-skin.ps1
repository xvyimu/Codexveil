[CmdletBinding()]
param(
  [int]$Port = 9335,
  [switch]$NoShortcuts
)

$ErrorActionPreference = 'Stop'
$PortExplicit = $PSBoundParameters.ContainsKey('Port')
$SkillRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'common-windows.ps1')
. (Join-Path $PSScriptRoot 'theme-windows.ps1')
. (Join-Path $PSScriptRoot 'runtime-windows.ps1')

$operationLock = Enter-DreamSkinOperationLock
try {
  Assert-DreamSkinPort -Port $Port
  $null = Get-DreamSkinNodeRuntime
  $registeredInstalls = @(Get-DreamSkinRegisteredCodexInstalls)
  if ($registeredInstalls.Count -eq 0) {
    throw 'The official OpenAI.Codex Store package is not installed or its identity cannot be validated.'
  }
  foreach ($registeredCodex in $registeredInstalls) {
    if ((Get-DreamSkinCodexProcesses -Codex $registeredCodex).Count -gt 0) {
      throw 'Close Codex before installing Dream Skin so config.toml cannot change during the transaction.'
    }
  }

  $ProgramRoot = Join-Path $env:LOCALAPPDATA 'Programs\CodexDreamSkin'
  $previousRuntime = $null
  if (Test-Path -LiteralPath $ProgramRoot) {
    $previousRuntime = Resolve-DreamSkinCurrentRuntime -ProgramRoot $ProgramRoot
  }
  $trayScriptsToStop = @((Join-Path $PSScriptRoot 'tray-dream-skin.ps1'))
  if ($null -ne $previousRuntime) { $trayScriptsToStop += $previousRuntime.TrayScript }
  $trayScriptsToStop | Sort-Object -Unique | ForEach-Object {
    Stop-DreamSkinTrayProcess -TrayScript $_
  }

  $runtime = Install-DreamSkinRuntime -SkillRoot $SkillRoot -ProgramRoot $ProgramRoot
  $trayScript = $runtime.TrayScript
  $launcherScript = $runtime.LauncherScript

  $StateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
  $themePaths = Get-DreamSkinThemePaths -StateRoot $StateRoot
  Ensure-DreamSkinManagedDirectory -Path $themePaths.Root -Root $themePaths.Root
  $StatePath = Join-Path $StateRoot 'state.json'
  $existingState = Read-DreamSkinState -Path $StatePath
  $savedPathCandidate = Get-DreamSkinCodexStatePathCandidate -State $existingState
  $savedCodex = Resolve-DreamSkinCodexInstallFromState -State $existingState -RegisteredInstalls $registeredInstalls
  if ($null -ne $savedPathCandidate -and $null -eq $savedCodex -and
    (Get-DreamSkinCodexProcesses -Codex $savedPathCandidate).Count -gt 0) {
    throw 'The saved Codex path is still running but no longer matches a registered Store package. Close it manually before installing.'
  }
  $null = Initialize-DreamSkinThemeStore -SkillRoot $SkillRoot -StateRoot $StateRoot
  $ConfigPath = Join-Path $HOME '.codex\config.toml'
  $BackupPath = Join-Path $StateRoot 'config.before-dream-skin.toml'
  Install-DreamSkinBaseTheme -ConfigPath $ConfigPath -BackupPath $BackupPath

  if (-not $NoShortcuts) {
    $shell = New-Object -ComObject WScript.Shell
    $desktop = [Environment]::GetFolderPath('Desktop')
    $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
    $powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
    $portArgument = if ($PortExplicit) { " -Port $Port" } else { '' }

    foreach ($folder in @($desktop, $startMenu)) {
      $shortcut = $shell.CreateShortcut((Join-Path $folder 'Codex Dream Skin.lnk'))
      $shortcut.TargetPath = $powershell
      $shortcut.Arguments = "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File `"$launcherScript`"$portArgument -ShowMenu"
      $shortcut.WorkingDirectory = $ProgramRoot
      $shortcut.Description = 'Open unified Codex Dream Skin controls'
      $shortcut.Save()
    }

    @(
      (Join-Path $desktop 'Codex Dream Skin - Restore.lnk'),
      (Join-Path $desktop 'Codex Dream Skin - Tray.lnk'),
      (Join-Path $startMenu 'Codex Dream Skin - Restore.lnk'),
      (Join-Path $startMenu 'Codex Dream Skin - Tray.lnk')
    ) | ForEach-Object { Remove-Item -LiteralPath $_ -Force -ErrorAction SilentlyContinue }
    Stop-DreamSkinTrayProcess -TrayScript $trayScript
    Start-Process -FilePath $powershell -ArgumentList `
      "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File `"$trayScript`"$portArgument" `
      -WindowStyle Hidden | Out-Null
  }

  if ($NoShortcuts) {
    Write-Host 'Codex Dream Skin base theme installed. Run start-dream-skin.ps1 to launch it.'
  } else {
    Write-Host 'Codex Dream Skin installed. One shortcut opens all skin controls.'
  }
} finally {
  Exit-DreamSkinOperationLock -Mutex $operationLock
}
