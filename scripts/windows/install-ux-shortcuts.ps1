#Requires -Version 5.1
$ErrorActionPreference = "Stop"
# UTF-8 console bootstrap (PAIN-POINTS #22). Full helper also runs when launcher-ui is dotted.
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
  $ico = Join-Path $programRoot 'codex-icon.ico'
  if (Test-Path -LiteralPath $ico) { $sc.IconLocation = "$ico,0" }
  $sc.Save()
  Write-Host ('lnk ' + $Path)
}

# 任务栏/开始菜单/桌面 Codex：优先走原生 CodexFastLaunch.exe（冷启 ~100ms）。
# 回退：exe 不在时走 powershell -File open-codex-dream-skin.ps1。
# 历史：VBS WaitOnReturn + 冷启 PS/Add-Type → 1.5-3s 卡死；直连 PS 仍有 ~3.8s 冷启。
$fastExe = Join-Path $programRoot 'CodexFastLaunch.exe'
if (Test-Path -LiteralPath $fastExe) {
  Set-Exe (Join-Path $programs 'Codex.lnk') $fastExe 'Open Codex with skin (native)'
  Set-Exe (Join-Path $desktop 'Codex.lnk') $fastExe 'Open Codex with skin (native)'
} else {
  Set-Ps (Join-Path $programs 'Codex.lnk') (Join-Path $programRoot 'open-codex-dream-skin.ps1') '-Port 9335 -NoPrompt' 'Open Codex with skin'
  Set-Ps (Join-Path $desktop 'Codex.lnk') (Join-Path $programRoot 'open-codex-dream-skin.ps1') '-Port 9335 -NoPrompt' 'Open Codex with skin'
}
Set-Vbs (Join-Path $programs ($switchName + '.lnk')) 'launch-switch-theme.vbs' 'Switch theme'
Set-Vbs (Join-Path $desktop ($switchName + '.lnk')) 'launch-switch-theme.vbs' 'Switch theme'
Set-Ps (Join-Path $advanced 'check-and-fix.lnk') (Join-Path $programRoot 'check-and-fix.ps1') '-Port 9335 -Quiet' 'Repair'
Set-Ps (Join-Path $advanced 'post-update.lnk') (Join-Path $programRoot 'post-update-regression.ps1') '-Port 9335' 'Regression'
Write-Host ('OK advanced=' + $advancedName + ' switch=' + $switchName)
