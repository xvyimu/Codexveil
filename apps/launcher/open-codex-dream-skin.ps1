#Requires -Version 5.1
<#
.SYNOPSIS
  打开带皮肤的 Codex（日常入口）

.DESCRIPTION
  默认安静：不弹确认框 / 就绪气泡 / 失败 MessageBox。
  模块依赖：
  - lib/launcher-ui.ps1（或开发仓 packages/core-win/launcher-ui.ps1）
  - runtime scripts: common-windows.ps1 / theme-windows.ps1 / injector.mjs

.PARAMETER Port
  CDP 端口，默认 9335。
.PARAMETER RestartExisting
  强制重启已运行的裸 Codex。
.PARAMETER NoPrompt
  兼容旧参数：强制安静（现已是默认）。
.PARAMETER ShowPrompt
  允许确认框与失败弹窗。
.PARAMETER ShowReady
  成功时显示就绪气泡。
#>
[CmdletBinding()]
param(
  [ValidateRange(1024, 65535)][int]$Port = 9335,
  [switch]$RestartExisting,
  [switch]$NoPrompt,
  [switch]$ShowPrompt,
  [switch]$ShowReady
)

$ErrorActionPreference = 'Stop'
$programRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$stateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
$currentPath = Join-Path $programRoot 'current.json'
$logPath = Join-Path $stateRoot 'open-codex-dream-skin.log'

# --- 加载共享 UI/路径库（安装态 lib/ 优先，开发仓 packages/core-win 回退）---
$launcherUiCandidates = @(
  (Join-Path $programRoot 'lib\launcher-ui.ps1'),
  (Join-Path $PSScriptRoot '..\..\packages\core-win\launcher-ui.ps1'),
  (Join-Path $PSScriptRoot 'launcher-ui.ps1')
)
$launcherUi = $launcherUiCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $launcherUi) {
  throw 'launcher-ui.ps1 missing. Expected programRoot\lib\launcher-ui.ps1'
}
. $launcherUi

[void](Initialize-CodexSkinQuietUi -ShowPrompt:$ShowPrompt -NoPrompt:$NoPrompt)

# 薄包装：把共享库日志写到 open 专用 log
function Write-OpenLog([string]$Message) {
  Write-CodexSkinLog -Message $Message -LogPath $logPath
}
function Show-OpenUi {
  param(
    [Parameter(Mandatory = $true)][string]$Message,
    [ValidateSet('Info', 'Error', 'Question')][string]$Kind = 'Info'
  )
  return Show-CodexSkinMessageBox -Message $Message -Kind $Kind -Title 'Codex Skin'
}
function Ensure-DreamSkinTrayLocal([int]$TrayPort = 9335) {
  return Ensure-CodexSkinTray -Port $TrayPort -ProgramRoot $programRoot
}
function Focus-CodexWindowLocal($Codex) {
  $eq = $null
  if (Get-Command Test-DreamSkinPathEqual -ErrorAction SilentlyContinue) {
    $eq = { param($a, $b) Test-DreamSkinPathEqual -Left $a -Right $b }
  }
  return Focus-CodexSkinWindow -Codex $Codex -PathEqual $eq
}

function Wait-CodexShell {
  param(
    [Parameter(Mandatory = $true)][string]$NodePath,
    [Parameter(Mandatory = $true)][int]$WaitPort
  )
  $waitScript = Join-Path $stateRoot 'wait-shell.mjs'
  if (-not (Test-Path -LiteralPath $waitScript -PathType Leaf)) {
    throw "Missing shell waiter: $waitScript"
  }
  Write-CodexSkinOpenStatus -Phase 'shell-wait' -Detail 'waiting for Codex shell' -Code 'shell-wait' -Ok $true
  $swWait = [System.Diagnostics.Stopwatch]::StartNew()
  $lastBalloon = [datetime]::MinValue
  & $NodePath $waitScript $WaitPort | ForEach-Object {
    Write-OpenLog $_
    if ($swWait.Elapsed.TotalSeconds -ge 5 -and ((Get-Date) - $lastBalloon).TotalSeconds -ge 8) {
      Show-CodexSkinUserFeedback -Code 'shell-wait' | Out-Null
      $lastBalloon = Get-Date
    }
    Write-CodexSkinOpenStatus -Phase 'shell-wait' -Detail ([string]$_) -Code 'shell-wait' -Ok $true -ElapsedMs ([int]$swWait.ElapsedMilliseconds)
  }
  if ($LASTEXITCODE -ne 0) {
    throw 'Codex shell did not become ready for Dream Skin injection.'
  }
}

try {
  Write-CodexSkinOpenStatus -Phase 'start' -Detail 'open launcher' -Code 'start' -Ok $true
  $runtimeInfo = Resolve-CodexSkinRuntimeRoot -ProgramRoot $programRoot
  $runtimeRoot = $runtimeInfo.RuntimeRoot
  $scriptRoot = $runtimeInfo.ScriptsRoot
  $commonScript = Join-Path $scriptRoot 'common-windows.ps1'
  $themeScript = Join-Path $scriptRoot 'theme-windows.ps1'
  $injector = Join-Path $scriptRoot 'injector.mjs'
  foreach ($path in @($commonScript, $themeScript, $injector)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      throw "Dream Skin runtime file is missing: $path"
    }
  }
  . $commonScript
  . $themeScript

  # 超快路径：控制面已健康
  if (Get-Command Invoke-CodexSkinControl -ErrorAction SilentlyContinue) {
    $cp = Invoke-CodexSkinControl -Action 'open-healthy' -TimeoutMs 200
    if ($null -ne $cp -and $cp.ok) {
      Write-OpenLog ("control-plane hit open-healthy focused=" + [bool]$cp.focused + " port=" + $cp.port)
      Write-CodexSkinOpenStatus -Phase 'control-hit' -Detail 'open-healthy' -Code 'ok' -Ok $true
      [void](Try-CodexSkinAppActivate)
      if (-not [bool]$cp.focused) {
        Show-CodexSkinUserFeedback -Code 'focus-miss' | Out-Null
      }
      Show-CodexSkinFirstRunGuide -StateRoot $stateRoot | Out-Null
      exit 0
    }
  }

  Assert-DreamSkinPort -Port $Port
  $node = Get-DreamSkinNodeRuntime
  $codex = Get-DreamSkinCodexInstall
  $statePath = Join-Path $stateRoot 'state.json'
  $stdoutPath = Join-Path $stateRoot 'injector.log'
  $stderrPath = Join-Path $stateRoot 'injector-error.log'
  $verifyPath = Join-Path $stateRoot 'verify.log'

  $existingCdp = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $codex
  $running = @(Get-DreamSkinCodexProcesses -Codex $codex)
  $oldState = $null
  try { $oldState = Read-DreamSkinState -Path $statePath } catch {}

  # 快路径：CDP + injector 已健康 → 只聚焦（托盘已在则跳过 spawn）
  if (
    $null -ne $existingCdp -and
    $null -ne $oldState -and
    $oldState.browserId -ceq $existingCdp.BrowserId -and
    (Test-DreamSkinInjectorAlive -State $oldState)
  ) {
    Write-OpenLog "Healthy session (browserId=$($existingCdp.BrowserId), injector=$($oldState.injectorPid)); focusing."
    Write-CodexSkinOpenStatus -Phase 'healthy-focus' -Detail 'session healthy' -Code 'ok' -Ok $true
    $focused = $false
    if (Get-Command Invoke-CodexSkinControl -ErrorAction SilentlyContinue) {
      $cpFocus = Invoke-CodexSkinControl -Action 'focus' -TimeoutMs 600
      if ($null -ne $cpFocus -and $cpFocus.focused) {
        Write-OpenLog ('control-plane focus ok ms=' + $cpFocus.ms)
        $focused = $true
      }
    }
    if (-not $focused) {
      $focused = [bool](Focus-CodexWindowLocal -Codex $codex)
    }
    if (-not $focused) {
      [void](Try-CodexSkinAppActivate)
      Show-CodexSkinUserFeedback -Code 'focus-miss' | Out-Null
    }
    if (Get-Command Test-CodexSkinTrayAlive -ErrorAction SilentlyContinue) {
      if (-not (Test-CodexSkinTrayAlive)) {
        [void](Ensure-DreamSkinTrayLocal -TrayPort $Port)
      } else {
        Write-OpenLog 'Healthy path: tray already running, skip ensure'
      }
    } else {
      [void](Ensure-DreamSkinTrayLocal -TrayPort $Port)
    }
    Show-CodexSkinFirstRunGuide -StateRoot $stateRoot | Out-Null
    exit 0
  }

  $paths = Initialize-DreamSkinThemeStore -SkillRoot $runtimeRoot -StateRoot $stateRoot

  # 裸 Codex（无 CDP）：默认安静自动重启接管；显式反馈原因
  if ($running.Count -gt 0 -and $null -eq $existingCdp) {
    Write-CodexSkinOpenStatus -Phase 'bare-codex' -Detail 'process without CDP' -Code 'bare-codex' -Ok $false
    $shouldRestart = [bool]$RestartExisting -or $script:QuietUi
    if (-not $shouldRestart) {
      $msg = @(
        '当前 Codex 已打开，但没有启用皮肤。',
        '',
        '是否关闭并重启 Codex 以启用皮肤？',
        '未发送的草稿可能会丢失；已完成的对话记录不受影响。'
      ) -join [Environment]::NewLine
      if (Get-Command Confirm-DreamSkinRestart -ErrorAction SilentlyContinue) {
        $shouldRestart = [bool](Confirm-DreamSkinRestart -Message $msg)
      } else {
        $answer = Show-OpenUi -Kind Question -Message $msg
        $shouldRestart = ($answer -eq [System.Windows.Forms.DialogResult]::Yes)
      }
    } else {
      # Quiet auto path: still tell the user why restart is happening (throttled)
      Show-CodexSkinUserFeedback -Code 'bare-codex' | Out-Null
    }
    if (-not $shouldRestart) {
      Write-OpenLog 'Bare Codex open; user declined restart.'
      exit 0
    }
    Write-OpenLog 'Stopping bare Codex to enable skin.'
    Stop-DreamSkinCodex -Codex $codex -AllowForce
    Start-Sleep -Seconds 2
  }

  $cdp = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $codex
  if ($null -eq $cdp) {
    function Start-CodexWithCdpOnce {
      if (-not (Test-DreamSkinPortAvailable -Port $Port)) {
        throw "Port $Port is not available."
      }
      Write-OpenLog "Launching Codex with CDP on port $Port."
      Write-CodexSkinOpenStatus -Phase 'launch-cdp' -Detail ("port=" + $Port) -Code 'launch' -Ok $true
      Start-Process -FilePath $codex.Executable -ArgumentList @(
        '--remote-debugging-address=127.0.0.1',
        "--remote-debugging-port=$Port"
      ) | Out-Null
      $local = $null
      $deadline = (Get-Date).AddSeconds(60)
      while ((Get-Date) -lt $deadline -and $null -eq $local) {
        $local = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $codex
        if ($null -eq $local) { Start-Sleep -Milliseconds 400 }
      }
      return $local
    }

    $cdp = Start-CodexWithCdpOnce
    if ($null -eq $cdp) {
      Write-OpenLog 'CDP not exposed within 60s; force-stop and retry once.'
      try { Stop-DreamSkinCodex -Codex $codex -AllowForce } catch { Write-OpenLog ('retry stop: ' + $_.Exception.Message) }
      Start-Sleep -Seconds 2
      $cdp = Start-CodexWithCdpOnce
    }
    if ($null -eq $cdp) {
      Show-CodexSkinUserFeedback -Code 'cdp-closed' | Out-Null
      throw "Codex did not expose CDP on port $Port. Use 'Codex 皮肤修复' or close Codex and retry."
    }
  }

  Wait-CodexShell -NodePath $node.Path -WaitPort $Port
  Set-DreamSkinPaused -Paused $false -StateRoot $stateRoot | Out-Null
  Write-CodexSkinOpenStatus -Phase 'inject-start' -Detail 'starting watch injector' -Code 'inject' -Ok $true

  if ($oldState) {
    try { [void](Stop-DreamSkinRecordedInjector -State $oldState) }
    catch { Write-OpenLog ('Old injector stop skipped: ' + $_.Exception.Message) }
  }

  '' | Set-Content -LiteralPath $stdoutPath -Encoding utf8
  '' | Set-Content -LiteralPath $stderrPath -Encoding utf8
  $daemon = Start-Process -FilePath $node.Path -ArgumentList @(
    $injector,
    '--watch',
    '--port', "$Port",
    '--browser-id', $cdp.BrowserId,
    '--theme-dir', $paths.Active,
    '--pause-file', $paths.PauseFile
  ) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
  Start-Sleep -Seconds 3
  if ($daemon.HasExited) {
    throw "Dream Skin injector exited during startup. See $stderrPath"
  }

  $injectorStartedAt = Get-DreamSkinProcessStartedAt -ProcessId $daemon.Id
  $prevState = $null
  try { if (Test-Path -LiteralPath $statePath) { $prevState = Read-DreamSkinState -Path $statePath } } catch {}
  $state = New-CodexSkinRuntimeState `
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
    -PreviousState $prevState
  Write-CodexSkinRuntimeState -StatePath $statePath -State $state
  Write-OpenLog ("state normalized runtimeId=" + $runtimeInfo.RuntimeId + " injector=" + $runtimeInfo.InjectorPath + " controlPort=" + $state.controlPort)

  $verify = Invoke-DreamSkinNative -FilePath $node.Path -ArgumentList @(
    $injector, '--verify', '--port', "$Port",
    '--browser-id', $cdp.BrowserId, '--timeout-ms', '45000'
  )
  Write-DreamSkinUtf8FileAtomically -Path $verifyPath -Content (($verify.Output -join "`r`n") + "`r`n")
  if ($verify.ExitCode -ne 0) {
    throw "Dream Skin verification failed. See $verifyPath"
  }

  Write-OpenLog "Dream Skin opened on port $Port with injector $($daemon.Id)."
  Write-CodexSkinOpenStatus -Phase 'ready' -Detail ("injector=" + $daemon.Id) -Code 'ok' -Ok $true
  [void](Ensure-DreamSkinTrayLocal -TrayPort $Port)
  $focused = [bool](Focus-CodexWindowLocal -Codex $codex)
  if (-not $focused) {
    [void](Try-CodexSkinAppActivate)
    Show-CodexSkinUserFeedback -Code 'focus-miss' | Out-Null
  }
  Show-CodexSkinFirstRunGuide -StateRoot $stateRoot | Out-Null
  if ($ShowReady) { Show-CodexSkinReadyBalloon -StateRoot $stateRoot }
  # Best-effort async thumbs at most once per 6 hours (avoid open-path CPU storms).
  try {
    $stamp = Join-Path $stateRoot 'thumbs-last-run.txt'
    $run = $true
    if (Test-Path -LiteralPath $stamp) {
      try {
        $last = [datetime]::Parse((Get-Content -LiteralPath $stamp -Raw).Trim())
        if (((Get-Date) - $last).TotalHours -lt 6) { $run = $false }
      } catch {}
    }
    if ($run) {
      $candidates = @(
        (Join-Path $programRoot 'generate-theme-thumbs.ps1'),
        (Join-Path $PSScriptRoot '..\..\scripts\windows\generate-theme-thumbs.ps1')
      )
      $thumbGen = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
      if ($thumbGen) {
        Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
          '-NoProfile','-ExecutionPolicy','Bypass','-File',$thumbGen
        ) | Out-Null
        [System.IO.File]::WriteAllText($stamp, (Get-Date).ToString('o'), [Text.UTF8Encoding]::new($false))
      }
    }
  } catch {}
  exit 0
} catch {
  Write-OpenLog ('failed: ' + $_.Exception.Message)
  $code = 'error'
  $msg = $_.Exception.Message
  if ($msg -match 'CDP|debugging|port') { $code = 'cdp-closed' }
  elseif ($msg -match 'shell') { $code = 'shell-wait' }
  elseif ($msg -match 'injector') { $code = 'injector-dead' }
  try { Show-CodexSkinUserFeedback -Code $code -Detail $msg | Out-Null } catch {}
  Write-CodexSkinOpenStatus -Phase 'failed' -Detail $msg -Code $code -Ok $false
  if (-not $script:QuietUi) {
    try {
      [void](Show-OpenUi -Kind Error -Message ("启动失败：`n" + $msg + "`n可点「Codex 皮肤修复」或「Codex 换肤」。"))
    } catch {}
  }
  exit 1
}
