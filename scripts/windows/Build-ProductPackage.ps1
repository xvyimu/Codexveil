#Requires -Version 5.1
<#
.SYNOPSIS
  Build a portable Codex Dream Skin product package (zip) from the repo.

.DESCRIPTION
  Produces dist/CodexDreamSkin-<version>-win-x64/ with:
    Install.ps1
    Uninstall.ps1
    README.txt
    package-meta.json
    payload/ ...

  Then zips it to dist/CodexDreamSkin-<version>-win-x64.zip
#>
[CmdletBinding()]
param(
  [string]$RepoRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
  [string]$Version = "",
  [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
try {
  & chcp.com 65001 | Out-Null
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  try { [Console]::OutputEncoding = $utf8 } catch {}
  $OutputEncoding = $utf8
} catch {}

if (-not $Version) {
  # Prefer stamped runtime token, then current.json, then default
  $inj = Join-Path $RepoRoot "packages\runtime\scripts\injector.mjs"
  if (Test-Path -LiteralPath $inj) {
    $m = Select-String -Path $inj -Pattern 'SKIN_VERSION_TOKEN = "([^"]+)"' | Select-Object -First 1
    if ($m -and $m.Matches[0].Groups[1].Value -notmatch '^__') {
      $Version = $m.Matches[0].Groups[1].Value
    }
  }
}
if (-not $Version) { $Version = "1.3.25" }
if (-not $OutDir) { $OutDir = Join-Path $RepoRoot "dist" }

$stamp = Get-Date -Format "yyyyMMdd"
$folderName = "CodexDreamSkin-$Version-win-x64"
$stage = Join-Path $OutDir $folderName
$payload = Join-Path $stage "payload"

Write-Host "Building product package $folderName"
if (Test-Path -LiteralPath $stage) {
  Remove-Item -LiteralPath $stage -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $payload | Out-Null

function Copy-Tree([string]$Src, [string]$Dst) {
  if (-not (Test-Path -LiteralPath $Src)) { throw "Missing: $Src" }
  New-Item -ItemType Directory -Force -Path $Dst | Out-Null
  Copy-Item -Path (Join-Path $Src "*") -Destination $Dst -Recurse -Force
}

# Core payload
Copy-Tree (Join-Path $RepoRoot "packages\runtime") (Join-Path $payload "runtime")
Copy-Tree (Join-Path $RepoRoot "packages\core-win") (Join-Path $payload "core-win")
Copy-Tree (Join-Path $RepoRoot "apps\launcher") (Join-Path $payload "launcher")
Copy-Tree (Join-Path $RepoRoot "themes") (Join-Path $payload "themes")
Copy-Tree (Join-Path $RepoRoot "packages\core") (Join-Path $payload "packages\core")
Copy-Tree (Join-Path $RepoRoot "packages\themes") (Join-Path $payload "packages\themes")

# Tools
$tools = Join-Path $payload "tools"
New-Item -ItemType Directory -Force -Path $tools | Out-Null
foreach ($name in @(
  "install-all-skin-launchers.ps1",
  "install-ux-shortcuts.ps1",
  "generate-theme-thumbs.ps1",
  "probe-session-dom.mjs",
  "import-themes.ps1"
)) {
  $src = Join-Path $RepoRoot ("scripts\windows\" + $name)
  if (Test-Path -LiteralPath $src) { Copy-Item $src (Join-Path $tools $name) -Force }
}

# Native exe if built
$nativeSrc = Join-Path $RepoRoot "apps\native\CodexFastLaunch\bin\CodexFastLaunch.exe"
$nativeDstDir = Join-Path $payload "native"
New-Item -ItemType Directory -Force -Path $nativeDstDir | Out-Null
if (-not (Test-Path -LiteralPath $nativeSrc)) {
  # fall back to installed copy
  $installed = Join-Path $env:LOCALAPPDATA "Programs\CodexDreamSkin\CodexFastLaunch.exe"
  if (Test-Path -LiteralPath $installed) { $nativeSrc = $installed }
}
if (Test-Path -LiteralPath $nativeSrc) {
  Copy-Item $nativeSrc (Join-Path $nativeDstDir "CodexFastLaunch.exe") -Force
  Write-Host "  + CodexFastLaunch.exe"
} else {
  Write-Warning "CodexFastLaunch.exe missing — package will use PS open path"
}

# VERSION file in runtime for installer
Set-Content -Path (Join-Path $payload "runtime\VERSION") -Value $Version -Encoding ascii -NoNewline

# Ensure SKIN_VERSION_TOKEN in payload is stamped (or leave as-is; Install stamps again)
foreach ($rel in @("runtime\scripts\injector.mjs", "runtime\assets\renderer-inject.js")) {
  $t = Join-Path $payload $rel
  if (-not (Test-Path -LiteralPath $t)) { continue }
  $text = [System.IO.File]::ReadAllText($t)
  $text = [regex]::Replace($text, 'const SKIN_VERSION_TOKEN = "[^"]*";', ('const SKIN_VERSION_TOKEN = "' + $Version + '";'))
  [System.IO.File]::WriteAllText($t, $text, [System.Text.UTF8Encoding]::new($false))
}

# Install / Uninstall wrappers at package root
$installSrc = Join-Path $RepoRoot "scripts\windows\Install-Product.ps1"
$uninstallSrc = Join-Path $RepoRoot "scripts\windows\Uninstall-Product.ps1"
if (-not (Test-Path -LiteralPath $installSrc)) { throw "Missing Install-Product.ps1" }
Copy-Item $installSrc (Join-Path $stage "Install.ps1") -Force
if (Test-Path -LiteralPath $uninstallSrc) {
  Copy-Item $uninstallSrc (Join-Path $stage "Uninstall.ps1") -Force
}

$meta = [ordered]@{
  schemaVersion = 1
  product = "CodexDreamSkin"
  version = $Version
  platform = "win-x64"
  builtAt = (Get-Date).ToUniversalTime().ToString("o")
  sourceCommit = ""
  themeCount = @(Get-ChildItem (Join-Path $payload "themes") -Directory -ErrorAction SilentlyContinue).Count
  requires = @("Windows 10/11", "Node.js >= 20 (for CLI)", "OpenAI Codex Store package")
}
try {
  Push-Location $RepoRoot
  $meta.sourceCommit = (git rev-parse --short HEAD 2>$null)
} catch {} finally { Pop-Location }
[System.IO.File]::WriteAllText(
  (Join-Path $stage "package-meta.json"),
  (($meta | ConvertTo-Json -Depth 5) + "`n"),
  [System.Text.UTF8Encoding]::new($false)
)

$readme = @"
Codex Dream Skin $Version (Windows x64)
======================================

一键安装（推荐）
  右键 Install.ps1 → 使用 PowerShell 运行
  或在终端：
    powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1

卸载
  powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1

前提
  - 已安装微软商店版 OpenAI Codex
  - 本机有 Node.js 20+（用于导入主题 / apply / doctor）

安装后
  1. 点任务栏 / 开始菜单 Codex
  2. 换肤：桌面「Codex 换肤」或 F6，或
     node "%LOCALAPPDATA%\Programs\CodexDreamSkin\cli\packages\core\cli.mjs" list
     node "...\cli.mjs" apply --theme genshin-night

包内主题：约 $($meta.themeCount) 套（含 preset-arina-hashimoto）
构建时间：$($meta.builtAt)
提交：$($meta.sourceCommit)
"@
[System.IO.File]::WriteAllText((Join-Path $stage "README.txt"), $readme, [System.Text.UTF8Encoding]::new($true))

# Zip
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$zipPath = Join-Path $OutDir ($folderName + ".zip")
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Compress-Archive -Path $stage -DestinationPath $zipPath -CompressionLevel Optimal

$zipItem = Get-Item $zipPath
$stageSize = (Get-ChildItem $stage -Recurse -File | Measure-Object Length -Sum).Sum
Write-Host ""
Write-Host "Package ready:"
Write-Host "  folder : $stage  ($([math]::Round($stageSize/1MB, 1)) MB)"
Write-Host "  zip    : $zipPath  ($([math]::Round($zipItem.Length/1MB, 1)) MB)"
Write-Host "  version: $Version  themes: $($meta.themeCount)"
