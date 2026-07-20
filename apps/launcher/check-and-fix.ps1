#Requires -Version 5.1
<#
.SYNOPSIS
  Codex Skin 一键修复

.DESCRIPTION
  检查 CDP / injector / catalog，必要时重挂 watch 或调用 open launcher。
  成功默认不弹 MessageBox（-Quiet 更彻底）。
  多主题模式下绝不删除 catalog。

.PARAMETER Port
  CDP 端口，默认 9335。
.PARAMETER Quiet
  不写主机输出、不弹失败框。
#>
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

# 共享库
$launcherUi = @(
  (Join-Path $programRoot 'lib\launcher-ui.ps1'),
  (Join-Path $PSScriptRoot '..\..\packages\core-win\launcher-ui.ps1')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $launcherUi) { throw 'launcher-ui.ps1 missing' }
. $launcherUi

function Log([string]$m) {
  Write-CodexSkinLog -Message $m -LogPath $logPath
  if (-not $Quiet) { Write-Host $m }
}
function Ui([string]$m, [string]$kind = 'Info') {
  if ($Quiet) { return }
  [void](Show-CodexSkinMessageBox -Message $m -Kind $kind -Title 'Codex Skin 修复')
}

try {
  if (-not (Test-Path -LiteralPath $open)) { throw 'missing open-codex-dream-skin.ps1' }

  $runtimeInfo = Resolve-CodexSkinRuntimeRoot -ProgramRoot $programRoot
  $runtimeRoot = $runtimeInfo.RuntimeRoot
  $current = $runtimeInfo.Current
  . (Join-Path $runtimeInfo.ScriptsRoot 'common-windows.ps1')
  . (Join-Path $runtimeInfo.ScriptsRoot 'theme-windows.ps1')

  $node = Get-DreamSkinNodeRuntime
  $codex = Get-DreamSkinCodexInstall
  $inj = Join-Path $runtimeInfo.ScriptsRoot 'injector.mjs'
  # Short retries: a single CDP probe can false-negative during route transitions.
  if (Get-Command Get-DreamSkinVerifiedCdpIdentityRetry -ErrorAction SilentlyContinue) {
    $cdp = Get-DreamSkinVerifiedCdpIdentityRetry -Port $Port -Codex $codex -Attempts 3 -DelayMs 350
  } else {
    $cdp = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $codex
  }
  $statePath = Join-Path $stateRoot 'state.json'
  $state = $null
  if (Test-Path -LiteralPath $statePath) {
    try { $state = Read-DreamSkinState -Path $statePath } catch {}
  }

  $themes = Join-Path $stateRoot 'themes'
  $locked = Test-DreamSkinThemesLocked -StateRoot $stateRoot
  $extraThemes = @()
  if (Test-Path -LiteralPath $themes) {
    $extraThemes = @(Get-ChildItem -LiteralPath $themes -Directory -Force -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -notmatch '^\.' })
  }

  Log (
    "cdp=$([bool]$cdp) locked=$locked catalogThemes=$($extraThemes.Count) " +
    "injectorAlive=$(Test-DreamSkinInjectorAlive $state) runtime=$($current.runtimeId)"
  )

  # 多主题产品线：修复时绝不删除 catalog
  if ($locked -and $extraThemes.Count -gt 1) {
    Log "warn: themes locked with $($extraThemes.Count) catalog entries; unlock for F6/tray multi-switch"
  }
  if (-not $locked) {
    Log "multi-theme catalog unlocked; entries=$($extraThemes.Count)"
  }

  $needOpen = $true

  # Case A：CDP + browserId + injector 均健康
  if (
    $null -ne $cdp -and
    $null -ne $state -and
    $state.browserId -ceq $cdp.BrowserId -and
    (Test-DreamSkinInjectorAlive $state)
  ) {
    $fresh = Test-CodexSkinInjectorPathFresh -State $state -RuntimeInfo $runtimeInfo
    if (-not $fresh.fresh) {
      Log ("state drift detected: " + $fresh.reason + " actual=" + $fresh.actual + " expected=" + $fresh.expected)
      # 路径漂移也当不健康，走 reattach 以写回规范化 state
    } else {
      $verify = Invoke-DreamSkinNative -FilePath $node.Path -ArgumentList @(
        $inj, '--verify', '--port', "$Port", '--browser-id', $cdp.BrowserId, '--timeout-ms', '8000'
      )
      if ($verify.ExitCode -eq 0) {
        # Fast healthy path: only rewrite state when fields actually drifted.
        $needsNormalize = $false
        try {
          if ("$($state.runtimeId)" -cne "$($runtimeInfo.RuntimeId)") { $needsNormalize = $true }
          elseif ("$($state.injectorPath)" -cne "$($runtimeInfo.InjectorPath)") { $needsNormalize = $true }
          elseif (-not $state.updatedAt) { $needsNormalize = $true }
          elseif (-not $state.controlPort) { $needsNormalize = $true }
        } catch { $needsNormalize = $true }
        if ($needsNormalize) {
          try {
            $startedAt = if ($state.injectorStartedAt) { [string]$state.injectorStartedAt } else { (Get-Date).ToUniversalTime().ToString('o') }
            $normalized = New-CodexSkinRuntimeState `
              -RuntimeInfo $runtimeInfo `
              -Node $node `
              -Codex $codex `
              -Port $Port `
              -BrowserId $cdp.BrowserId `
              -InjectorPid ([int]$state.injectorPid) `
              -InjectorStartedAt $startedAt `
              -ThemeDir $(if ($state.themeDir) { [string]$state.themeDir } else { (Get-DreamSkinThemePaths -StateRoot $stateRoot).Active }) `
              -PauseFile $(if ($state.pauseFile) { [string]$state.pauseFile } else { (Get-DreamSkinThemePaths -StateRoot $stateRoot).PauseFile }) `
              -ProfilePath $(if ($state.profilePath) { [string]$state.profilePath } else { '' }) `
              -PreviousState $state
            Write-CodexSkinRuntimeState -StatePath $statePath -State $normalized
            Log 'already healthy; state normalized'
          } catch {
            Log ('state normalize skipped: ' + $_.Exception.Message)
          }
        } else {
          Log 'already healthy'
        }
        $needOpen = $false
      } else {
        Log 'verify failed on healthy-looking session; will reattach'
      }
    }
  }

  # Case B：CDP 在但 injector 死/漂移 → 只重挂 injector
  if ($needOpen -and $null -ne $cdp) {
    Log 'reattaching injector on existing CDP session'
    try {
      [void](Stop-DreamSkinRecordedInjector -State $state)
    } catch {
      Log ('old injector stop: ' + $_.Exception.Message)
      $sweep = Stop-DreamSkinWatchInjectors -Port $Port
      if (-not $sweep.Ok) {
        $sweep = Stop-DreamSkinWatchInjectors
      }
      if (-not $sweep.Ok) {
        throw ('Refusing reattach with live peer injector(s): PID ' + ($sweep.Left -join ','))
      }
    }
    $pre = Stop-DreamSkinWatchInjectors -Port $Port
    if (-not $pre.Ok) {
      throw ('Refusing reattach with live peer injector(s): PID ' + ($pre.Left -join ','))
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
    # Bounded wait instead of fixed 3s sleep
    $deadline = (Get-Date).AddSeconds(5)
    while (-not $daemon.HasExited -and (Get-Date) -lt $deadline) {
      Start-Sleep -Milliseconds 200
      if (Test-DreamSkinInjectorAlive -State ([pscustomobject]@{ injectorPid = $daemon.Id })) { break }
    }
    if ($daemon.HasExited) { throw 'injector exited during reattach' }
    $peers = Stop-DreamSkinWatchInjectors -Port $Port -ExcludeProcessId $daemon.Id
    if (-not $peers.Ok) {
      try { Stop-Process -Id $daemon.Id -Force -ErrorAction SilentlyContinue } catch {}
      throw ('Dual injector race on reattach; peers: PID ' + ($peers.Left -join ','))
    }
    if ($peers.Stopped.Count -gt 0) {
      Log ('Cleared peer injector(s): ' + ($peers.Stopped -join ','))
    }
    $injectorStartedAt = Get-DreamSkinProcessStartedAt -ProcessId $daemon.Id
    $newState = New-CodexSkinRuntimeState `
      -RuntimeInfo $runtimeInfo `
      -Node $node `
      -Codex $codex `
      -Port $Port `
      -BrowserId $cdp.BrowserId `
      -InjectorPid $daemon.Id `
      -InjectorStartedAt $injectorStartedAt `
      -ThemeDir $paths.Active `
      -PauseFile $paths.PauseFile `
      -ProfilePath '' `
      -PreviousState $state
    Write-CodexSkinRuntimeState -StatePath $statePath -State $newState
    $verify2 = Invoke-DreamSkinNative -FilePath $node.Path -ArgumentList @(
      $inj, '--verify', '--port', "$Port", '--browser-id', $cdp.BrowserId, '--timeout-ms', '12000'
    )
    if ($verify2.ExitCode -eq 0) {
      Log ('reattach ok injector=' + $daemon.Id + ' runtimeId=' + $runtimeInfo.RuntimeId)
      $needOpen = $false
    } else {
      Log 'reattach verify failed; falling back to full open launcher'
    }
  }

  # Case C：完整 open（安静 + 必要时强制重启）— hard timeout to avoid multi-minute hangs
  if ($needOpen) {
    Log 'repairing via open launcher'
    $argList = @(
      '-NoProfile', '-STA', '-ExecutionPolicy', 'RemoteSigned',
      '-File', $open, '-Port', "$Port", '-NoPrompt', '-RestartExisting'
    )
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -PassThru -WindowStyle Hidden
    $finished = $p.WaitForExit(45000)
    if (-not $finished) {
      try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch {}
      throw 'repair launcher timed out after 45s'
    }
    if ($p.ExitCode -ne 0) { throw ('repair launcher exit ' + $p.ExitCode) }
    Log 'repair launcher ok'
  }

  Log 'skin healthy'
  if (-not $Quiet -and $Host.Name -eq 'ConsoleHost' -and [Environment]::UserInteractive) {
    Write-Host '皮肤检查完成，当前可用。'
  }
  exit 0
} catch {
  Log ('failed: ' + $_.Exception.Message)
  if (-not $Quiet) {
    Ui ("修复失败：`n" + $_.Exception.Message + "`n可再点「Codex 皮肤修复」或任务栏 Codex。") 'Error'
  }
  exit 1
}
