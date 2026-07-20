#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$programRoot = Join-Path $env:LOCALAPPDATA 'Programs\CodexDreamSkin'
$programs = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$desktop = [Environment]::GetFolderPath('Desktop')
$huanfu = -join ([char]0x6362, [char]0x80A4)
$gaoji = -join ([char]0x9AD8, [char]0x7EA7)
$advancedName = 'Codex Skin ' + $gaoji
$switchName = 'Codex ' + $huanfu
$advanced = Join-Path $programs $advancedName
$shell = New-Object -ComObject WScript.Shell
$ps = (Get-Command powershell.exe).Source
$wscript = Join-Path $env:SystemRoot 'System32\wscript.exe'

# remove broken advanced folders
Get-ChildItem -LiteralPath $programs -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -like 'Codex Skin*' -and $_.Name -ne $advancedName } |
  ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue; Write-Host ('removed ' + $_.Name) }

New-Item -ItemType Directory -Force -Path $advanced | Out-Null

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
  $sc.Save()
  Write-Host ('lnk ' + $Path)
}
function Set-Ps([string]$Path, [string]$FilePath, [string]$Extra, [string]$Description) {
  if (-not (Test-Path -LiteralPath $FilePath)) { Write-Host ('skip ' + $FilePath); return }
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $sc = $shell.CreateShortcut($Path)
  $sc.TargetPath = $ps
  $sc.Arguments = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $FilePath + '" ' + $Extra
  $sc.WorkingDirectory = $programRoot
  $sc.WindowStyle = 7
  $sc.Description = $Description
  $sc.Save()
  Write-Host ('lnk ' + $Path)
}

# 任务栏/开始菜单/桌面 Codex：直接 powershell.exe -File open-codex-dream-skin.ps1
#
# 之前走 wscript → launch-codex-skin.vbs → powershell 有两个问题：
#   - VBS 里 TryFocusScript 用 WaitOnReturn=True 阻塞 wscript 主线程，冷启动 PS +
#     Add-Type C# 焦点类 ~700-1500ms/次，累积 1.5-3s，用户感觉"任务栏卡死"。
#   - VBS 的 /open-healthy 快路径其实和 open-codex-dream-skin.ps1 里的一模一样，
#     PS 版本命中控制面同样 ~200ms。VBS 是纯多余一层。
# 直连 PS 后，控制面命中 → 快路径 exit 0；miss → 常规 open。
Set-Ps (Join-Path $programs 'Codex.lnk') (Join-Path $programRoot 'open-codex-dream-skin.ps1') '-Port 9335 -NoPrompt' 'Open Codex with skin'
Set-Ps (Join-Path $desktop 'Codex.lnk') (Join-Path $programRoot 'open-codex-dream-skin.ps1') '-Port 9335 -NoPrompt' 'Open Codex with skin'
Set-Vbs (Join-Path $programs ($switchName + '.lnk')) 'launch-switch-theme.vbs' 'Switch theme'
Set-Vbs (Join-Path $desktop ($switchName + '.lnk')) 'launch-switch-theme.vbs' 'Switch theme'
Set-Ps (Join-Path $advanced 'check-and-fix.lnk') (Join-Path $programRoot 'check-and-fix.ps1') '-Port 9335 -Quiet' 'Repair'
Set-Ps (Join-Path $advanced 'post-update.lnk') (Join-Path $programRoot 'post-update-regression.ps1') '-Port 9335' 'Regression'
Write-Host ('OK advanced=' + $advancedName + ' switch=' + $switchName)
