#Requires -Version 5.1
<#
.SYNOPSIS
  Codex Skin 启动器共享库（安静 UI / 托盘 / 焦点 / 路径）

.DESCRIPTION
  供 open-codex-dream-skin.ps1、check-and-fix.ps1、switch-theme-ui.ps1 复用。
  约定：
  - 日常默认安静：不弹 MessageBox / 就绪气泡
  - 安装根：%LOCALAPPDATA%\Programs\CodexDreamSkin
  - 数据根：%LOCALAPPDATA%\CodexDreamSkin

  使用方式：
    . (Join-Path $PSScriptRoot '..\..\packages\core-win\launcher-ui.ps1')  # 开发仓
    或安装态把本文件复制到 programRoot 后：
    . (Join-Path $programRoot 'lib\launcher-ui.ps1')
#>

if (Get-Variable -Name CodexSkinLauncherUiLoaded -Scope Script -ErrorAction SilentlyContinue) {
  return
}
$script:CodexSkinLauncherUiLoaded = $true

function Initialize-CodexSkinConsoleUtf8 {
  <#
  .SYNOPSIS
    Make host console print Chinese without GBK mojibake (PAIN-POINTS #22).
  .DESCRIPTION
    Windows PowerShell 5.1 defaults to system ANSI/GBK for console I/O. This
    switches both input and output encodings to UTF-8 (code page 65001) and
    aligns $OutputEncoding so native tools piping into PS also see UTF-8.
    Safe no-op when there is no interactive console (hidden launchers).
  #>
  param([switch]$Force)
  if (-not $Force -and $script:CodexSkinConsoleUtf8Ready) { return $true }
  try {
    # code page 65001 = UTF-8. chcp output is discarded (locale noise).
    try { & chcp.com 65001 | Out-Null } catch {}
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    try { [Console]::OutputEncoding = $utf8 } catch {}
    try { [Console]::InputEncoding = $utf8 } catch {}
    $global:OutputEncoding = $utf8
    # PS 7 already defaults to UTF-8; still set for consistency.
    try {
      if ($PSVersionTable.PSVersion.Major -ge 6) {
        $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
        $PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'
        $PSDefaultParameterValues['Add-Content:Encoding'] = 'utf8'
      }
    } catch {}
    $script:CodexSkinConsoleUtf8Ready = $true
    return $true
  } catch {
    return $false
  }
}

# Best-effort at import time so any host that dotsources this lib gets UTF-8.
[void](Initialize-CodexSkinConsoleUtf8)

function Get-CodexSkinProgramRoot {
  param([string]$Hint)
  if ($Hint -and (Test-Path -LiteralPath $Hint)) {
    return [System.IO.Path]::GetFullPath($Hint)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs\CodexDreamSkin'))
}

function Get-CodexSkinStateRoot {
  return [System.IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'))
}

function Initialize-CodexSkinQuietUi {
  <#
  .SYNOPSIS
    根据开关设置 $script:QuietUi。
  .PARAMETER ShowPrompt
    显式允许确认/错误 MessageBox。
  .PARAMETER NoPrompt
    兼容旧参数：强制安静。
  #>
  param(
    [switch]$ShowPrompt,
    [switch]$NoPrompt
  )
  $script:QuietUi = -not [bool]$ShowPrompt
  if ($NoPrompt) { $script:QuietUi = $true }
  return $script:QuietUi
}

function Read-CodexSkinJsonUtf8 {
  param([Parameter(Mandatory = $true)][string]$Path)
  # 无 BOM / 有 BOM 均可；拒绝用默认 ANSI 读中文 theme.json
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $encoding = [System.Text.UTF8Encoding]::new($false, $true)
  return $encoding.GetString($bytes) | ConvertFrom-Json -ErrorAction Stop
}

function Write-CodexSkinJsonUtf8NoBom {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)]$Object
  )
  $json = ($Object | ConvertTo-Json -Depth 8) + "`n"
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Write-CodexSkinLog {
  param(
    [Parameter(Mandatory = $true)][string]$Message,
    [string]$LogPath = (Join-Path (Get-CodexSkinStateRoot) 'open-codex-dream-skin.log')
  )
  $stateRoot = Split-Path -Parent $LogPath
  [System.IO.Directory]::CreateDirectory($stateRoot) | Out-Null
  [System.IO.File]::AppendAllText(
    $LogPath,
    ('{0:u} {1}' -f (Get-Date), $Message) + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Show-CodexSkinMessageBox {
  param(
    [Parameter(Mandatory = $true)][string]$Message,
    [string]$Title = 'Codex Skin',
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

function Get-CodexSkinUiPrefsPath {
  param([string]$StateRoot = (Get-CodexSkinStateRoot))
  return (Join-Path $StateRoot 'ui-prefs.json')
}

function Get-CodexSkinUiPrefs {
  <#
  .SYNOPSIS
    Read user UX prefs (apply balloon on/off). Missing file → defaults.
  #>
  param([string]$StateRoot = (Get-CodexSkinStateRoot))
  $defaults = [ordered]@{
    schemaVersion = 1
    applyBalloonEnabled = $true
    # borderless = heige 无描边；card = 圆角卡片描边
    bubbleStyle = 'borderless'
  }
  $path = Get-CodexSkinUiPrefsPath -StateRoot $StateRoot
  try {
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      $raw = Read-CodexSkinJsonUtf8 -Path $path
      if ($null -ne $raw) {
        if ($null -ne $raw.applyBalloonEnabled) {
          $defaults.applyBalloonEnabled = [bool]$raw.applyBalloonEnabled
        }
        if ($null -ne $raw.schemaVersion) {
          $defaults.schemaVersion = [int]$raw.schemaVersion
        }
        if ($raw.bubbleStyle -is [string]) {
          $bs = $raw.bubbleStyle.Trim().ToLowerInvariant()
          if ($bs -eq 'card' -or $bs -eq 'borderless') {
            $defaults.bubbleStyle = $bs
          }
        }
      }
    }
  } catch {}
  return [pscustomobject]$defaults
}

function Set-CodexSkinUiPrefs {
  <#
  .SYNOPSIS
    Merge and write ui-prefs.json (stateRoot). Non-blocking on failure.
  #>
  param(
    [string]$StateRoot = (Get-CodexSkinStateRoot),
    [Nullable[bool]]$ApplyBalloonEnabled = $null,
    [ValidateSet('borderless', 'card', '')][string]$BubbleStyle = ''
  )
  try {
    $cur = Get-CodexSkinUiPrefs -StateRoot $StateRoot
    $bubble = if ($BubbleStyle -and $BubbleStyle.Trim()) {
      $BubbleStyle.Trim().ToLowerInvariant()
    } else {
      [string]$cur.bubbleStyle
    }
    if ($bubble -ne 'card') { $bubble = 'borderless' }
    $obj = [ordered]@{
      schemaVersion = 1
      applyBalloonEnabled = $(if ($null -ne $ApplyBalloonEnabled) { [bool]$ApplyBalloonEnabled } else { [bool]$cur.applyBalloonEnabled })
      bubbleStyle = $bubble
      updatedAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    Write-CodexSkinJsonUtf8NoBom -Path (Get-CodexSkinUiPrefsPath -StateRoot $StateRoot) -Object $obj
    return [pscustomobject]$obj
  } catch {
    return $null
  }
}

function Get-CodexSkinBubbleStyle {
  param([string]$StateRoot = (Get-CodexSkinStateRoot))
  try {
    $s = [string]((Get-CodexSkinUiPrefs -StateRoot $StateRoot).bubbleStyle)
    if ($s -eq 'card') { return 'card' }
  } catch {}
  return 'borderless'
}

function Test-CodexSkinApplyBalloonEnabled {
  param([string]$StateRoot = (Get-CodexSkinStateRoot))
  try {
    return [bool]((Get-CodexSkinUiPrefs -StateRoot $StateRoot).applyBalloonEnabled)
  } catch {
    return $true
  }
}

function Show-CodexSkinBalloon {
  param(
    [Parameter(Mandatory = $true)][string]$Message,
    [string]$Title = 'Codex Skin',
    [int]$Ms = 2200,
    [string]$ThrottleKey = '',
    [int]$ThrottleSeconds = 60,
    # Success = respect ui-prefs applyBalloonEnabled (U3 可关); Error/Info always attempt.
    [ValidateSet('Success', 'Error', 'Info')][string]$Kind = 'Info',
    [switch]$Force
  )
  if (-not $Force -and $Kind -eq 'Success' -and -not (Test-CodexSkinApplyBalloonEnabled)) {
    return
  }
  # Same-cause throttle: avoid balloon spam on repeated taskbar clicks.
  if ($ThrottleKey) {
    try {
      $stampPath = Join-Path (Get-CodexSkinStateRoot) ('balloon-throttle-' + ($ThrottleKey -replace '[^\w\-]', '_') + '.txt')
      if (Test-Path -LiteralPath $stampPath) {
        $last = [datetime]::Parse([System.IO.File]::ReadAllText($stampPath).Trim())
        if (((Get-Date) - $last).TotalSeconds -lt $ThrottleSeconds) { return }
      }
      [System.IO.File]::WriteAllText($stampPath, (Get-Date).ToString('o'), [System.Text.UTF8Encoding]::new($false))
    } catch {}
  }
  try {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    Add-Type -AssemblyName System.Drawing | Out-Null
    $n = [System.Windows.Forms.NotifyIcon]::new()
    $n.Icon = [System.Drawing.SystemIcons]::Information
    $n.Visible = $true
    $n.BalloonTipTitle = $Title
    $n.BalloonTipText = $Message
    $n.ShowBalloonTip([Math]::Max(500, $Ms))
    Start-Sleep -Milliseconds 280
    $n.Visible = $false
    $n.Dispose()
  } catch {
    # 托盘气泡失败不影响主流程
  }
}

function Show-CodexSkinApplyFeedback {
  <#
  .SYNOPSIS
    U3: light success/fail balloon after theme apply/kick. Respects applyBalloonEnabled.
  #>
  param(
    [Parameter(Mandatory = $true)][string]$ThemeName,
    [bool]$Ok = $true,
    [string]$Detail = '',
    [string]$StateRoot = (Get-CodexSkinStateRoot),
    [int]$Ms = 1600
  )
  if (-not (Test-CodexSkinApplyBalloonEnabled -StateRoot $StateRoot)) { return $false }
  $name = if ($ThemeName) { $ThemeName.Trim() } else { '皮肤' }
  if ($Ok) {
    $msg = if ($Detail) { "已切换：$name`n$Detail" } else { "已切换：$name" }
    Show-CodexSkinBalloon -Message $msg -Title 'Codex 换肤' -Ms $Ms -ThrottleKey 'apply-ok' -ThrottleSeconds 1 -Kind Success
  } else {
    $msg = if ($Detail) { "已写入：$name · $Detail" } else { "已写入：$name · 注入未完成" }
    Show-CodexSkinBalloon -Message $msg -Title 'Codex 换肤' -Ms ([Math]::Max($Ms, 2200)) -ThrottleKey 'apply-fail' -ThrottleSeconds 2 -Kind Success
  }
  return $true
}

function Write-CodexSkinOpenStatus {
  param(
    [Parameter(Mandatory = $true)][string]$Phase,
    [string]$Detail = '',
    [string]$Code = '',
    [bool]$Ok = $true,
    [int]$ElapsedMs = 0
  )
  $obj = [ordered]@{
    phase = $Phase
    detail = $Detail
    code = $Code
    ok = $Ok
    elapsedMs = $ElapsedMs
    updatedAt = (Get-Date).ToUniversalTime().ToString('o')
  }
  try {
    Write-CodexSkinJsonUtf8NoBom -Path (Join-Path (Get-CodexSkinStateRoot) 'open-status.json') -Object $obj
  } catch {}
}

function Get-CodexSkinControlPort {
  param([string]$StateRoot = (Get-CodexSkinStateRoot))
  try {
    $portFile = Join-Path $StateRoot 'control.port'
    if (Test-Path -LiteralPath $portFile) {
      $n = 0
      if ([int]::TryParse((Get-Content -LiteralPath $portFile -Raw).Trim(), [ref]$n) -and $n -ge 1024) { return $n }
    }
    $statePath = Join-Path $StateRoot 'state.json'
    if (Test-Path -LiteralPath $statePath) {
      $st = Read-CodexSkinJsonUtf8 -Path $statePath
      if ($st.controlPort) {
        $n = [int]$st.controlPort
        if ($n -ge 1024) { return $n }
      }
    }
  } catch {}
  return 9336
}

function Get-CodexSkinControlToken {
  <#
  .SYNOPSIS
    Read loopback control-plane token (stateRoot\control.token). Empty if missing.
  #>
  param([string]$StateRoot = (Get-CodexSkinStateRoot))
  try {
    $tokenFile = Join-Path $StateRoot 'control.token'
    if (Test-Path -LiteralPath $tokenFile) {
      $t = (Get-Content -LiteralPath $tokenFile -Raw -ErrorAction Stop).Trim()
      if ($t) { return $t }
    }
  } catch {}
  return ''
}

function Resolve-CodexSkinUserError {
  <#
  .SYNOPSIS
    Map machine reason codes to user-facing Chinese + primary CTA.
  #>
  param(
    [Parameter(Mandatory = $true)][string]$Code,
    [string]$Detail = ''
  )
  $c = $Code.ToLowerInvariant()
  switch -Regex ($c) {
    'cdp-closed|no-cdp' {
      return [pscustomobject]@{
        Code = 'cdp-closed'
        Title = 'Codex 未开启皮肤调试端口'
        Message = '请用任务栏「Codex」快捷方式打开（不要用商店磁贴）。'
        Action = 'open-skinned'
      }
    }
    'bare-codex|bare' {
      return [pscustomobject]@{
        Code = 'bare-codex'
        Title = '当前是未带皮肤的 Codex'
        Message = '将关闭并重启以启用皮肤。未发送的草稿可能丢失。'
        Action = 'restart-skinned'
      }
    }
    'no-state|incomplete' {
      return [pscustomobject]@{
        Code = 'no-state'
        Title = '皮肤守护尚未初始化'
        Message = '请先点任务栏 Codex 完成首次启动。'
        Action = 'open-skinned'
      }
    }
    'injector-dead|injector-missing|injector' {
      return [pscustomobject]@{
        Code = 'injector-dead'
        Title = '皮肤守护未运行'
        Message = '点「一键修复」或重新打开任务栏 Codex。'
        Action = 'fix'
      }
    }
    'focus-miss|focus' {
      return [pscustomobject]@{
        Code = 'focus-miss'
        Title = '皮肤已就绪'
        Message = '窗口可能在后台。请点击任务栏 Codex 图标显示窗口。'
        Action = 'none'
      }
    }
    'control-miss|slow-path' {
      return [pscustomobject]@{
        Code = 'slow-path'
        Title = '正在启动皮肤模式'
        Message = '完整启动需要几秒，请稍候…'
        Action = 'wait'
      }
    }
    'shell-wait' {
      return [pscustomobject]@{
        Code = 'shell-wait'
        Title = '正在等待 Codex 界面'
        Message = '界面加载中，请稍候（通常 5–15 秒）。'
        Action = 'wait'
      }
    }
    'post-update' {
      return [pscustomobject]@{
        Code = 'post-update'
        Title = '更新检查完成'
        Message = '请继续使用任务栏「Codex」打开（不要用商店磁贴）。'
        Action = 'none'
      }
    }
    'bare-hint' {
      return [pscustomobject]@{
        Code = 'bare-hint'
        Title = '检测到未带皮肤的 Codex'
        Message = '托盘选择「用皮肤重启 Codex」。未发送草稿可能丢失。'
        Action = 'restart-skinned'
      }
    }
    default {
      return [pscustomobject]@{
        Code = $Code
        Title = 'Codex Skin'
        Message = $(if ($Detail) { $Detail } else { '操作未完成，可尝试一键修复。' })
        Action = 'fix'
      }
    }
  }
}

function Show-CodexSkinUserFeedback {
  param(
    [Parameter(Mandatory = $true)][string]$Code,
    [string]$Detail = '',
    [int]$Ms = 3200
  )
  $err = Resolve-CodexSkinUserError -Code $Code -Detail $Detail
  $text = $err.Title + [Environment]::NewLine + $err.Message
  Show-CodexSkinBalloon -Message $text -Title 'Codex Skin' -Ms $Ms -ThrottleKey $err.Code -ThrottleSeconds 45
  Write-CodexSkinOpenStatus -Phase 'user-feedback' -Detail $err.Message -Code $err.Code -Ok $false
  return $err
}

function Test-CodexSkinFirstRunPending {
  param([string]$StateRoot = (Get-CodexSkinStateRoot))
  $flag = Join-Path $StateRoot 'first-run-shown.flag'
  return -not (Test-Path -LiteralPath $flag)
}

function Set-CodexSkinFirstRunShown {
  param([string]$StateRoot = (Get-CodexSkinStateRoot))
  try {
    [System.IO.Directory]::CreateDirectory($StateRoot) | Out-Null
    [System.IO.File]::WriteAllText(
      (Join-Path $StateRoot 'first-run-shown.flag'),
      ((Get-Date).ToUniversalTime().ToString('o') + "`n"),
      [System.Text.UTF8Encoding]::new($false)
    )
  } catch {}
}

function Show-CodexSkinFirstRunGuide {
  param([string]$StateRoot = (Get-CodexSkinStateRoot))
  if (-not (Test-CodexSkinFirstRunPending -StateRoot $StateRoot)) { return $false }
  # U4: one-shot entry tip. Flag is written even if balloon fails so we never loop.
  $msg = @(
    '欢迎使用 Codex 皮肤',
    '1) 日常请点任务栏「Codex」',
    '   不要用微软商店磁贴（无皮肤，不是故障）',
    '2) 换肤：开始菜单「Codex 换肤」· 托盘 · F6',
    '3) 异常：托盘状态或「一键修复」'
  ) -join [Environment]::NewLine
  # Force: first-run is not gated by applyBalloonEnabled (that only covers apply success).
  Show-CodexSkinBalloon -Message $msg -Title 'Codex Skin' -Ms 6500 -ThrottleKey 'first-run' -ThrottleSeconds 3600 -Kind Info -Force
  Set-CodexSkinFirstRunShown -StateRoot $StateRoot
  Write-CodexSkinOpenStatus -Phase 'first-run' -Detail 'guide shown' -Code 'first-run' -Ok $true
  return $true
}

function Invoke-CodexSkinFlashWindow {
  param([IntPtr]$Hwnd)
  if ($Hwnd -eq [IntPtr]::Zero) { return $false }
  try {
    if (-not ('CodexSkin.FlashWin' -as [type])) {
      $code = @'
using System;
using System.Runtime.InteropServices;
namespace CodexSkin {
  public static class FlashWin {
    [StructLayout(LayoutKind.Sequential)]
    public struct FLASHWINFO {
      public uint cbSize; public IntPtr hwnd; public uint dwFlags; public uint uCount; public uint dwTimeout;
    }
    [DllImport("user32.dll")] public static extern bool FlashWindowEx(ref FLASHWINFO pwfi);
    public const uint FLASHW_ALL = 3; public const uint FLASHW_TIMERNOFG = 12;
    public static bool Flash(IntPtr h) {
      var f = new FLASHWINFO();
      f.cbSize = (uint)Marshal.SizeOf(f); f.hwnd = h; f.dwFlags = FLASHW_ALL | FLASHW_TIMERNOFG; f.uCount = 4; f.dwTimeout = 0;
      return FlashWindowEx(ref f);
    }
  }
}
'@
      Add-Type -TypeDefinition $code -Language CSharp -ErrorAction Stop
    }
    return [CodexSkin.FlashWin]::Flash($Hwnd)
  } catch {
    return $false
  }
}

function Try-CodexSkinAppActivate {
  # Best-effort title activate (works better when called from user click chain).
  try {
    $shell = New-Object -ComObject WScript.Shell
    foreach ($title in @('Codex', 'ChatGPT', 'OpenAI', 'OpenAI Codex', 'Codex Desktop')) {
      try {
        if ($shell.AppActivate($title)) { return $true }
      } catch {}
    }
    # Process main-window titles as last resort
    foreach ($name in @('ChatGPT', 'Codex')) {
      $procs = @(Get-Process -Name $name -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle })
      foreach ($p in $procs) {
        try {
          if ($shell.AppActivate($p.MainWindowTitle)) { return $true }
        } catch {}
      }
    }
  } catch {}
  return $false
}

function Get-CodexSkinActiveThemeLabel {
  param([string]$StateRoot = (Get-CodexSkinStateRoot))
  try {
    $themePath = Join-Path $StateRoot 'active-theme\theme.json'
    if (-not (Test-Path -LiteralPath $themePath)) { return '默认皮肤' }
    $theme = Get-Content -LiteralPath $themePath -Raw -Encoding utf8 | ConvertFrom-Json
    if ($theme.name) { return [string]$theme.name }
    if ($theme.id) { return [string]$theme.id }
  } catch {}
  return '皮肤'
}

function Test-CodexSkinTrayAlive {
  # Cheap check: avoid spawning powershell when tray already owns the mutex/process.
  try {
    $hits = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
      $_.CommandLine -and (
        $_.CommandLine -match 'tray-dream-skin\.ps1' -or
        $_.CommandLine -match 'launch-dream-skin\.ps1'
      )
    })
    return ($hits.Count -gt 0)
  } catch {
    return $false
  }
}

function Ensure-CodexSkinTray {
  <#
  .SYNOPSIS
    确保托盘进程在跑（内部 mutex 去重，可重复调用）。
  #>
  param(
    [int]$Port = 9335,
    [string]$ProgramRoot = (Get-CodexSkinProgramRoot),
    [switch]$Force
  )
  try {
    if (-not $Force -and (Test-CodexSkinTrayAlive)) {
      Write-CodexSkinLog 'Ensure tray skipped: tray already running'
      return $true
    }
    $launch = Join-Path $ProgramRoot 'launch-dream-skin.ps1'
    if (-not (Test-Path -LiteralPath $launch -PathType Leaf)) {
      Write-CodexSkinLog 'Ensure tray skipped: launch-dream-skin.ps1 missing'
      return $false
    }
    Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
      '-NoProfile', '-STA', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'RemoteSigned',
      '-File', $launch, '-Port', "$Port"
    ) | Out-Null
    Write-CodexSkinLog 'Ensured tray process.'
    return $true
  } catch {
    Write-CodexSkinLog ('Ensure tray skipped: ' + $_.Exception.Message)
    return $false
  }
}

function Show-CodexSkinReadyBalloon {
  param([string]$StateRoot = (Get-CodexSkinStateRoot))
  $name = Get-CodexSkinActiveThemeLabel -StateRoot $StateRoot
  Show-CodexSkinBalloon -Message ("已就绪：$name`nF6 切换 · 托盘可管理 · 图形换肤见开始菜单")
}

function Ensure-CodexSkinFocusType {
  # Versioned type name: PS cannot unload Add-Type assemblies.
  if ('CodexSkin.WinFocus6' -as [type]) { return }
  $code = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
namespace CodexSkin {
  public static class WinFocus6 {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool AllowSetForegroundWindow(int dwProcessId);

    public class Hit {
      public IntPtr Hwnd;
      public uint Pid;
      public string ClassName;
      public string Title;
      public int Score;
    }

    public static List<Hit> FindWindows(HashSet<uint> pids) {
      var hits = new List<Hit>();
      EnumWindows((hWnd, l) => {
        // IMPORTANT: do NOT require IsWindowVisible — Electron may report false while cloaked/minimized.
        uint pid;
        GetWindowThreadProcessId(hWnd, out pid);
        if (!pids.Contains(pid)) return true;
        var sb = new StringBuilder(256);
        GetClassName(hWnd, sb, sb.Capacity);
        var cls = sb.ToString() ?? "";
        int textLen = GetWindowTextLength(hWnd);
        var tb = new StringBuilder(Math.Max(1, textLen + 1));
        if (textLen > 0) GetWindowText(hWnd, tb, tb.Capacity);
        var title = tb.ToString() ?? "";
        bool chrome = cls.IndexOf("Chrome_WidgetWin", StringComparison.OrdinalIgnoreCase) >= 0;
        bool electron = cls.IndexOf("Electron", StringComparison.OrdinalIgnoreCase) >= 0;
        if (cls.IndexOf("IME", StringComparison.OrdinalIgnoreCase) >= 0) return true;
        if (cls.IndexOf("crashpad", StringComparison.OrdinalIgnoreCase) >= 0) return true;
        if (cls.IndexOf("NotifyIcon", StringComparison.OrdinalIgnoreCase) >= 0) return true;
        if (cls.IndexOf("StatusTray", StringComparison.OrdinalIgnoreCase) >= 0) return true;
        if (cls.IndexOf("PowerMessage", StringComparison.OrdinalIgnoreCase) >= 0) return true;
        if (!chrome && !electron && textLen <= 0) return true;
        int score = 1;
        if (chrome) score += 50;
        if (electron) score += 20;
        if (textLen > 0) score += 10;
        if (IsWindowVisible(hWnd)) score += 15;
        if (title.IndexOf("Codex", StringComparison.OrdinalIgnoreCase) >= 0) score += 25;
        if (title.IndexOf("ChatGPT", StringComparison.OrdinalIgnoreCase) >= 0) score += 20;
        if (cls.IndexOf("Chrome_WidgetWin_1", StringComparison.OrdinalIgnoreCase) >= 0) score += 15;
        hits.Add(new Hit { Hwnd = hWnd, Pid = pid, ClassName = cls, Title = title, Score = score });
        return true;
      }, IntPtr.Zero);
      hits.Sort((a, b) => b.Score.CompareTo(a.Score));
      return hits;
    }

    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr hWnd, EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool EnableWindow(IntPtr hWnd, bool bEnable);

    // Electron may leave "Intermediate D3D Window" disabled: top-level focuses,
    // but mouse/keyboard never reach the page (whole UI feels frozen).
    public static void EnableDisabledRenderChildren(IntPtr parent) {
      EnumChildWindows(parent, (hWnd, l) => {
        if (!IsWindowEnabled(hWnd)) {
          var sb = new StringBuilder(256);
          GetClassName(hWnd, sb, sb.Capacity);
          var cls = sb.ToString() ?? "";
          if (IsWindowVisible(hWnd)
              || cls.IndexOf("Intermediate D3D", StringComparison.OrdinalIgnoreCase) >= 0
              || cls.IndexOf("Chrome_RenderWidget", StringComparison.OrdinalIgnoreCase) >= 0
              || cls.IndexOf("Chrome_WidgetWin", StringComparison.OrdinalIgnoreCase) >= 0) {
            EnableWindow(hWnd, true);
          }
        }
        return true;
      }, IntPtr.Zero);
    }

    public static bool FocusHwnd(IntPtr hWnd) {
      if (hWnd == IntPtr.Zero) return false;
      // Force restore/show even when IsWindowVisible was false.
      ShowWindow(hWnd, 9);      // SW_RESTORE
      ShowWindowAsync(hWnd, 5); // SW_SHOW
      EnableDisabledRenderChildren(hWnd);
      uint ignoredPid1 = 0;
      uint ignoredPid2 = 0;
      uint targetThread = GetWindowThreadProcessId(hWnd, out ignoredPid1);
      uint cur = GetCurrentThreadId();
      uint fgThread = GetWindowThreadProcessId(GetForegroundWindow(), out ignoredPid2);
      bool attached1 = false, attached2 = false;
      try {
        AllowSetForegroundWindow(-1);
        if (fgThread != cur) attached1 = AttachThreadInput(cur, fgThread, true);
        if (targetThread != cur && targetThread != fgThread) attached2 = AttachThreadInput(cur, targetThread, true);
        BringWindowToTop(hWnd);
        bool ok = SetForegroundWindow(hWnd);
        EnableDisabledRenderChildren(hWnd);
        return ok;
      } finally {
        if (attached2) AttachThreadInput(cur, targetThread, false);
        if (attached1) AttachThreadInput(cur, fgThread, false);
      }
    }
  }
}
'@
  Add-Type -TypeDefinition $code -Language CSharp -ErrorAction Stop
}

function Get-CodexSkinProcessIdSet {
  param(
    [Parameter(Mandatory = $true)]$Codex,
    [scriptblock]$PathEqual = $null
  )
  $set = New-Object 'System.Collections.Generic.HashSet[uint32]'
  # Store apps often hide Path; always take ChatGPT/Codex PIDs by name first.
  foreach ($name in @('ChatGPT', 'Codex')) {
    Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
      try { [void]$set.Add([uint32]$_.Id) } catch {}
    }
  }
  # Optional path filter: keep only matching package if Path is available.
  if ($null -ne $PathEqual -or $Codex.Executable) {
    $filtered = New-Object 'System.Collections.Generic.HashSet[uint32]'
    foreach ($name in @('ChatGPT', 'Codex')) {
      Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
        try {
          $path = $_.Path
          $ok = $true
          if ($path -and $null -ne $PathEqual) {
            $ok = [bool](& $PathEqual $path $Codex.Executable)
          } elseif ($path -and $Codex.Executable) {
            $ok = ("$path" -ieq "$($Codex.Executable)") -or ("$path" -like '*OpenAI.Codex*') -or ("$path" -like '*ChatGPT.exe')
          }
          if ($ok) { [void]$filtered.Add([uint32]$_.Id) }
        } catch {
          [void]$filtered.Add([uint32]$_.Id)
        }
      }
    }
    if ($filtered.Count -gt 0) { $set = $filtered }
  }
  # Port-owner fallback: CDP listener may own the browser host.
  try {
    Get-NetTCPConnection -LocalPort 9335 -State Listen -ErrorAction SilentlyContinue |
      ForEach-Object { if ($_.OwningProcess) { [void]$set.Add([uint32]$_.OwningProcess) } }
  } catch {}
  return $set
}

function Focus-CodexSkinWindow {
  # 找 Codex 顶层窗口并强制置前。
  #
  # 稳定性 (PAIN-POINTS #4)：EnumWindows / MainWindowHandle 在以下瞬时状态会假空——
  #   - Electron 冷启动窗口刚创建但 WM_CREATE 未完成
  #   - MainWindowHandle 缓存在 System.Diagnostics.Process，需要 Refresh()
  #   - 切窗/最小化恢复的 100–300ms 间隔
  # 因此我们在 $TimeoutMs 预算内做 bounded retry：MainWindow → EnumWindows → sleep 120ms 再来一遍。
  # 只要预算内任一轮命中就返回；全灭再走 AppActivate 兜底。
  param(
    [Parameter(Mandatory = $true)]$Codex,
    [scriptblock]$PathEqual = $null,
    # Cold first call: SetForegroundWindow may reject all 4 hits (~300ms each) —
    # so budget 1800ms so at least a second retry round can succeed after the
    # attach-thread-input warm-up succeeds. Subsequent calls typically finish
    # under 400ms via the MainWindow fast path.
    [int]$TimeoutMs = 1800
  )
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $attempt = 0
  $lastHitCount = 0
  $lastPidCount = 0
  try {
    Ensure-CodexSkinFocusType
    while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
      $attempt++
      # 每轮重新收集 pids：Electron 会在启动早期 spawn 若干子进程，pid 集合会扩张。
      $pids = Get-CodexSkinProcessIdSet -Codex $Codex -PathEqual $PathEqual
      $lastPidCount = $pids.Count
      if ($pids.Count -eq 0) {
        if ($sw.ElapsedMilliseconds -ge ($TimeoutMs - 120)) { break }
        Start-Sleep -Milliseconds 120
        continue
      }
      # 1) Fast path: process MainWindowHandle (with Refresh so we're not on cached zero).
      # NOTE: do not use $pid — it aliases automatic $PID (read-only) on Windows PowerShell.
      foreach ($processId in $pids) {
        if ($sw.ElapsedMilliseconds -gt $TimeoutMs) { break }
        try {
          $proc = Get-Process -Id ([int]$processId) -ErrorAction SilentlyContinue
          if ($null -eq $proc) { continue }
          try { $proc.Refresh() } catch {}
          $hwnd = $proc.MainWindowHandle
          if ($hwnd -ne [IntPtr]::Zero) {
            if ([CodexSkin.WinFocus6]::FocusHwnd($hwnd)) {
              Write-CodexSkinLog ("Focused Codex MainWindow pid=$processId attempt=$attempt ms=$($sw.ElapsedMilliseconds)")
              return $true
            }
          }
        } catch {}
      }
      # 2) EnumWindows across process tree
      $hits = [CodexSkin.WinFocus6]::FindWindows($pids)
      $lastHitCount = $hits.Count
      foreach ($hit in $hits) {
        if ($sw.ElapsedMilliseconds -gt $TimeoutMs) { break }
        $focusedHit = [CodexSkin.WinFocus6]::FocusHwnd($hit.Hwnd)
        if ($focusedHit) {
          [void](Invoke-CodexSkinFlashWindow -Hwnd $hit.Hwnd)
          [void](Try-CodexSkinAppActivate)
          Write-CodexSkinLog ("Focused Codex EnumWindows pid=$($hit.Pid) class=$($hit.ClassName) attempt=$attempt ms=$($sw.ElapsedMilliseconds)")
          return $true
        }
      }
      # Only sleep + retry if we still have budget for another round.
      $remaining = $TimeoutMs - $sw.ElapsedMilliseconds
      if ($remaining -lt 180) { break }
      Start-Sleep -Milliseconds 120
    }
    # Last resort: AppActivate by title
    if (Try-CodexSkinAppActivate) {
      Write-CodexSkinLog ("Focused Codex AppActivate attempts=$attempt ms=$($sw.ElapsedMilliseconds)")
      return $true
    }
    Write-CodexSkinLog ("Focus Codex: no window attempts=$attempt ms=$($sw.ElapsedMilliseconds) pids=$lastPidCount hits=$lastHitCount")
  } catch {
    Write-CodexSkinLog ('Focus Codex skipped: ' + $_.Exception.Message)
  }
  return $false
}

function Repair-CodexSkinDisabledRenderWindows {
  <#
  .SYNOPSIS
    Re-enable disabled Electron render children (Intermediate D3D Window).
  .DESCRIPTION
    Whole-page unclickable freeze: top-level window is fine, but Chromium's
    Intermediate D3D Window child is IsWindowEnabled=false so input never
    reaches the page. Safe to call periodically from tray health timer.
  .OUTPUTS
    int — number of top-level windows whose children were repaired (best-effort 0/1)
  #>
  param(
    [object]$Codex = $null,
    [scriptblock]$PathEqual = $null
  )
  try {
    Ensure-CodexSkinFocusType
    if (-not $Codex) {
      # Best-effort without full codex discovery: use process names only.
      $pids = New-Object 'System.Collections.Generic.HashSet[uint32]'
      foreach ($name in @('ChatGPT', 'Codex')) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
          try { [void]$pids.Add([uint32]$_.Id) } catch {}
        }
      }
    } else {
      $pids = Get-CodexSkinProcessIdSet -Codex $Codex -PathEqual $PathEqual
    }
    if ($pids.Count -eq 0) { return 0 }
    $hits = [CodexSkin.WinFocus6]::FindWindows($pids)
    $fixed = 0
    foreach ($hit in $hits) {
      try {
        [CodexSkin.WinFocus6]::EnableDisabledRenderChildren($hit.Hwnd)
        $fixed += 1
        # only need the highest-scoring main window
        break
      } catch {}
    }
    return $fixed
  } catch {
    return 0
  }
}

function Invoke-CodexSkinNativeOpenOrFocus {
  <#
  .SYNOPSIS
    Open/focus Codex without cold-starting a second PowerShell open script.
  .DESCRIPTION
    Prefer in-process WinFocus6 focus when Codex already looks running (tray has
    launcher-ui loaded). Otherwise fire-and-forget CodexFastLaunch.exe
    (native ~100ms). Last resort: open-codex-dream-skin.ps1.
    Tray path for PAIN-POINTS #8 / #16.
  .OUTPUTS
    string — focused | native-launched | ps-launched | failed
  #>
  param(
    [ValidateRange(1024, 65535)][int]$Port = 9335,
    [string]$ProgramRoot = (Get-CodexSkinProgramRoot),
    [string]$StateRoot = (Get-CodexSkinStateRoot),
    [switch]$PreferNativeExe
  )
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    try {
      if (Get-Command Set-DreamSkinPaused -ErrorAction SilentlyContinue) {
        Set-DreamSkinPaused -Paused $false -StateRoot $StateRoot | Out-Null
      }
    } catch {}

    $nativeExe = Join-Path $ProgramRoot 'CodexFastLaunch.exe'
    $openScript = Join-Path $ProgramRoot 'open-codex-dream-skin.ps1'

    if (-not $PreferNativeExe) {
      try {
        Ensure-CodexSkinFocusType
        $cg = @(Get-Process -Name ChatGPT -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero })
        if ($cg.Count -eq 0) {
          $cg = @(Get-Process -Name ChatGPT,Codex -ErrorAction SilentlyContinue)
        }
        if ($cg.Count -gt 0) {
          try { [void](Repair-CodexSkinDisabledRenderWindows) } catch {}
          # Ultra-fast path: one MainWindow FocusHwnd attempt (~tens of ms) before
          # the longer Focus-CodexSkinWindow retry budget.
          foreach ($proc in $cg) {
            try {
              $proc.Refresh()
              $hwnd = $proc.MainWindowHandle
              if ($hwnd -ne [IntPtr]::Zero -and [CodexSkin.WinFocus6]::FocusHwnd([IntPtr]$hwnd)) {
                Write-CodexSkinLog ("tray native focus ok (main-handle) ms=" + $sw.ElapsedMilliseconds)
                return 'focused'
              }
            } catch {}
          }
          $codexObj = $null
          try {
            if (Get-Command Get-DreamSkinCodexInstall -ErrorAction SilentlyContinue) {
              $codexObj = Get-DreamSkinCodexInstall
            }
          } catch {}
          $focused = $false
          if ($null -ne $codexObj -and (Get-Command Focus-CodexSkinWindow -ErrorAction SilentlyContinue)) {
            $eq = $null
            if (Get-Command Test-DreamSkinPathEqual -ErrorAction SilentlyContinue) {
              $eq = { param($a, $b) Test-DreamSkinPathEqual -Left $a -Right $b }
            }
            $focused = [bool](Focus-CodexSkinWindow -Codex $codexObj -PathEqual $eq -TimeoutMs 350)
          } else {
            foreach ($proc in $cg) {
              try {
                $proc.Refresh()
                $hwnd = $proc.MainWindowHandle
                if ($hwnd -ne [IntPtr]::Zero -and [CodexSkin.WinFocus6]::FocusHwnd([IntPtr]$hwnd)) {
                  $focused = $true
                  break
                }
              } catch {}
            }
            if (-not $focused) {
              try {
                $pids = New-Object 'System.Collections.Generic.HashSet[uint32]'
                foreach ($proc in $cg) { try { [void]$pids.Add([uint32]$proc.Id) } catch {} }
                $hits = [CodexSkin.WinFocus6]::FindWindows($pids)
                foreach ($hit in $hits) {
                  if ([CodexSkin.WinFocus6]::FocusHwnd($hit.Hwnd)) { $focused = $true; break }
                }
              } catch {}
            }
            if (-not $focused -and (Get-Command Try-CodexSkinAppActivate -ErrorAction SilentlyContinue)) {
              $focused = [bool](Try-CodexSkinAppActivate)
            }
          }
          if ($focused) {
            Write-CodexSkinLog ("tray native focus ok ms=" + $sw.ElapsedMilliseconds)
            return 'focused'
          }
        }
      } catch {
        Write-CodexSkinLog ('tray in-process focus skipped: ' + $_.Exception.Message)
      }
    }

    if (Test-Path -LiteralPath $nativeExe -PathType Leaf) {
      try {
        Start-Process -FilePath $nativeExe -WorkingDirectory $ProgramRoot -WindowStyle Hidden | Out-Null
        Write-CodexSkinLog ("tray launched CodexFastLaunch.exe ms=" + $sw.ElapsedMilliseconds)
        return 'native-launched'
      } catch {
        Write-CodexSkinLog ('tray native exe failed: ' + $_.Exception.Message)
      }
    }

    if (Test-Path -LiteralPath $openScript -PathType Leaf) {
      $psExe = (Get-Command powershell.exe -ErrorAction Stop).Source
      Start-Process -FilePath $psExe -ArgumentList @(
        '-NoProfile','-STA','-WindowStyle','Hidden','-ExecutionPolicy','Bypass',
        '-File', $openScript, '-Port', "$Port", '-NoPrompt'
      ) -WindowStyle Hidden | Out-Null
      Write-CodexSkinLog ("tray launched open-codex-dream-skin.ps1 ms=" + $sw.ElapsedMilliseconds)
      return 'ps-launched'
    }
    return 'failed'
  } catch {
    Write-CodexSkinLog ('Invoke-CodexSkinNativeOpenOrFocus failed: ' + $_.Exception.Message)
    return 'failed'
  }
}

function Invoke-CodexSkinControl {

  <#
  .SYNOPSIS
    Call watch control plane (127.0.0.1:9336 by default). Returns $null on miss.
    Mutating POSTs send x-codex-skin-token from control.token when present.
    GET health stays unauthenticated (FastLaunch / probes).
  #>
  param(
    [ValidateSet('health','focus','kick','open-healthy')][string]$Action = 'health',
    [int]$Port = 0,
    [int]$TimeoutMs = 120,
    [string]$StateRoot = (Get-CodexSkinStateRoot)
  )
  try {
    if ($Port -lt 1024) {
      $Port = Get-CodexSkinControlPort -StateRoot $StateRoot
    }
    $url = if ($Action -eq 'health') {
      "http://127.0.0.1:$Port/health"
    } else {
      "http://127.0.0.1:$Port/$Action"
    }
    $req = [System.Net.HttpWebRequest]::Create($url)
    $req.Timeout = $TimeoutMs
    $req.ReadWriteTimeout = $TimeoutMs
    $req.Method = if ($Action -eq 'health') { 'GET' } else { 'POST' }
    $req.ContentType = 'application/json'
    $req.ContentLength = 0
    if ($Action -ne 'health') {
      $token = Get-CodexSkinControlToken -StateRoot $StateRoot
      if ($token) {
        $req.Headers['x-codex-skin-token'] = $token
      }
      $stream = $req.GetRequestStream()
      $stream.Close()
    }
    $resp = $req.GetResponse()
    $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
    $text = $reader.ReadToEnd()
    $reader.Close()
    $resp.Close()
    return ($text | ConvertFrom-Json)
  } catch {
    return $null
  }
}

function Resolve-CodexSkinRuntimeRoot {
  param(
    [Parameter(Mandatory = $true)][string]$ProgramRoot
  )
  $currentPath = Join-Path $ProgramRoot 'current.json'
  $current = Read-CodexSkinJsonUtf8 -Path $currentPath
  if ($current.schemaVersion -ne 1 -or -not $current.runtimeId) {
    throw 'Dream Skin current runtime pointer is invalid.'
  }
  $relative = [string]$current.relativeEnginePath
  if (-not $relative) { $relative = "versions/$($current.runtimeId)" }
  $runtimeRoot = Join-Path $ProgramRoot ($relative -replace '/', '\')
  return [pscustomobject]@{
    Current = $current
    RuntimeRoot = [System.IO.Path]::GetFullPath($runtimeRoot)
    ScriptsRoot = [System.IO.Path]::GetFullPath((Join-Path $runtimeRoot 'scripts'))
    InjectorPath = [System.IO.Path]::GetFullPath((Join-Path $runtimeRoot 'scripts\injector.mjs'))
    RuntimeId = [string]$current.runtimeId
  }
}

function New-CodexSkinRuntimeState {
  <#
  .SYNOPSIS
    构造规范化 state 对象：强制 injector/node/port/browserId 对齐 current runtime。
    保留 controlPort（来自参数 / 旧 state / control.port 文件）。
  #>
  param(
    [Parameter(Mandatory = $true)]$RuntimeInfo,
    [Parameter(Mandatory = $true)]$Node,
    [Parameter(Mandatory = $true)]$Codex,
    [Parameter(Mandatory = $true)][int]$Port,
    [Parameter(Mandatory = $true)][string]$BrowserId,
    [Parameter(Mandatory = $true)][int]$InjectorPid,
    [Parameter(Mandatory = $true)][string]$InjectorStartedAt,
    [Parameter(Mandatory = $true)][string]$ThemeDir,
    [Parameter(Mandatory = $true)][string]$PauseFile,
    [string]$ProfilePath = '',
    [int]$ControlPort = 0,
    $PreviousState = $null
  )
  $injectorPath = $RuntimeInfo.InjectorPath
  if (-not (Test-Path -LiteralPath $injectorPath)) {
    throw "Current runtime injector missing: $injectorPath"
  }

  $resolvedControlPort = 0
  if ($ControlPort -ge 1024) {
    $resolvedControlPort = $ControlPort
  } elseif ($PreviousState -and $PreviousState.controlPort) {
    try {
      $n = [int]$PreviousState.controlPort
      if ($n -ge 1024) { $resolvedControlPort = $n }
    } catch {}
  }
  if ($resolvedControlPort -lt 1024 -and (Get-Command Get-CodexSkinControlPort -ErrorAction SilentlyContinue)) {
    try { $resolvedControlPort = [int](Get-CodexSkinControlPort) } catch {}
  }
  if ($resolvedControlPort -lt 1024) { $resolvedControlPort = 9336 }

  $createdAt = (Get-Date).ToUniversalTime().ToString('o')
  if ($PreviousState -and $PreviousState.createdAt) {
    $createdAt = [string]$PreviousState.createdAt
  }

  return [pscustomobject]@{
    schemaVersion = 3
    platform = 'windows'
    product = 'codex-skin'
    runtimeId = $RuntimeInfo.RuntimeId
    port = $Port
    controlPort = $resolvedControlPort
    injectorPid = $InjectorPid
    injectorStartedAt = $InjectorStartedAt
    injectorPath = $injectorPath
    nodePath = $Node.Path
    nodeVersion = $Node.Version
    codexExe = $Codex.Executable
    codexPackageRoot = $Codex.PackageRoot
    codexPackageFullName = $Codex.PackageFullName
    codexPackageFamilyName = $Codex.PackageFamilyName
    codexVersion = $Codex.Version
    browserId = $BrowserId
    profilePath = $ProfilePath
    themeDir = $ThemeDir
    pauseFile = $PauseFile
    createdAt = $createdAt
    updatedAt = (Get-Date).ToUniversalTime().ToString('o')
  }
}

function Write-CodexSkinRuntimeState {
  <#
  .SYNOPSIS
    原子写 state.json（规范化字段）。写前再兜底补 controlPort。
  #>
  param(
    [Parameter(Mandatory = $true)][string]$StatePath,
    [Parameter(Mandatory = $true)]$State
  )
  try {
    $has = $false
    if ($State.PSObject.Properties.Name -contains 'controlPort') {
      try { if ([int]$State.controlPort -ge 1024) { $has = $true } } catch {}
    }
    if (-not $has) {
      $cp = 9336
      if (Get-Command Get-CodexSkinControlPort -ErrorAction SilentlyContinue) {
        try { $cp = [int](Get-CodexSkinControlPort) } catch {}
      }
      $State | Add-Member -NotePropertyName controlPort -NotePropertyValue $cp -Force
    }
  } catch {}
  if (Get-Command Write-DreamSkinState -ErrorAction SilentlyContinue) {
    Write-DreamSkinState -Path $StatePath -State $State
    return
  }
  Write-CodexSkinJsonUtf8NoBom -Path $StatePath -Object $State
}

function Get-DreamSkinVerifiedCdpIdentityRetry {
  <#
  .SYNOPSIS
    Short retry wrapper for CDP identity (avoids one-shot false negatives).
  #>
  param(
    [Parameter(Mandatory = $true)][int]$Port,
    [Parameter(Mandatory = $true)]$Codex,
    [int]$Attempts = 3,
    [int]$DelayMs = 350
  )
  $last = $null
  for ($i = 0; $i -lt [Math]::Max(1, $Attempts); $i++) {
    try {
      $last = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $Codex
      if ($null -ne $last) { return $last }
    } catch {}
    if ($i -lt $Attempts - 1) { Start-Sleep -Milliseconds $DelayMs }
  }
  return $last
}

function Test-CodexSkinInjectorPathFresh {
  <#
  .SYNOPSIS
    判断 state.injectorPath 是否对齐 current runtime。
  #>
  param(
    [Parameter(Mandatory = $true)]$State,
    [Parameter(Mandatory = $true)]$RuntimeInfo
  )
  if (-not $State -or -not $State.injectorPath) {
    return [pscustomobject]@{ fresh = $false; reason = 'missing-state-injectorPath'; expected = $RuntimeInfo.InjectorPath; actual = $null }
  }
  $actual = [System.IO.Path]::GetFullPath([string]$State.injectorPath)
  $expected = [System.IO.Path]::GetFullPath([string]$RuntimeInfo.InjectorPath)
  $fresh = $actual.Equals($expected, [System.StringComparison]::OrdinalIgnoreCase)
  $runtimeMatch = $true
  if ($State.runtimeId -and $RuntimeInfo.RuntimeId) {
    $runtimeMatch = ([string]$State.runtimeId).Equals([string]$RuntimeInfo.RuntimeId, [System.StringComparison]::OrdinalIgnoreCase)
  }
  return [pscustomobject]@{
    fresh = ($fresh -and $runtimeMatch)
    reason = if ($fresh -and $runtimeMatch) { 'ok' } elseif (-not $fresh) { 'injector-path-drift' } else { 'runtimeId-drift' }
    expected = $expected
    actual = $actual
    expectedRuntimeId = $RuntimeInfo.RuntimeId
    actualRuntimeId = $State.runtimeId
  }
}
