#Requires -Version 5.1
<#
.SYNOPSIS
  安装/收敛用户可见快捷方式（PAIN-POINTS #18 唯一源）。

.DESCRIPTION
  日常入口（桌面 / 开始菜单 / 任务栏 / 开机启动）：
    Codex · ChatGPT  → CodexFastLaunch.exe（无 native 时回退 open-*.ps1）
    Codex 换肤       → launch-switch-theme.vbs

  工具（仅开始菜单「Codex 工具」文件夹，不放桌面）：
    皮肤修复         → check-and-fix.ps1（可见窗口，不用 -Quiet）
    商店更新后修复   → post-update-regression.ps1 -Repair
    使用说明         → 使用说明.md / USAGE.md

  会清理的误导入口：
    - 桌面/开始菜单重复的「Codex Skin.lnk」（与 Codex 同目标）
    - 旧「Codex Skin 高级」文件夹（改名后迁到「Codex 工具」）
    - refresh-shortcuts 曾铺的「Codex Skin 管理 / 皮肤修复 / 更新回归」顶层散落项
    - 名称含 heige / Codex Studio 的残留快捷方式（PAIN #20）

  不做：改写微软商店磁贴 / Store AUMID 包激活（PAIN #21，OS 硬限）。
#>
$ErrorActionPreference = "Stop"
try {
  & chcp.com 65001 | Out-Null
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  try { [Console]::OutputEncoding = $utf8 } catch {}
  try { [Console]::InputEncoding = $utf8 } catch {}
  $OutputEncoding = $utf8
} catch {}

$programRoot = Join-Path $env:LOCALAPPDATA 'Programs\CodexDreamSkin'
$programs = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$desktop = [Environment]::GetFolderPath('Desktop')
$startup = Join-Path $programs 'Startup'
$taskbar = Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'

# Chinese labels via codepoints only (no CJK in this block) so PS 5.1
# never mis-parses UTF-8-without-BOM source as system ANSI/GBK.
$huanfu = -join ([char]0x6362, [char]0x80A4)
$gongju = -join ([char]0x5DE5, [char]0x5177)
$xiufu = -join ([char]0x76AE, [char]0x80A4, [char]0x4FEE, [char]0x590D)
$postUpdate = -join ([char]0x5546, [char]0x5E97, [char]0x66F4, [char]0x65B0, [char]0x540E, [char]0x4FEE, [char]0x590D)
$shuoming = -join ([char]0x4F7F, [char]0x7528, [char]0x8BF4, [char]0x660E)

$toolsName = 'Codex ' + $gongju
$toolsDir = Join-Path $programs $toolsName
$switchName = 'Codex ' + $huanfu
$repairName = $xiufu
$postName = $postUpdate
$usageName = $shuoming

$shell = New-Object -ComObject WScript.Shell
$ps = (Get-Command powershell.exe).Source
$wscript = Join-Path $env:SystemRoot 'System32\wscript.exe'
$fastExe = Join-Path $programRoot 'CodexFastLaunch.exe'
$openPs1 = Join-Path $programRoot 'open-codex-dream-skin.ps1'
$ico = Join-Path $programRoot 'codex-icon.ico'
$useNative = Test-Path -LiteralPath $fastExe

function Remove-LinkIfExists([string]$Path) {
  if (Test-Path -LiteralPath $Path) {
    Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    Write-Host ('rm  ' + $Path)
  }
}

function Set-Vbs([string]$Path, [string]$VbsName, [string]$Description) {
  $vbs = Join-Path $programRoot $VbsName
  if (-not (Test-Path -LiteralPath $vbs)) { Write-Host ('skip ' + $VbsName); return }
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $sc = $shell.CreateShortcut($Path)
  $sc.TargetPath = $wscript
  $sc.Arguments = '//B //Nologo "' + $vbs + '"'
  $sc.WorkingDirectory = $programRoot
  $sc.WindowStyle = 7
  $sc.Description = $Description
  if (Test-Path -LiteralPath $ico) { $sc.IconLocation = "$ico,0" }
  $sc.Save()
  Write-Host ('lnk ' + $Path)
}

function Set-Ps([string]$Path, [string]$FilePath, [string]$Extra, [string]$Description, [int]$WindowStyle = 1) {
  if (-not (Test-Path -LiteralPath $FilePath)) { Write-Host ('skip ' + $FilePath); return }
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $sc = $shell.CreateShortcut($Path)
  $sc.TargetPath = $ps
  # Visible Normal window for repair tools so users see PASS/FAIL (not -WindowStyle Hidden).
  $sc.Arguments = '-NoProfile -STA -ExecutionPolicy Bypass -File "' + $FilePath + '" ' + $Extra
  $sc.WorkingDirectory = $programRoot
  $sc.WindowStyle = $WindowStyle
  $sc.Description = $Description
  if (Test-Path -LiteralPath $ico) { $sc.IconLocation = "$ico,0" }
  $sc.Save()
  Write-Host ('lnk ' + $Path)
}

function Set-Exe([string]$Path, [string]$ExePath, [string]$Description) {
  if (-not (Test-Path -LiteralPath $ExePath)) { Write-Host ('skip ' + $ExePath); return }
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $sc = $shell.CreateShortcut($Path)
  $sc.TargetPath = $ExePath
  $sc.Arguments = ''
  $sc.WorkingDirectory = $programRoot
  $sc.WindowStyle = 7
  $sc.Description = $Description
  if (Test-Path -LiteralPath $ico) { $sc.IconLocation = "$ico,0" }
  $sc.Save()
  Write-Host ('lnk ' + $Path)
}

function Set-DailyCodex([string]$Path, [string]$Description) {
  if ($useNative) {
    Set-Exe $Path $fastExe $Description
  } else {
    Set-Ps $Path $openPs1 '-Port 9335 -NoPrompt' $Description 7
  }
}

function Set-Doc([string]$Path, [string]$DocPath, [string]$Description) {
  if (-not (Test-Path -LiteralPath $DocPath)) { Write-Host ('skip doc ' + $DocPath); return }
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $sc = $shell.CreateShortcut($Path)
  $sc.TargetPath = $DocPath
  $sc.WorkingDirectory = $programRoot
  $sc.Description = $Description
  $sc.Save()
  Write-Host ('lnk ' + $Path)
}

# --- 1) Remove misleading / duplicate daily entries (#18 + #20) ----------------
$staleNames = @(
  'Codex Skin.lnk',
  'Codex Skin 管理.lnk',
  'Codex 皮肤修复.lnk',
  'Codex 更新回归.lnk',
  'Codex Skin 使用说明.lnk',
  'Codex Studio.lnk',
  'heige.lnk',
  'Heige Studio.lnk',
  'Codex Heige.lnk'
)
foreach ($root in @($programs, $desktop)) {
  if (-not (Test-Path -LiteralPath $root)) { continue }
  foreach ($n in $staleNames) {
    Remove-LinkIfExists (Join-Path $root $n)
  }
  # residual names containing heige / studio (case-insensitive)
  Get-ChildItem -LiteralPath $root -Filter '*.lnk' -ErrorAction SilentlyContinue |
    Where-Object { $_.BaseName -match '(?i)heige|codex\s*studio' } |
    ForEach-Object { Remove-LinkIfExists $_.FullName }
}

# Old advanced folder → tools folder
Get-ChildItem -LiteralPath $programs -Directory -ErrorAction SilentlyContinue |
  Where-Object {
    $_.Name -like 'Codex Skin*' -or
    $_.Name -eq 'Codex 高级' -or
    ($_.Name -like 'Codex *' -and $_.Name -match '高级|Advanced' -and $_.Name -ne $toolsName)
  } |
  ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ('rmdir ' + $_.Name)
  }

# --- 2) Daily entries ---------------------------------------------------------
Set-DailyCodex (Join-Path $programs 'Codex.lnk') 'Open Codex with skin'
Set-DailyCodex (Join-Path $programs 'ChatGPT.lnk') 'Open Codex with skin'
Set-DailyCodex (Join-Path $desktop 'Codex.lnk') 'Open Codex with skin'
Set-DailyCodex (Join-Path $desktop 'ChatGPT.lnk') 'Open Codex with skin'
Set-Vbs (Join-Path $programs ($switchName + '.lnk')) 'launch-switch-theme.vbs' 'Switch theme'
Set-Vbs (Join-Path $desktop ($switchName + '.lnk')) 'launch-switch-theme.vbs' 'Switch theme'

if (Test-Path -LiteralPath $taskbar) {
  # Only rewrite if Codex/ChatGPT pins already exist — don't force-create taskbar pins.
  foreach ($name in @('Codex.lnk', 'ChatGPT.lnk')) {
    $p = Join-Path $taskbar $name
    if (Test-Path -LiteralPath $p) {
      Set-DailyCodex $p 'Open Codex with skin'
    }
  }
}

# Startup auto-launch disabled (2026-07-23): remove if present; do not recreate.
if (Test-Path -LiteralPath $startup) {
  $startupLnk = Join-Path $startup 'Codex Dream Skin - Auto Launch.lnk'
  if (Test-Path -LiteralPath $startupLnk) {
    Remove-LinkIfExists $startupLnk
    Write-Host ("RM   Startup auto-launch (disabled): " + $startupLnk)
  }
}

# --- 3) Tools folder only (not desktop) --------------------------------------
New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
# clear any leftover junk inside tools dir first
Get-ChildItem -LiteralPath $toolsDir -Filter '*.lnk' -ErrorAction SilentlyContinue |
  ForEach-Object { Remove-LinkIfExists $_.FullName }

Set-Ps (Join-Path $toolsDir ($repairName + '.lnk')) `
  (Join-Path $programRoot 'check-and-fix.ps1') `
  '-Port 9335' `
  'Repair skin injector / reattach' `
  1

Set-Ps (Join-Path $toolsDir ($postName + '.lnk')) `
  (Join-Path $programRoot 'post-update-regression.ps1') `
  '-Port 9335 -Repair' `
  'After Codex Store update: rebind + reattach + smoke' `
  1

$usageDoc = @(
  (Join-Path $programRoot '使用说明.md'),
  (Join-Path $programRoot 'USAGE.md')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if ($usageDoc) {
  Set-Doc (Join-Path $toolsDir ($usageName + '.lnk')) $usageDoc 'Codex Skin usage'
}

# Also rebind bare Codex/ChatGPT launchers if install-all is present (idempotent).
$rebind = Join-Path $programRoot 'install-all-skin-launchers.ps1'
if (-not (Test-Path -LiteralPath $rebind)) {
  $rebind = Join-Path $PSScriptRoot 'install-all-skin-launchers.ps1'
}
if (Test-Path -LiteralPath $rebind) {
  try {
    Write-Host 'rebinding bare Codex/ChatGPT shortcuts via install-all-skin-launchers.ps1'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $rebind | Out-Host
  } catch {
    Write-Warning ("install-all-skin-launchers: " + $_.Exception.Message)
  }
}

Write-Host ('OK daily=Codex/ChatGPT/' + $switchName + ' tools=' + $toolsName)
Write-Host 'NOTE Store tile / package AUMID bare launch cannot be rewritten (OS limit). Prefer taskbar Codex pin.'
