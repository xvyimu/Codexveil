#Requires -Version 5.1
<#
.SYNOPSIS
  Codex 换肤面板（单实例 + 点击立即生效 + 可隐藏托盘）
.DESCRIPTION
  - 全局 Mutex：同时只允许一个换肤程序
  - 再次点击快捷方式：激活已有窗口，不新开进程
  - 应用皮肤：写 active-theme 后立刻 kick injector --once（不等 watch 轮询）
  - 关闭/最小化：隐藏到托盘；托盘退出才真正结束
#>
[CmdletBinding()]
param(
  [ValidateRange(1024, 65535)][int]$Port = 9335,
  [switch]$StartHidden
)

$ErrorActionPreference = "Stop"
$script:SwitchLog = Join-Path $env:TEMP "codex-switch-theme-error.log"
$script:Form = $null
$script:Tray = $null
$script:AllowExit = $false
$script:Mutex = $null
$script:ShowSignal = $null
$script:ShowTimer = $null
$script:ApplyPending = $false
$script:ApplyDebounceTimer = $null
$script:PendingEntry = $null
$script:LastAppliedPath = $null
$script:LastAppliedAt = [datetime]::MinValue

function Write-SwitchLog([string]$Message) {
  $line = "{0:u} {1}" -f (Get-Date), $Message
  try {
    [System.IO.File]::AppendAllText(
      $script:SwitchLog,
      $line + [Environment]::NewLine,
      [System.Text.UTF8Encoding]::new($false)
    )
  } catch {}
}

function Show-SwitchError([string]$Message) {
  Write-SwitchLog $Message
  try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue | Out-Null
    [void][System.Windows.Forms.MessageBox]::Show(
      $Message,
      "Codex 换肤",
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error
    )
  } catch {}
}

function Show-StatusBalloon([string]$Message) {
  try {
    if ($null -ne $script:Tray -and $script:Tray.Visible) {
      $script:Tray.BalloonTipTitle = "Codex 换肤"
      $script:Tray.BalloonTipText = $Message
      $script:Tray.ShowBalloonTip(1200)
    }
  } catch {}
}

function Show-PickerForm {
  if ($null -eq $script:Form) { return }
  $script:Form.Show()
  $script:Form.WindowState = "Normal"
  $script:Form.ShowInTaskbar = $true
  $script:Form.Activate()
  $script:Form.BringToFront()
  $script:Form.TopMost = $true
  $script:Form.TopMost = $false
}

function Hide-PickerForm {
  if ($null -eq $script:Form) { return }
  $script:Form.ShowInTaskbar = $false
  $script:Form.Hide()
}

function Invoke-KickThemeNow {
  # Single path: prefer control plane via shared helper; fallback kick-theme-now.ps1 once-inject.
  try {
    if (Get-Command Invoke-CodexSkinControl -ErrorAction SilentlyContinue) {
      $cp = Invoke-CodexSkinControl -Action 'kick' -TimeoutMs 3500
      if ($null -ne $cp -and $cp.ok) {
        Write-SwitchLog ("kick control-plane ok ms=" + $cp.ms + " applied=" + $cp.applied)
        return [pscustomobject]@{ Ok = $true; Code = 0; Reason = 'ok'; Message = '即时生效' }
      }
    }
  } catch {
    Write-SwitchLog ("kick control-plane: " + $_.Exception.Message)
  }

  $kick = Join-Path $programRoot 'kick-theme-now.ps1'
  if (-not (Test-Path -LiteralPath $kick)) {
    return [pscustomobject]@{ Ok = $false; Code = -2; Reason = 'kick-script-missing'; Message = 'kick-theme-now.ps1 缺失' }
  }
  try {
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
      '-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass',
      '-WindowStyle','Hidden','-File',$kick
    ) -WindowStyle Hidden -Wait -PassThru
    $code = 0
    if ($null -ne $p.ExitCode) { $code = [int]$p.ExitCode }
    Write-SwitchLog ("kick script exit=" + $code)
    $reason = switch ($code) {
      0 { 'ok' }
      2 { 'no-state' }
      3 { 'incomplete-or-injector-missing' }
      4 { 'no-node' }
      5 { 'cdp-closed' }
      default { 'injector-failed' }
    }
    $message = switch ($reason) {
      'ok' { '即时生效' }
      'no-state' { '守护未初始化，请先打开 Codex' }
      'incomplete-or-injector-missing' { 'injector 状态不完整，请点 Codex 重开' }
      'no-node' { '找不到 node' }
      'cdp-closed' { 'Codex 未开启调试端口，请先打开 Codex' }
      default { "注入失败 (exit $code)" }
    }
    return [pscustomobject]@{ Ok = ($code -eq 0); Code = $code; Reason = $reason; Message = $message }
  } catch {
    Write-SwitchLog ("kick failed: " + $_.Exception.Message)
    return [pscustomobject]@{ Ok = $false; Code = -1; Reason = 'exception'; Message = $_.Exception.Message }
  }
}

# ---- single instance ----
$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$mutexName = "Local\CodexSkin.ThemePicker." + $sid
$showEventName = "Local\CodexSkin.ThemePicker.Show." + $sid
$script:Mutex = New-Object System.Threading.Mutex($false, $mutexName)
$script:ShowSignal = New-Object System.Threading.EventWaitHandle(
  $false,
  [System.Threading.EventResetMode]::AutoReset,
  $showEventName
)
$hasHandle = $false
try {
  $hasHandle = $script:Mutex.WaitOne(0)
} catch [System.Threading.AbandonedMutexException] {
  $hasHandle = $true
}
if (-not $hasHandle) {
  # 已有实例：发信号让它显示，自己退出
  [void]$script:ShowSignal.Set()
  Write-SwitchLog "another instance running; signaled show"
  $script:ShowSignal.Dispose()
  $script:Mutex.Dispose()
  exit 0
}

# Hide console if any
try {
  if (-not ("CodexSkin.ConsoleUtil" -as [type])) {
    Add-Type -Namespace CodexSkin -Name ConsoleUtil -MemberDefinition @"
using System;
using System.Runtime.InteropServices;
public class ConsoleUtil {
  [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
  }
  $hwnd = [CodexSkin.ConsoleUtil]::GetConsoleWindow()
  if ($hwnd -ne [IntPtr]::Zero) { [void][CodexSkin.ConsoleUtil]::ShowWindow($hwnd, 0) }
} catch {}

try {
  Write-SwitchLog "launch start (single-instance owner)"
  Add-Type -AssemblyName System.Windows.Forms | Out-Null
  Add-Type -AssemblyName System.Drawing | Out-Null
  [System.Windows.Forms.Application]::EnableVisualStyles()

  $scriptPath = $null
  if ($PSCommandPath) { $scriptPath = $PSCommandPath }
  elseif ($MyInvocation.MyCommand.Path) { $scriptPath = $MyInvocation.MyCommand.Path }
  if (-not $scriptPath) { throw "无法解析脚本路径" }
  $programRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $scriptPath))
  Write-SwitchLog ("programRoot=" + $programRoot)

  $launcherUi = $null
  foreach ($c in @(
    (Join-Path $programRoot "lib\launcher-ui.ps1"),
    (Join-Path $programRoot "..\..\packages\core-win\launcher-ui.ps1")
  )) {
    if (Test-Path -LiteralPath $c) { $launcherUi = $c; break }
  }
  if (-not $launcherUi) { throw "找不到 launcher-ui.ps1" }
  . $launcherUi

  $stateRoot = Get-CodexSkinStateRoot
  $runtimeInfo = Resolve-CodexSkinRuntimeRoot -ProgramRoot $programRoot
  . (Join-Path $runtimeInfo.ScriptsRoot "common-windows.ps1")
  . (Join-Path $runtimeInfo.ScriptsRoot "theme-windows.ps1")

  $paths = Get-DreamSkinThemePaths -StateRoot $stateRoot
  $locked = Test-DreamSkinThemesLocked -StateRoot $stateRoot
  $active = $null
  try { $active = Read-DreamSkinTheme -ThemeDirectory $paths.Active -SkipImageMetadata } catch {}
  if ($active -and $active.Theme -and $active.Theme.name) { $activeName = [string]$active.Theme.name }
  else { $activeName = Get-CodexSkinActiveThemeLabel -StateRoot $stateRoot }
  if ($active -and $active.Theme -and $active.Theme.id) { $activeId = [string]$active.Theme.id } else { $activeId = "" }

  $saved = @()
  if (-not $locked) { $saved = @(Get-DreamSkinSavedThemes -StateRoot $stateRoot -SkipImageMetadata) }
  Write-SwitchLog ("locked=$locked themes=$($saved.Count) active=$activeName")

  $form = New-Object System.Windows.Forms.Form
  $script:Form = $form
  $form.Text = "Codex 换肤"
  $form.Size = New-Object System.Drawing.Size(460, 560)
  $form.StartPosition = "CenterScreen"
  $form.MinimizeBox = $true
  $form.MaximizeBox = $false
  $form.FormBorderStyle = "FixedSingle"
  $form.ShowInTaskbar = $true
  try { $form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10) }
  catch { $form.Font = New-Object System.Drawing.Font("Segoe UI", 10) }

  $label = New-Object System.Windows.Forms.Label
  $label.AutoSize = $false
  $label.Location = New-Object System.Drawing.Point(16, 12)
  $label.Size = New-Object System.Drawing.Size(420, 42)
  $label.Text = "当前：$activeName`n点击即生效 · 关闭/最小化隐藏到托盘 · 仅允许一个换肤窗口"
  $form.Controls.Add($label)

  $list = New-Object System.Windows.Forms.ListBox
  $list.Location = New-Object System.Drawing.Point(16, 58)
  $list.Size = New-Object System.Drawing.Size(412, 360)
  $list.IntegralHeight = $false
  $form.Controls.Add($list)

  $hint = New-Object System.Windows.Forms.Label
  $hint.Location = New-Object System.Drawing.Point(16, 426)
  $hint.Size = New-Object System.Drawing.Size(412, 22)
  $hint.ForeColor = [System.Drawing.Color]::DimGray
  $form.Controls.Add($hint)

  $btnApply = New-Object System.Windows.Forms.Button
  $btnApply.Text = "应用皮肤"
  $btnApply.Location = New-Object System.Drawing.Point(148, 460)
  $btnApply.Size = New-Object System.Drawing.Size(96, 32)
  $form.Controls.Add($btnApply)

  $btnHide = New-Object System.Windows.Forms.Button
  $btnHide.Text = "隐藏"
  $btnHide.Location = New-Object System.Drawing.Point(252, 460)
  $btnHide.Size = New-Object System.Drawing.Size(80, 32)
  $form.Controls.Add($btnHide)

  $btnExit = New-Object System.Windows.Forms.Button
  $btnExit.Text = "退出"
  $btnExit.Location = New-Object System.Drawing.Point(340, 460)
  $btnExit.Size = New-Object System.Drawing.Size(88, 32)
  $form.Controls.Add($btnExit)

  $items = New-Object "System.Collections.Generic.List[object]"
  if ($locked) {
    $hint.Text = "单皮肤锁定中 · 请先解锁主题库"
    $btnApply.Enabled = $false
  } elseif ($saved.Count -eq 0) {
    $hint.Text = "皮肤库为空 · 请运行 import-themes.ps1"
    $btnApply.Enabled = $false
  } else {
    $hint.Text = ("共 {0} 套 · 点击/双击立即换肤" -f $saved.Count)
    $selectIndex = 0
    $i = 0
    foreach ($t in ($saved | Sort-Object Name)) {
      $isActive = ($activeId -and $t.Id -and ($activeId -ieq [string]$t.Id)) -or (
        $activeName -and $t.Name -and ($activeName -ieq [string]$t.Name)
      )
      if ($isActive) { $labelText = "* " + $t.Name } else { $labelText = "  " + $t.Name }
      $entry = [pscustomobject]@{ Label = $labelText; Path = $t.Path; Name = [string]$t.Name; Id = [string]$t.Id }
      [void]$items.Add($entry)
      [void]$list.Items.Add($labelText)
      if ($isActive) { $selectIndex = $i }
      $i++
    }
    if ($list.Items.Count -gt 0) { $list.SelectedIndex = $selectIndex }
  }

  $applySelected = {
    if ($script:ApplyPending) { return }
    if ($list.SelectedIndex -lt 0 -or $list.SelectedIndex -ge $items.Count) {
      [void][System.Windows.Forms.MessageBox]::Show("请先选择一套皮肤。", "Codex 换肤")
      return
    }
    $entry = $items[$list.SelectedIndex]
    # 200ms debounce：连点合并为一次
    $script:PendingEntry = $entry
    if ($null -eq $script:ApplyDebounceTimer) {
      $script:ApplyDebounceTimer = New-Object System.Windows.Forms.Timer
      $script:ApplyDebounceTimer.Interval = 200
      $script:ApplyDebounceTimer.Add_Tick({
        $script:ApplyDebounceTimer.Stop()
        if ($null -eq $script:PendingEntry) { return }
        if ($script:ApplyPending) { return }
        $entry = $script:PendingEntry
        $script:PendingEntry = $null

        # 同一主题 800ms 内重复点击直接忽略
        if ($script:LastAppliedPath -eq $entry.Path -and ((Get-Date) - $script:LastAppliedAt).TotalMilliseconds -lt 800) {
          $hint.Text = ("已是当前皮肤：{0}" -f $entry.Name)
          return
        }

        $script:ApplyPending = $true
        $btnApply.Enabled = $false
        # Optimistic UI: mark selected immediately so click feels instant.
        for ($i = 0; $i -lt $items.Count; $i++) {
          if ($items[$i].Path -eq $entry.Path) { $mark = "* " } else { $mark = "  " }
          $items[$i].Label = $mark + $items[$i].Name
          $list.Items[$i] = $items[$i].Label
        }
        $list.SelectedIndex = [Math]::Max(0, [Array]::IndexOf(@($items | ForEach-Object { $_.Path }), $entry.Path))
        $hint.Text = ("正在应用：{0} ..." -f $entry.Name)
        $label.Text = "当前：$($entry.Name)`n写入中…"
        $form.Cursor = [System.Windows.Forms.Cursors]::AppStarting
        [System.Windows.Forms.Application]::DoEvents()
        try {
          $null = Use-DreamSkinSavedTheme -ThemeDirectory $entry.Path -StateRoot $stateRoot
          Set-DreamSkinPaused -Paused $false -StateRoot $stateRoot | Out-Null
          $hint.Text = ("已写入：{0} · 注入中…" -f $entry.Name)
          [System.Windows.Forms.Application]::DoEvents()
          $kick = Invoke-KickThemeNow
          $label.Text = "当前：$($entry.Name)`n$($kick.Message) · 可点「隐藏」收起"
          if ($kick.Ok) {
            $hint.Text = ("已切换：{0}（{1})" -f $entry.Name, $kick.Message)
            Show-StatusBalloon ("已切换：" + $entry.Name)
          } else {
            $hint.Text = ("已写入：{0} · {1} [{2}]" -f $entry.Name, $kick.Message, $kick.Reason)
            Show-StatusBalloon ("已写入：" + $entry.Name + " · " + $kick.Message)
            if (Get-Command Show-CodexSkinUserFeedback -ErrorAction SilentlyContinue) {
              $map = switch ($kick.Reason) {
                'cdp-closed' { 'cdp-closed' }
                'no-state' { 'no-state' }
                'incomplete-or-injector-missing' { 'injector-dead' }
                default { 'injector-dead' }
              }
              Show-CodexSkinUserFeedback -Code $map -Detail $kick.Message | Out-Null
            }
          }
          $script:LastAppliedPath = $entry.Path
          $script:LastAppliedAt = Get-Date
          Write-SwitchLog ("applied " + $entry.Name + " kick=" + $kick.Reason + " code=" + $kick.Code)
        } catch {
          Show-SwitchError ("切换失败：`n" + $_.Exception.Message)
          $hint.Text = "切换失败，见日志"
        } finally {
          $form.Cursor = [System.Windows.Forms.Cursors]::Default
          $btnApply.Enabled = $true
          $list.Enabled = $true
          $script:ApplyPending = $false
        }
      })
    }
    $script:ApplyDebounceTimer.Stop()
    $script:ApplyDebounceTimer.Start()
  }.GetNewClosure()

  $btnApply.Add_Click($applySelected)
  $list.Add_DoubleClick($applySelected)
  # 单击也走同一防抖路径
  $list.Add_Click({
    if ($list.SelectedIndex -ge 0) { & $applySelected }
  })

  $btnHide.Add_Click({ Hide-PickerForm })
  $btnExit.Add_Click({
    $script:AllowExit = $true
    if ($null -ne $script:Tray) {
      $script:Tray.Visible = $false
      $script:Tray.Dispose()
      $script:Tray = $null
    }
    $form.Close()
  })

  $form.Add_Resize({
    if ($form.WindowState -eq "Minimized") {
      Hide-PickerForm
      $form.WindowState = "Normal"
    }
  })
  $form.Add_FormClosing({
    param($sender, $e)
    if (-not $script:AllowExit -and $script:Tray -and $script:Tray.Visible) {
      $e.Cancel = $true
      Hide-PickerForm
    }
  })

  # tray
  $tray = New-Object System.Windows.Forms.NotifyIcon
  $script:Tray = $tray
  $tray.Text = "Codex 换肤"
  $tray.Visible = $true
  try {
    $ico = Join-Path $programRoot "codex-icon.ico"
    if (Test-Path -LiteralPath $ico) { $tray.Icon = New-Object System.Drawing.Icon($ico) }
    else { $tray.Icon = [System.Drawing.SystemIcons]::Application }
  } catch { $tray.Icon = [System.Drawing.SystemIcons]::Application }

  $menu = New-Object System.Windows.Forms.ContextMenuStrip
  $miShow = $menu.Items.Add("显示换肤面板")
  $miHide = $menu.Items.Add("隐藏面板")
  [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
  $miExit = $menu.Items.Add("退出换肤面板")
  $tray.ContextMenuStrip = $menu
  $miShow.Add_Click({ Show-PickerForm })
  $miHide.Add_Click({ Hide-PickerForm })
  $miExit.Add_Click({
    $script:AllowExit = $true
    $tray.Visible = $false
    $tray.Dispose()
    $script:Tray = $null
    $form.Close()
  })
  $tray.Add_MouseUp({
    param($sender, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
      if ($form.Visible) { Hide-PickerForm } else { Show-PickerForm }
    }
  })

  # second-launch activation timer
  $script:ShowTimer = New-Object System.Windows.Forms.Timer
  $script:ShowTimer.Interval = 250
  $script:ShowTimer.Add_Tick({
    if ($script:ShowSignal.WaitOne(0)) {
      Show-PickerForm
    }
  })
  $script:ShowTimer.Start()

  $form.Add_Shown({
    if ($StartHidden) { Hide-PickerForm }
    else { Show-PickerForm }
  })

  Write-SwitchLog "running single-instance UI"
  $ctx = New-Object System.Windows.Forms.ApplicationContext
  if (-not $StartHidden) { $form.Show() } else { Hide-PickerForm }
  $form.Add_FormClosed({ $ctx.ExitThread() })
  [System.Windows.Forms.Application]::Run($ctx)

  if ($null -ne $script:ShowTimer) { $script:ShowTimer.Stop(); $script:ShowTimer.Dispose() }
  if ($null -ne $script:Tray) { $script:Tray.Visible = $false; $script:Tray.Dispose() }
  Write-SwitchLog "exit clean"
  exit 0
} catch {
  Show-SwitchError ("换肤面板启动失败：`n" + $_.Exception.Message + "`n`n日志：" + $script:SwitchLog)
  exit 1
} finally {
  try {
    if ($script:Mutex) {
      try { $script:Mutex.ReleaseMutex() } catch {}
      $script:Mutex.Dispose()
    }
  } catch {}
  try { if ($script:ShowSignal) { $script:ShowSignal.Dispose() } } catch {}
}
