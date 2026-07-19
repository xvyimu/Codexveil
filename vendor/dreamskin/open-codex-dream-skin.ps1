[CmdletBinding()]
param(
  [ValidateRange(1024, 65535)][int]$Port = 9335,
  [switch]$RestartExisting,
  [switch]$NoPrompt
)

$ErrorActionPreference = 'Stop'
$programRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$stateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
$currentPath = Join-Path $programRoot 'current.json'
$logPath = Join-Path $stateRoot 'open-codex-dream-skin.log'

function Read-JsonUtf8 {
  param([Parameter(Mandatory = $true)][string]$Path)
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $encoding = [System.Text.UTF8Encoding]::new($false, $true)
  return $encoding.GetString($bytes) | ConvertFrom-Json -ErrorAction Stop
}

function Write-OpenLog {
  param([Parameter(Mandatory = $true)][string]$Message)
  [System.IO.Directory]::CreateDirectory($stateRoot) | Out-Null
  [System.IO.File]::AppendAllText(
    $logPath,
    ('{0:u} {1}' -f (Get-Date), $Message) + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Show-OpenUi {
  param(
    [Parameter(Mandatory = $true)][string]$Message,
    [string]$Title = 'Codex Dream Skin',
    [ValidateSet('Info', 'Error', 'Question')][string]$Kind = 'Info'
  )
  Add-Type -AssemblyName System.Windows.Forms | Out-Null
  $icon = switch ($Kind) {
    'Error' { [System.Windows.Forms.MessageBoxIcon]::Error }
    'Question' { [System.Windows.Forms.MessageBoxIcon]::Question }
    default { [System.Windows.Forms.MessageBoxIcon]::Information }
  }
  $buttons = if ($Kind -eq 'Question') {
    [System.Windows.Forms.MessageBoxButtons]::YesNo
  } else {
    [System.Windows.Forms.MessageBoxButtons]::OK
  }
  return [System.Windows.Forms.MessageBox]::Show($Message, $Title, $buttons, $icon)
}

function Show-Balloon {
  param([Parameter(Mandatory = $true)][string]$Message, [string]$Title = 'Codex Dream Skin')
  try {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    Add-Type -AssemblyName System.Drawing | Out-Null
    $n = [System.Windows.Forms.NotifyIcon]::new()
    $n.Icon = [System.Drawing.SystemIcons]::Information
    $n.Visible = $true
    $n.BalloonTipTitle = $Title
    $n.BalloonTipText = $Message
    $n.ShowBalloonTip(1800)
    Start-Sleep -Milliseconds 200
    $n.Visible = $false
    $n.Dispose()
  } catch {}
}

function Ensure-FocusType {
  if ("DreamSkin.WinFocus" -as [type]) { return }
  $code = @'
using System;
using System.Runtime.InteropServices;
namespace DreamSkin {
  public static class WinFocus {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
  }
}
'@
  Add-Type -TypeDefinition $code -Language CSharp -ErrorAction Stop
}

function Focus-CodexWindow {
  param([Parameter(Mandatory = $true)][object]$Codex)
  try {
    Ensure-FocusType
    $candidates = @(Get-Process -Name ChatGPT -ErrorAction SilentlyContinue |
      Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
      Sort-Object StartTime -Descending)
    foreach ($proc in $candidates) {
      try {
        $path = $proc.Path
        if ($path -and -not (Test-DreamSkinPathEqual -Left $path -Right $Codex.Executable)) { continue }
      } catch {}
      $hwnd = $proc.MainWindowHandle
      if ([DreamSkin.WinFocus]::IsIconic($hwnd)) {
        [void][DreamSkin.WinFocus]::ShowWindow($hwnd, 9)
      }
      [void][DreamSkin.WinFocus]::SetForegroundWindow($hwnd)
      Write-OpenLog ("Focused Codex window pid=" + $proc.Id)
      return $true
    }
  } catch {
    Write-OpenLog ('Focus Codex skipped: ' + $_.Exception.Message)
  }
  return $false
}

function Wait-CodexShell {
  param(
    [Parameter(Mandatory = $true)][string]$NodePath,
    [Parameter(Mandatory = $true)][int]$Port
  )
  $waitScript = Join-Path $stateRoot 'wait-shell.mjs'
  if (-not (Test-Path -LiteralPath $waitScript -PathType Leaf)) {
    throw "Missing shell waiter: $waitScript"
  }
  & $NodePath $waitScript $Port | ForEach-Object { Write-OpenLog $_ }
  if ($LASTEXITCODE -ne 0) {
    throw 'Codex shell did not become ready for Dream Skin injection.'
  }
}



try {
  $current = Read-JsonUtf8 -Path $currentPath
  if ($current.schemaVersion -ne 1 -or -not $current.runtimeId) {
    throw 'Dream Skin current runtime pointer is invalid.'
  }
  $runtimeRoot = Join-Path $programRoot ($current.relativeEnginePath -replace '/', '\')
  $scriptRoot = Join-Path $runtimeRoot 'scripts'
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

  # Fast path: matching CDP + live injector => focus only (no theme-store / verify).
  if ($null -ne $existingCdp -and $null -ne $oldState -and $oldState.browserId -ceq $existingCdp.BrowserId -and (Test-DreamSkinInjectorAlive -State $oldState)) {
    Write-OpenLog "Healthy Dream Skin session already running (browserId=$($existingCdp.BrowserId), injector=$($oldState.injectorPid)); focusing."
    [void](Focus-CodexWindow -Codex $codex)
    exit 0
  }
  $paths = Initialize-DreamSkinThemeStore -SkillRoot $runtimeRoot -StateRoot $stateRoot

  if ($running.Count -gt 0 -and $null -eq $existingCdp) {
    $shouldRestart = [bool]$RestartExisting
    if (-not $shouldRestart -and -not $NoPrompt) {
      $msg = @(
        '当前 Codex 已打开，但没有启用 Dream Skin。',
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
    }
    if (-not $shouldRestart) {
      Write-OpenLog 'Bare Codex is open; user declined restart. Left unchanged.'
      if (-not $NoPrompt) {
        [void](Show-OpenUi -Kind Info -Message ("已取消。`n请先关闭现有 Codex，再点任务栏 Codex 图标。"))
      }
      exit 0
    }
    Write-OpenLog 'Stopping bare Codex after user confirmation.'
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
      Write-OpenLog 'CDP not exposed within 60s; force-stopping residual Codex and retrying once.'
      try { Stop-DreamSkinCodex -Codex $codex -AllowForce } catch { Write-OpenLog ('retry stop: ' + $_.Exception.Message) }
      Start-Sleep -Seconds 2
      $cdp = Start-CodexWithCdpOnce
    }
    if ($null -eq $cdp) {
      throw "Codex did not expose CDP on port $Port. Please click 'Codex 皮肤修复' or close Codex and try again."
    }
  }

  Wait-CodexShell -NodePath $node.Path -Port $Port
  Set-DreamSkinPaused -Paused $false -StateRoot $stateRoot | Out-Null

  if ($oldState) {
    try {
      [void](Stop-DreamSkinRecordedInjector -State $oldState)
    } catch {
      Write-OpenLog ('Old injector stop skipped: ' + $_.Exception.Message)
    }
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
  $state = [pscustomobject]@{
    schemaVersion = 3
    platform = 'windows'
    port = $Port
    injectorPid = $daemon.Id
    injectorStartedAt = $injectorStartedAt
    injectorPath = $injector
    nodePath = $node.Path
    nodeVersion = $node.Version
    codexExe = $codex.Executable
    codexPackageRoot = $codex.PackageRoot
    codexPackageFullName = $codex.PackageFullName
    codexPackageFamilyName = $codex.PackageFamilyName
    codexVersion = $codex.Version
    browserId = $cdp.BrowserId
    profilePath = ''
    themeDir = $paths.Active
    pauseFile = $paths.PauseFile
    createdAt = (Get-Date).ToUniversalTime().ToString('o')
  }
  Write-DreamSkinState -Path $statePath -State $state

  $verify = Invoke-DreamSkinNative -FilePath $node.Path -ArgumentList @(
    $injector, '--verify', '--port', "$Port",
    '--browser-id', $cdp.BrowserId, '--timeout-ms', '45000'
  )
  Write-DreamSkinUtf8FileAtomically -Path $verifyPath -Content (($verify.Output -join "`r`n") + "`r`n")
  if ($verify.ExitCode -ne 0) {
    throw "Dream Skin verification failed. See $verifyPath"
  }
  Write-OpenLog "Dream Skin opened on port $Port with injector $($daemon.Id)."
  [void](Focus-CodexWindow -Codex $codex)
  if (-not $NoPrompt) { Show-Balloon -Message '皮肤已就绪' }
  exit 0
} catch {
  Write-OpenLog ('failed: ' + $_.Exception.Message)
  try {
    [void](Show-OpenUi -Kind Error -Message ("启动失败：`n" + $_.Exception.Message))
  } catch {}
  exit 1
}
