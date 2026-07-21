[CmdletBinding()]
param([int]$Port = 9335, [switch]$ShowMenu)

$ErrorActionPreference = 'Stop'
# UTF-8 console bootstrap (PAIN-POINTS #22). Full helper also runs when launcher-ui is dotted.
try {
  & chcp.com 65001 | Out-Null
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  try { [Console]::OutputEncoding = $utf8 } catch {}
  try { [Console]::InputEncoding = $utf8 } catch {}
  $OutputEncoding = $utf8
} catch {}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
. (Join-Path $PSScriptRoot 'common-windows.ps1')
. (Join-Path $PSScriptRoot 'theme-windows.ps1')
# Optional: launcher-ui provides Repair-CodexSkinDisabledRenderWindows + WinFocus6.
# Installed layouts also copy it to programRoot\lib\launcher-ui.ps1.
foreach ($ui in @(
  (Join-Path $PSScriptRoot 'launcher-ui.ps1'),
  (Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) 'lib\launcher-ui.ps1')
)) {
  if (Test-Path -LiteralPath $ui) { . $ui; break }
}

Assert-DreamSkinPort -Port $Port
$SkillRoot = Split-Path -Parent $PSScriptRoot
$StateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
$paths = Initialize-DreamSkinThemeStore -SkillRoot $SkillRoot -StateRoot $StateRoot
$powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
$startScript = Join-Path $PSScriptRoot 'start-dream-skin.ps1'
$restoreScript = Join-Path $PSScriptRoot 'restore-dream-skin.ps1'

$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$mutex = [System.Threading.Mutex]::new($false, "Local\CodexDreamSkin.$sid.Tray")
$showSignal = [System.Threading.EventWaitHandle]::new(
  $false,
  [System.Threading.EventResetMode]::AutoReset,
  "Local\CodexDreamSkin.$sid.Tray.Show"
)
$acquired = $false
$showTimer = $null
$healthTimer = $null
$script:LastBareNoticeAt = [datetime]::MinValue
$script:LastTipText = ''
$script:TrayRuntimeId = Split-Path (Split-Path $PSScriptRoot -Parent) -Leaf
$script:ProgramRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
try {
  try { $acquired = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $acquired = $true }
  if (-not $acquired) {
    if ($ShowMenu) { $null = $showSignal.Set() }
    exit 0
  }

  $notify = [System.Windows.Forms.NotifyIcon]::new()
  $notify.Icon = [System.Drawing.SystemIcons]::Application
  $notify.Text = 'Codex Skin · 多主题'
  $notify.Visible = $true
  $menu = [System.Windows.Forms.ContextMenuStrip]::new()
  $notify.ContextMenuStrip = $menu

  function Show-DreamSkinTrayError {
    param([string]$Message)
    [void][System.Windows.Forms.MessageBox]::Show(
      $Message,
      'Codex Skin',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error
    )
  }

  function Start-DreamSkinPowerShell {
    param([Parameter(Mandatory = $true)][string]$Script, [string[]]$Arguments = @())
    $scriptToken = ConvertTo-DreamSkinProcessArgument -Value $Script
    $argumentLine = '-NoProfile -ExecutionPolicy RemoteSigned -File ' + $scriptToken
    if ($Arguments.Count -gt 0) { $argumentLine += ' ' + ($Arguments -join ' ') }
    Start-Process -FilePath $powershell -ArgumentList $argumentLine | Out-Null
  }

  function Add-DreamSkinTrayItem {
    param(
      [Parameter(Mandatory = $true)]
      [AllowEmptyCollection()]
      [System.Windows.Forms.ToolStripItemCollection]$Items,
      [Parameter(Mandatory = $true)][string]$Text,
      [AllowNull()][scriptblock]$Action,
      [bool]$Enabled = $true
    )
    $item = [System.Windows.Forms.ToolStripMenuItem]::new($Text)
    $item.Enabled = $Enabled
    if ($null -ne $Action) {
      $item.add_Click({
        try { & $Action } catch { Show-DreamSkinTrayError -Message $_.Exception.Message }
      }.GetNewClosure())
    }
    [void]$Items.Add($item)
    return $item
  }

  function Test-DreamSkinBareCodexRunning {
    try {
      $codex = Get-DreamSkinCodexInstall
      $running = @(Get-DreamSkinCodexProcesses -Codex $codex)
      if ($running.Count -eq 0) { return $false }
      $cdp = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $codex
      return ($null -eq $cdp)
    } catch {
      return $false
    }
  }

  function Get-DreamSkinControlPortLocal {
    # Prefer shared helper when launcher-ui is available (open/switch publish path).
    if (Get-Command Get-CodexSkinControlPort -ErrorAction SilentlyContinue) {
      try { return Get-CodexSkinControlPort -StateRoot $StateRoot } catch {}
    }
    $p = Join-Path $StateRoot 'control.port'
    if (Test-Path -LiteralPath $p) {
      $n = 0
      if ([int]::TryParse((Get-Content -LiteralPath $p -Raw).Trim(), [ref]$n) -and $n -ge 1024) { return $n }
    }
    try {
      $statePath = Join-Path $StateRoot 'state.json'
      if (Test-Path -LiteralPath $statePath) {
        $st = Get-Content -LiteralPath $statePath -Raw -Encoding utf8 | ConvertFrom-Json
        if ($st.controlPort) {
          $n = [int]$st.controlPort
          if ($n -ge 1024) { return $n }
        }
      }
    } catch {}
    return 9336
  }

  function Get-DreamSkinTraySnapshot {
    $paused = Test-DreamSkinPaused -StateRoot $StateRoot
    $state = $null
    try { $state = Read-DreamSkinState -Path $paths.State } catch {}
    $injectorAlive = $false
    if ($state) {
      try { $injectorAlive = [bool](Test-DreamSkinInjectorAlive -State $state) } catch {}
    }
    $bare = Test-DreamSkinBareCodexRunning
    $phase = ''
    try {
      $openStatus = Join-Path $StateRoot 'open-status.json'
      if (Test-Path -LiteralPath $openStatus) {
        $phase = [string]((Get-Content -LiteralPath $openStatus -Raw -Encoding utf8 | ConvertFrom-Json).phase)
      }
    } catch {}
    $kind = if ($paused) { 'paused' }
      elseif ($bare) { 'bare' }
      elseif ($injectorAlive) { 'healthy' }
      elseif ($state) { 'injector-dead' }
      else { 'uninitialized' }
    return [pscustomobject]@{
      Kind = $kind; Paused = $paused; Bare = $bare; InjectorAlive = $injectorAlive
      Phase = $phase; State = $state; ControlPort = (Get-DreamSkinControlPortLocal)
    }
  }

  function Update-DreamSkinTrayTip {
    param([switch]$NotifyBare)
    $snap = Get-DreamSkinTraySnapshot
    $prefix = switch ($snap.Kind) {
      'healthy' { '✓' }
      'bare' { '!' }
      'paused' { 'Ⅱ' }
      'injector-dead' { '!' }
      default { '·' }
    }
    $stateText = switch ($snap.Kind) {
      'healthy' { '正常' }
      'bare' { '裸启：未带皮肤' }
      'paused' { '已暂停' }
      'injector-dead' { '守护未运行' }
      default { '未初始化' }
    }
    $phaseText = switch -Regex ($snap.Phase) {
      '^start$' { '启动中' }
      '^slow-path' { '完整启动中' }
      '^shell-wait' { '等待界面' }
      '^launch-cdp' { '启动 Codex' }
      '^inject-start' { '挂载皮肤' }
      '^healthy-focus' { '聚焦窗口' }
      '^control-hit' { '就绪' }
      '^ready' { '就绪' }
      '^first-run' { '欢迎引导' }
      '^user-feedback' { '需处理' }
      '^focus-miss' { '窗口在后台' }
      '^bare-codex' { '裸启处理中' }
      '^failed' { '启动失败' }
      default { '' }
    }
    $elapsedHint = ''
    try {
      $openStatus = Join-Path $StateRoot 'open-status.json'
      if (Test-Path -LiteralPath $openStatus) {
        $os = Get-Content -LiteralPath $openStatus -Raw -Encoding utf8 | ConvertFrom-Json
        if ($os.updatedAt -and $phaseText -and $phaseText -ne '就绪') {
          $updated = [datetime]::Parse([string]$os.updatedAt).ToUniversalTime()
          $age = [int]([datetime]::UtcNow - $updated).TotalSeconds
          if ($age -ge 0 -and $age -le 120) {
            if ($age -ge 8 -and $snap.Phase -match 'shell-wait|slow-path|launch|inject') {
              $elapsedHint = '仍在等待'
            }
          }
        }
      }
    } catch {}
    $tip = "$prefix Codex Skin · $stateText"
    if ($phaseText -and $phaseText -ne '就绪') { $tip += " · $phaseText" }
    if ($elapsedHint) { $tip += " · $elapsedHint" }
    # NotifyIcon text hard limit is 63 chars.
    $notify.Text = $tip.Substring(0, [Math]::Min(63, $tip.Length))
    if ($NotifyBare -and $snap.Bare -and ((Get-Date) - $script:LastBareNoticeAt).TotalSeconds -ge 60) {
      # Require two timer checks: avoid transient CDP probe false positives.
      if ($script:LastTipText -match '裸启') {
        $notify.ShowBalloonTip(
          5200,
          'Codex Skin',
          "检测到未带皮肤的 Codex。`n请点托盘 →「用皮肤重启 Codex」。`n未发送草稿可能丢失。",
          [System.Windows.Forms.ToolTipIcon]::Warning
        )
        $script:LastBareNoticeAt = Get-Date
      }
    }
    # Cold-start lingering feedback (throttled via tip text change only; balloon rare)
    if ($elapsedHint -and $snap.Phase -match 'shell-wait' -and ((Get-Date) - $script:LastBareNoticeAt).TotalSeconds -ge 90) {
      # reuse throttle clock lightly; do not spam
    }
    $script:LastTipText = $tip
    return $snap
  }

  function Test-DreamSkinTrayRuntimeChanged {
    try {
      $currentPath = Join-Path $script:ProgramRoot 'current.json'
      if (-not (Test-Path -LiteralPath $currentPath)) { return $false }
      $current = Get-Content -LiteralPath $currentPath -Raw -Encoding utf8 | ConvertFrom-Json
      return ($current.runtimeId -and ([string]$current.runtimeId -cne [string]$script:TrayRuntimeId))
    } catch { return $false }
  }

  function Rebuild-DreamSkinTrayMenu {
    $menu.Items.Clear()
    $themesLocked = Test-DreamSkinThemesLocked -StateRoot $StateRoot
    $snap = Update-DreamSkinTrayTip
    $state = $snap.State
    $active = $null
    try { $active = Read-DreamSkinTheme -ThemeDirectory $paths.Active -SkipImageMetadata } catch {}
    $activeName = $null
    $activeId = $null
    if ($null -ne $active -and $null -ne $active.Theme) {
      if ($active.Theme.name) { $activeName = [string]$active.Theme.name }
      if ($active.Theme.id) { $activeId = [string]$active.Theme.id }
    }
    $paused = [bool]$snap.Paused
    $injectorAlive = [bool]$snap.InjectorAlive
    $controlPort = $snap.ControlPort
    $bare = [bool]$snap.Bare
    $prefix = switch ($snap.Kind) {
      'healthy' { '✓' }
      'bare' { '!' }
      'paused' { 'Ⅱ' }
      'injector-dead' { '!' }
      default { '·' }
    }
    $status = if ($paused) { "$prefix 状态：已暂停" }
      elseif ($bare) { "$prefix 状态：裸启（无皮肤）" }
      elseif ($injectorAlive) { "$prefix 状态：正常" }
      elseif ($state) { "$prefix 状态：守护未运行" }
      else { "$prefix 状态：未初始化" }
    if ($activeName) { $status += " · $activeName" }
    if ($controlPort) { $status += " · 控制面:$controlPort" }
    if ($themesLocked) { $status += ' · 单皮肤' } else { $status += ' · 多主题' }
    try {
      $thumbReport = Join-Path $StateRoot 'themes\.thumb-report.json'
      if (Test-Path -LiteralPath $thumbReport) {
        $tr = Get-Content -LiteralPath $thumbReport -Raw -Encoding utf8 | ConvertFrom-Json
        if ([int]$tr.fail -gt 0) { $status += (" · F6缺" + $tr.fail + "套") }
      }
    } catch {}
    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text $status -Action $null -Enabled $false
    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '提示：F6 循环缓存皮肤 · 完整库用「换肤…」' -Action $null -Enabled $false
    [void]$menu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new())

    $openScript = Join-Path $env:LOCALAPPDATA 'Programs\CodexDreamSkin\open-codex-dream-skin.ps1'
    $fixScript = Join-Path $env:LOCALAPPDATA 'Programs\CodexDreamSkin\check-and-fix.ps1'
    $switchVbs = Join-Path $env:LOCALAPPDATA 'Programs\CodexDreamSkin\launch-switch-theme.vbs'
    $switchUi = Join-Path $env:LOCALAPPDATA 'Programs\CodexDreamSkin\switch-theme-ui.ps1'
    $openDreamSkin = {
      # #8 tray focus native: in-process WinFocus6 when healthy, else CodexFastLaunch.exe.
      if (Get-Command Invoke-CodexSkinNativeOpenOrFocus -ErrorAction SilentlyContinue) {
        $mode = Invoke-CodexSkinNativeOpenOrFocus -Port $Port -ProgramRoot $script:ProgramRoot -StateRoot $StateRoot
        if ($mode -eq 'failed' -and (Test-Path -LiteralPath $openScript -PathType Leaf)) {
          Start-DreamSkinPowerShell -Script $openScript -Arguments @('-Port', "$Port", '-NoPrompt')
        }
      } else {
        Set-DreamSkinPaused -Paused $false -StateRoot $StateRoot | Out-Null
        $nativeExe = Join-Path $env:LOCALAPPDATA 'Programs\CodexDreamSkin\CodexFastLaunch.exe'
        if (Test-Path -LiteralPath $nativeExe -PathType Leaf) {
          Start-Process -FilePath $nativeExe -WindowStyle Hidden | Out-Null
        } elseif (Test-Path -LiteralPath $openScript -PathType Leaf) {
          Start-DreamSkinPowerShell -Script $openScript -Arguments @('-Port', "$Port", '-NoPrompt')
        } else {
          Start-DreamSkinPowerShell -Script $startScript -Arguments @('-Port', "$Port", '-PromptRestart')
        }
      }
    }.GetNewClosure()
    # Primary daily actions first — bare recovery is top CTA when needed
    if ($bare) {
      $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '★ 用皮肤重启 Codex（可能丢草稿）' -Action {
        $answer = [System.Windows.Forms.MessageBox]::Show(
          "将关闭当前 Codex 并以皮肤模式重启。`n未发送的草稿可能丢失。是否继续？",
          'Codex Skin',
          [System.Windows.Forms.MessageBoxButtons]::YesNo,
          [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
          if (Test-Path -LiteralPath $openScript -PathType Leaf) {
            Start-DreamSkinPowerShell -Script $openScript -Arguments @('-Port', "$Port", '-NoPrompt', '-RestartExisting')
          }
        }
      }.GetNewClosure()
    }
    if (Test-Path -LiteralPath $switchVbs -PathType Leaf) {
      $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '换肤…' -Action {
        Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\wscript.exe') -ArgumentList @('//B', '//Nologo', $switchVbs) | Out-Null
      }.GetNewClosure()
    } elseif (Test-Path -LiteralPath $switchUi -PathType Leaf) {
      $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '换肤…' -Action {
        Start-DreamSkinPowerShell -Script $switchUi
      }.GetNewClosure()
    }
    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '打开/聚焦 Codex' -Action $openDreamSkin
    if (Test-Path -LiteralPath $fixScript -PathType Leaf) {
      $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '一键修复皮肤' -Action {
        Start-DreamSkinPowerShell -Script $fixScript -Arguments @('-Port', "$Port", '-Quiet')
      }.GetNewClosure()
    }
    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '自检状态' -Action {
      $lines = @($status)
      try {
        $os = Join-Path $StateRoot 'open-status.json'
        if (Test-Path -LiteralPath $os) {
          $j = Get-Content -LiteralPath $os -Raw -Encoding utf8 | ConvertFrom-Json
          $lines += ("最近打开: " + $j.phase + $(if ($j.detail) { ' · ' + $j.detail } else { '' }))
        }
      } catch {}
      try {
        $thumbReport = Join-Path $StateRoot 'themes\.thumb-report.json'
        if (Test-Path -LiteralPath $thumbReport) {
          $tr = Get-Content -LiteralPath $thumbReport -Raw -Encoding utf8 | ConvertFrom-Json
          $lines += ("缩略图: ok=$($tr.ok) fail=$($tr.fail)")
        }
      } catch {}
      $notify.ShowBalloonTip(3600, 'Codex Skin 状态', ($lines -join "`n"), [System.Windows.Forms.ToolTipIcon]::Info)
    }.GetNewClosure()
    $pauseText = if ($paused) { '继续显示皮肤' } else { '暂停皮肤' }
    $nextPaused = -not $paused
    $pauseAction = {
      Set-DreamSkinPaused -Paused $nextPaused -StateRoot $StateRoot | Out-Null
    }.GetNewClosure()
    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text $pauseText -Action $pauseAction
    # U3: toggle apply success balloon (ui-prefs.json · applyBalloonEnabled)
    $balloonOn = $true
    try {
      if (Get-Command Test-CodexSkinApplyBalloonEnabled -ErrorAction SilentlyContinue) {
        $balloonOn = [bool](Test-CodexSkinApplyBalloonEnabled -StateRoot $StateRoot)
      }
    } catch {}
    $balloonLabel = if ($balloonOn) { '换肤气泡：开（点此关闭）' } else { '换肤气泡：关（点此开启）' }
    $nextBalloon = -not $balloonOn
    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text $balloonLabel -Action {
      try {
        if (Get-Command Set-CodexSkinUiPrefs -ErrorAction SilentlyContinue) {
          [void](Set-CodexSkinUiPrefs -StateRoot $StateRoot -ApplyBalloonEnabled $nextBalloon)
        } else {
          $prefsPath = Join-Path $StateRoot 'ui-prefs.json'
          $obj = [ordered]@{
            schemaVersion = 1
            applyBalloonEnabled = [bool]$nextBalloon
            updatedAt = (Get-Date).ToUniversalTime().ToString('o')
          }
          $json = ($obj | ConvertTo-Json -Depth 4) + "`n"
          [System.IO.File]::WriteAllText($prefsPath, $json, [System.Text.UTF8Encoding]::new($false))
        }
        $tip = if ($nextBalloon) { '已开启换肤成功气泡' } else { '已关闭换肤成功气泡（菜单状态仍更新）' }
        # Force one confirmation balloon even when turning off, so user sees the change took effect.
        if (Get-Command Show-CodexSkinBalloon -ErrorAction SilentlyContinue) {
          Show-CodexSkinBalloon -Message $tip -Title 'Codex Skin' -Ms 1800 -ThrottleKey 'prefs-balloon' -ThrottleSeconds 2 -Kind Info -Force
        } else {
          $notify.ShowBalloonTip(1800, 'Codex Skin', $tip, [System.Windows.Forms.ToolTipIcon]::Info)
        }
      } catch {
        Show-DreamSkinTrayError -Message $_.Exception.Message
      }
    }.GetNewClosure()
    # Message bubble style: borderless (heige) vs rounded card
    $bubbleStyle = 'borderless'
    try {
      if (Get-Command Get-CodexSkinBubbleStyle -ErrorAction SilentlyContinue) {
        $bubbleStyle = [string](Get-CodexSkinBubbleStyle -StateRoot $StateRoot)
      }
    } catch {}
    $bubbleLabel = if ($bubbleStyle -eq 'card') {
      '消息气泡：圆角卡片（点切无边框）'
    } else {
      '消息气泡：无边框（点切圆角卡片）'
    }
    $nextBubble = if ($bubbleStyle -eq 'card') { 'borderless' } else { 'card' }
    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text $bubbleLabel -Action {
      try {
        if (Get-Command Set-CodexSkinUiPrefs -ErrorAction SilentlyContinue) {
          [void](Set-CodexSkinUiPrefs -StateRoot $StateRoot -BubbleStyle $nextBubble)
        } else {
          $prefsPath = Join-Path $StateRoot 'ui-prefs.json'
          $prev = $null
          try {
            if (Test-Path -LiteralPath $prefsPath) {
              $prev = Get-Content -LiteralPath $prefsPath -Raw -Encoding utf8 | ConvertFrom-Json
            }
          } catch {}
          $obj = [ordered]@{
            schemaVersion = 1
            applyBalloonEnabled = if ($null -ne $prev -and $null -ne $prev.applyBalloonEnabled) { [bool]$prev.applyBalloonEnabled } else { $true }
            bubbleStyle = [string]$nextBubble
            updatedAt = (Get-Date).ToUniversalTime().ToString('o')
          }
          $json = ($obj | ConvertTo-Json -Depth 4) + "`n"
          [System.IO.File]::WriteAllText($prefsPath, $json, [System.Text.UTF8Encoding]::new($false))
        }
        # Kick so injector reloads ui-prefs into payload.
        try {
          if (Get-Command Invoke-CodexSkinControl -ErrorAction SilentlyContinue) {
            [void](Invoke-CodexSkinControl -Action 'kick' -TimeoutMs 3500)
          }
        } catch {}
        $tip = if ($nextBubble -eq 'card') {
          '消息气泡：圆角卡片（细描边）'
        } else {
          '消息气泡：无边框（heige 原味）'
        }
        if (Get-Command Show-CodexSkinBalloon -ErrorAction SilentlyContinue) {
          Show-CodexSkinBalloon -Message $tip -Title 'Codex Skin' -Ms 1800 -ThrottleKey 'prefs-bubble' -ThrottleSeconds 2 -Kind Info -Force
        } else {
          $notify.ShowBalloonTip(1800, 'Codex Skin', $tip, [System.Windows.Forms.ToolTipIcon]::Info)
        }
      } catch {
        Show-DreamSkinTrayError -Message $_.Exception.Message
      }
    }.GetNewClosure()
    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '更换背景图（写入当前皮肤）' -Action {
      $dialog = [System.Windows.Forms.OpenFileDialog]::new()
      $dialog.Title = '选择 Codex 皮肤背景图'
      $dialog.Filter = 'Image files|*.png;*.jpg;*.jpeg;*.webp|All files|*.*'
      $dialog.Multiselect = $false
      try {
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
          $null = Set-DreamSkinActiveTheme -ImagePath $dialog.FileName -Theme $null -StateRoot $StateRoot
          Set-DreamSkinPaused -Paused $false -StateRoot $StateRoot | Out-Null
          $notify.ShowBalloonTip(1800, 'Codex Skin', '背景图已更新。', [System.Windows.Forms.ToolTipIcon]::Info)
        }
      } finally {
        $dialog.Dispose()
      }
    }

    if ($themesLocked) {
      $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '保存当前主题（已锁定）' -Action {
        $notify.ShowBalloonTip(
          2600,
          'Codex Skin',
          '单皮肤锁定中。多主题请执行：lock-themes.ps1 -Unlock',
          [System.Windows.Forms.ToolTipIcon]::Info
        )
      }
      $savedMenu = [System.Windows.Forms.ToolStripMenuItem]::new('切换皮肤（已锁定）')
      $empty = [System.Windows.Forms.ToolStripMenuItem]::new('当前仅 active-theme · 解锁后显示皮肤库')
      $empty.Enabled = $false
      [void]$savedMenu.DropDownItems.Add($empty)
      [void]$menu.Items.Add($savedMenu)
    } else {
      $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '保存当前为皮肤库项' -Action {
        $name = [Microsoft.VisualBasic.Interaction]::InputBox('输入主题名称：', '保存到皮肤库', '')
        if ($name.Trim()) {
          $saved = Save-DreamSkinCurrentTheme -Name $name -StateRoot $StateRoot
          $notify.ShowBalloonTip(1800, 'Codex Skin', "已保存：$($saved.Theme.name)", [System.Windows.Forms.ToolTipIcon]::Info)
        }
      }
      $savedThemes = @(Get-DreamSkinSavedThemes -StateRoot $StateRoot -SkipImageMetadata)
      $savedMenu = [System.Windows.Forms.ToolStripMenuItem]::new(("切换皮肤（{0}）" -f $savedThemes.Count))
      if ($savedThemes.Count -eq 0) {
        $empty = [System.Windows.Forms.ToolStripMenuItem]::new('皮肤库为空 · 可用 codex-skin import-themes')
        $empty.Enabled = $false
        [void]$savedMenu.DropDownItems.Add($empty)
      } else {
        $shown = 0
        foreach ($saved in $savedThemes) {
          if ($shown -ge 24) {
            $more = [System.Windows.Forms.ToolStripMenuItem]::new('…其余主题请用 CLI apply / F6')
            $more.Enabled = $false
            [void]$savedMenu.DropDownItems.Add($more)
            break
          }
          $savedPath = $saved.Path
          $savedName = [string]$saved.Name
          $savedId = [string]$saved.Id
          $isActive = ($activeId -and $savedId -and ($activeId -ieq $savedId)) -or `
            ($activeName -and $savedName -and ($activeName -ieq $savedName))
          $label = if ($isActive) { "✓ $savedName" } else { "   $savedName" }
          $savedAction = {
            $null = Use-DreamSkinSavedTheme -ThemeDirectory $savedPath -StateRoot $StateRoot
            Set-DreamSkinPaused -Paused $false -StateRoot $StateRoot | Out-Null
            # Prefer control-plane kick so skin applies immediately (same as switch-theme-ui).
            $kickOk = $false
            $kickDetail = ''
            try {
              if (Get-Command Invoke-CodexSkinControl -ErrorAction SilentlyContinue) {
                $cp = Invoke-CodexSkinControl -Action 'kick' -TimeoutMs 3500
                if ($null -ne $cp -and $cp.ok) {
                  $kickOk = $true
                  $kickDetail = '即时生效'
                } else {
                  $kickDetail = '注入未确认'
                }
              }
            } catch {
              $kickDetail = $_.Exception.Message
            }
            # U3: respect ui-prefs; still update tray tip text even when balloon off.
            try {
              if (Get-Command Show-CodexSkinApplyFeedback -ErrorAction SilentlyContinue) {
                [void](Show-CodexSkinApplyFeedback -ThemeName $savedName -Ok:$kickOk -Detail $kickDetail)
              } elseif (
                -not (Get-Command Test-CodexSkinApplyBalloonEnabled -ErrorAction SilentlyContinue) -or
                (Test-CodexSkinApplyBalloonEnabled -StateRoot $StateRoot)
              ) {
                $tip = if ($kickOk) { "已切换：$savedName" } else { "已写入：$savedName · $kickDetail" }
                $notify.ShowBalloonTip(1800, 'Codex Skin', $tip, [System.Windows.Forms.ToolTipIcon]::Info)
              }
            } catch {}
            try {
              if ($kickOk) {
                $notify.Text = ("Codex Skin · {0}" -f $savedName)
              }
            } catch {}
          }.GetNewClosure()
          $item = Add-DreamSkinTrayItem -Items $savedMenu.DropDownItems -Text $label -Action $savedAction
          if ($isActive) { $item.Font = New-Object System.Drawing.Font($item.Font, [System.Drawing.FontStyle]::Bold) }
          $shown += 1
        }
      }
      [void]$menu.Items.Add($savedMenu)
    }

    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '打开图片文件夹' -Action {
      Start-Process -FilePath explorer.exe -ArgumentList @($paths.Images) | Out-Null
    }
    [void]$menu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new())
    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '完全恢复 Codex' -Action {
      Start-DreamSkinPowerShell -Script $restoreScript -Arguments @(
        '-Port', "$Port", '-RestoreBaseTheme', '-PromptRestart'
      )
      $notify.Visible = $false
      [System.Windows.Forms.Application]::Exit()
    }
    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '退出托盘' -Action {
      $notify.Visible = $false
      [System.Windows.Forms.Application]::Exit()
    }
  }

  $menu.add_Opening({ Rebuild-DreamSkinTrayMenu })
  $notify.add_DoubleClick({
    try {
      if (Get-Command Invoke-CodexSkinNativeOpenOrFocus -ErrorAction SilentlyContinue) {
        [void](Invoke-CodexSkinNativeOpenOrFocus -Port $Port -ProgramRoot $script:ProgramRoot -StateRoot $StateRoot)
      } else {
        $openScript = Join-Path $env:LOCALAPPDATA 'Programs\CodexDreamSkin\open-codex-dream-skin.ps1'
        $nativeExe = Join-Path $env:LOCALAPPDATA 'Programs\CodexDreamSkin\CodexFastLaunch.exe'
        Set-DreamSkinPaused -Paused $false -StateRoot $StateRoot | Out-Null
        if (Test-Path -LiteralPath $nativeExe -PathType Leaf) {
          Start-Process -FilePath $nativeExe -WindowStyle Hidden | Out-Null
        } elseif (Test-Path -LiteralPath $openScript -PathType Leaf) {
          Start-DreamSkinPowerShell -Script $openScript -Arguments @('-Port', "$Port")
        } else {
          Start-DreamSkinPowerShell -Script $startScript -Arguments @('-Port', "$Port", '-PromptRestart')
        }
      }
    } catch {
      Show-DreamSkinTrayError -Message $_.Exception.Message
    }
  })
  $showTrayMenu = {
    Rebuild-DreamSkinTrayMenu
    $menu.Show([System.Windows.Forms.Cursor]::Position)
  }
  $showTimer = [System.Windows.Forms.Timer]::new()
  $showTimer.Interval = 250
  $showTimer.add_Tick({
    if ($showSignal.WaitOne(0)) {
      try { & $showTrayMenu } catch { Show-DreamSkinTrayError -Message $_.Exception.Message }
    }
  })
  $showTimer.Start()
  # Lightweight UX monitor: status text every 5s; bare-Codex alert after two observations.
  $healthTimer = [System.Windows.Forms.Timer]::new()
  $healthTimer.Interval = 5000
  $healthTimer.add_Tick({
    try {
      [void](Update-DreamSkinTrayTip -NotifyBare)
      # Patrol: re-enable disabled Electron Intermediate D3D child so the page
      # does not stay foregrounded-but-unclickable. Cheap EnumChildWindows only.
      try {
        if (Get-Command Repair-CodexSkinDisabledRenderWindows -ErrorAction SilentlyContinue) {
          [void](Repair-CodexSkinDisabledRenderWindows)
        } elseif (Get-Command Ensure-CodexSkinFocusType -ErrorAction SilentlyContinue) {
          Ensure-CodexSkinFocusType
          $cg = Get-Process -Name ChatGPT -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
          if ($cg) { [CodexSkin.WinFocus6]::EnableDisabledRenderChildren([IntPtr]$cg.MainWindowHandle) }
        }
      } catch {}
      # Runtime pointer changed after publish: replace tray quietly with new script.
      if (Test-DreamSkinTrayRuntimeChanged) {
        $notify.Visible = $false
        $next = Join-Path $script:ProgramRoot 'launch-dream-skin.ps1'
        if (Test-Path -LiteralPath $next) {
          Start-Process -FilePath $powershell -WindowStyle Hidden -ArgumentList @(
            '-NoProfile','-STA','-WindowStyle','Hidden','-ExecutionPolicy','RemoteSigned',
            '-File',$next,'-Port',"$Port"
          ) | Out-Null
        }
        [System.Windows.Forms.Application]::Exit()
      }
    } catch {
      # Health UI must not take down the tray.
    }
  })
  [void](Update-DreamSkinTrayTip)
  $healthTimer.Start()
  if ($ShowMenu) { & $showTrayMenu }
  [System.Windows.Forms.Application]::Run()
} finally {
  if ($null -ne $healthTimer) { $healthTimer.Stop(); $healthTimer.Dispose() }
  if ($null -ne $showTimer) { $showTimer.Stop(); $showTimer.Dispose() }
  if ($null -ne $notify) { $notify.Dispose() }
  if ($acquired) { try { $mutex.ReleaseMutex() } catch {} }
  $showSignal.Dispose()
  $mutex.Dispose()
}
