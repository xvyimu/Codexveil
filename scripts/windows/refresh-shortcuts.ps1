#Requires -Version 5.1
<#
.SYNOPSIS
  兼容入口：转发到 install-ux-shortcuts.ps1（PAIN #18 唯一源）。

.DESCRIPTION
  旧版会在开始菜单顶层铺「管理 / 皮肤修复 / 更新回归」等散落项。
  现统一由 install-ux-shortcuts.ps1 管理：日常入口 + 「Codex 工具」文件夹。
#>
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$ux = Join-Path $here "install-ux-shortcuts.ps1"
if (-not (Test-Path -LiteralPath $ux)) {
  throw "install-ux-shortcuts.ps1 missing next to refresh-shortcuts.ps1"
}
Write-Host "refresh-shortcuts -> install-ux-shortcuts.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ux
exit $LASTEXITCODE
