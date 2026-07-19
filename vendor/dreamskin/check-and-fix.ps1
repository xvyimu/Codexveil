[CmdletBinding()]
param(
  [ValidateRange(1024, 65535)][int]$Port = 9335,
  [switch]$Quiet
)
$ErrorActionPreference = 'Stop'
$programRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$stateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
$logPath = Join-Path $stateRoot 'check-and-fix.log'
$open = Join-Path $programRoot 'open-codex-dream-skin.ps1'
$lock = Join-Path $programRoot 'lock-themes.ps1'

function Log([string]$m) {
  [System.IO.Directory]::CreateDirectory($stateRoot) | Out-Null
  [System.IO.File]::AppendAllText($logPath, ('{0:u} {1}' -f (Get-Date), $m) + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
  if (-not $Quiet) { Write-Host $m }
}
function Ui([string]$m, [string]$kind = 'Info') {
  if ($Quiet) { return }
  Add-Type -AssemblyName System.Windows.Forms | Out-Null
  $icon = if ($kind -eq 'Error') { [System.Windows.Forms.MessageBoxIcon]::Error } else { [System.Windows.Forms.MessageBoxIcon]::Information }
  [void][System.Windows.Forms.MessageBox]::Show($m, 'Codex Dream Skin 修复', [System.Windows.Forms.MessageBoxButtons]::OK, $icon)
}


try {
  if (-not (Test-Path -LiteralPath $open)) { throw 'missing open-codex-dream-skin.ps1' }
  $current = Get-Content (Join-Path $programRoot 'current.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $runtimeRoot = Join-Path $programRoot ($current.relativeEnginePath -replace '/', '\')
  . (Join-Path $runtimeRoot 'scripts\common-windows.ps1')
  . (Join-Path $runtimeRoot 'scripts\theme-windows.ps1')
  $node = Get-DreamSkinNodeRuntime
  $codex = Get-DreamSkinCodexInstall
  $inj = Join-Path $runtimeRoot 'scripts\injector.mjs'
  $cdp = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $codex
  $statePath = Join-Path $stateRoot 'state.json'
  $state = $null
  if (Test-Path -LiteralPath $statePath) { try { $state = Read-DreamSkinState -Path $statePath } catch {} }
  $themes = Join-Path $stateRoot 'themes'
  $locked = Test-DreamSkinThemesLocked -StateRoot $stateRoot
  $extraThemes = @()
  if (Test-Path -LiteralPath $themes) {
    $extraThemes = @(Get-ChildItem -LiteralPath $themes -Directory -Force -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -notmatch '^\.' })
  }
  Log ("cdp=" + [bool]$cdp + " locked=" + $locked + " catalogThemes=" + $extraThemes.Count + " injectorAlive=" + (Test-DreamSkinInjectorAlive $state) + " runtime=" + $current.runtimeId)

  # Multi-theme product line: never delete catalog themes during repair.
  # Only warn if lock is on while catalog has multiple skins (user may want unlock).
  if ($locked -and $extraThemes.Count -gt 1) {
    Log ("warn: themes locked with " + $extraThemes.Count + " catalog entries; F6/tray multi-switch disabled until unlock")
  }
  if (-not $locked) {
    Log ("multi-theme catalog unlocked; entries=" + $extraThemes.Count)
  }

  $needOpen = $true

  # Case: CDP alive + identity matches + injector alive + verify pass => healthy
  if ($null -ne $cdp -and $null -ne $state -and $state.browserId -ceq $cdp.BrowserId -and (Test-DreamSkinInjectorAlive $state)) {
    $verify = Invoke-DreamSkinNative -FilePath $node.Path -ArgumentList @(
      $inj, '--verify', '--port', "$Port", '--browser-id', $cdp.BrowserId, '--timeout-ms', '12000'
    )
    if ($verify.ExitCode -eq 0) {
      Log 'already healthy'
      $needOpen = $false
    } else {
      Log 'verify failed on healthy-looking session; will reattach'
    }
  }

  # Case: CDP alive but injector dead OR browserId drift => reattach injector only (no Codex restart)
  if ($needOpen -and $null -ne $cdp) {
    Log 'reattaching injector on existing CDP session'
    if ($state) {
      try { [void](Stop-DreamSkinRecordedInjector -State $state) } catch { Log ('old injector stop: ' + $_.Exception.Message) }
    }
    $paths = if (Test-Path -LiteralPath (Join-Path $stateRoot 'active-theme\theme.json')) {
      Get-DreamSkinThemePaths -StateRoot $stateRoot
    } else {
      Initialize-DreamSkinThemeStore -SkillRoot $runtimeRoot -StateRoot $stateRoot
    }
    Set-DreamSkinPaused -Paused $false -StateRoot $stateRoot | Out-Null
    $stdoutPath = Join-Path $stateRoot 'injector.log'
    $stderrPath = Join-Path $stateRoot 'injector-error.log'
    '' | Set-Content -LiteralPath $stdoutPath -Encoding utf8
    '' | Set-Content -LiteralPath $stderrPath -Encoding utf8
    $daemon = Start-Process -FilePath $node.Path -ArgumentList @(
      $inj, '--watch', '--port', "$Port", '--browser-id', $cdp.BrowserId,
      '--theme-dir', $paths.Active, '--pause-file', $paths.PauseFile
    ) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    Start-Sleep -Seconds 3
    if ($daemon.HasExited) { throw 'injector exited during reattach' }
    $injectorStartedAt = Get-DreamSkinProcessStartedAt -ProcessId $daemon.Id
    $newState = [pscustomobject]@{
      schemaVersion = 3; platform = 'windows'; port = $Port
      injectorPid = $daemon.Id; injectorStartedAt = $injectorStartedAt
      injectorPath = $inj; nodePath = $node.Path; nodeVersion = $node.Version
      codexExe = $codex.Executable; codexPackageRoot = $codex.PackageRoot
      codexPackageFullName = $codex.PackageFullName; codexPackageFamilyName = $codex.PackageFamilyName
      codexVersion = $codex.Version; browserId = $cdp.BrowserId; profilePath = ''
      themeDir = $paths.Active; pauseFile = $paths.PauseFile
      createdAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    Write-DreamSkinState -Path $statePath -State $newState
    $verify2 = Invoke-DreamSkinNative -FilePath $node.Path -ArgumentList @(
      $inj, '--verify', '--port', "$Port", '--browser-id', $cdp.BrowserId, '--timeout-ms', '20000'
    )
    if ($verify2.ExitCode -eq 0) {
      Log ('reattach ok injector=' + $daemon.Id)
      $needOpen = $false
    } else {
      Log 'reattach verify failed; falling back to full open launcher'
    }
  }

  if ($needOpen) {
    Log 'repairing via open launcher'
    $argList = @('-NoProfile','-STA','-ExecutionPolicy','RemoteSigned','-File',$open,'-Port',"$Port",'-NoPrompt')
    $running = @(Get-DreamSkinCodexProcesses -Codex $codex)
    $cdpNow = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $codex
    if ($running.Count -gt 0 -and $null -eq $cdpNow) { $argList += '-RestartExisting' }
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Wait -PassThru
    if ($p.ExitCode -ne 0) { throw ('repair launcher exit ' + $p.ExitCode) }
    Log 'repair launcher ok'
  }

  Ui '皮肤检查完成，当前可用。'
  exit 0
} catch {
  Log ('failed: ' + $_.Exception.Message)
  Ui ("修复失败：`n" + $_.Exception.Message + "`n可再点「Codex 皮肤修复」或任务栏 Codex。") 'Error'
  exit 1
}
