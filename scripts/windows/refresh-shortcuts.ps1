$ErrorActionPreference = "Stop"
$programRoot = Join-Path $env:LOCALAPPDATA "Programs\CodexDreamSkin"
$programs = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
$desktop = [Environment]::GetFolderPath("Desktop")
$ps = (Get-Command powershell.exe).Source
$shell = New-Object -ComObject WScript.Shell
$ico = Join-Path $programRoot "codex-icon.ico"

function New-Sc([string]$path, [string]$argumentList, [string]$desc, [int]$windowStyle = 7) {
  $sc = $shell.CreateShortcut($path)
  $sc.TargetPath = $ps
  $sc.Arguments = $argumentList
  $sc.WorkingDirectory = $programRoot
  $sc.WindowStyle = $windowStyle
  $sc.Description = $desc
  if (Test-Path -LiteralPath $ico) { $sc.IconLocation = "$ico,0" }
  $sc.Save()
  Write-Host "OK $path"
}

$open = "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File `"$programRoot\open-codex-dream-skin.ps1`" -Port 9335"
$switch = "-NoProfile -STA -ExecutionPolicy RemoteSigned -File `"$programRoot\switch-theme-ui.ps1`""
$manage = "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File `"$programRoot\launch-dream-skin.ps1`" -Port 9335 -ShowMenu"
$fix = "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File `"$programRoot\check-and-fix.ps1`" -Port 9335"
$update = "-NoProfile -ExecutionPolicy RemoteSigned -File `"$programRoot\post-update-regression.ps1`" -Port 9335 -Repair"

New-Sc (Join-Path $programs "Codex.lnk") $open "Open Codex with skin"
New-Sc (Join-Path $desktop "Codex.lnk") $open "Open Codex with skin"
New-Sc (Join-Path $programs "Codex 换肤.lnk") $switch "Switch theme UI" 1
New-Sc (Join-Path $desktop "Codex 换肤.lnk") $switch "Switch theme UI" 1
New-Sc (Join-Path $programs "Codex Skin 管理.lnk") $manage "Tray manager"
New-Sc (Join-Path $programs "Codex 皮肤修复.lnk") $fix "Repair skin"
New-Sc (Join-Path $programs "Codex 更新回归.lnk") $update "Post-update regression" 1

$usagePath = Join-Path $programs "Codex Skin 使用说明.lnk"
$sc = $shell.CreateShortcut($usagePath)
$sc.TargetPath = Join-Path $programRoot "使用说明.md"
$sc.WorkingDirectory = $programRoot
$sc.Description = "Usage"
$sc.Save()
Write-Host "OK $usagePath"
Write-Host "Done."
