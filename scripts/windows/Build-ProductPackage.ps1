#Requires -Version 5.1
<#
.SYNOPSIS
  Build a portable Codex Dream Skin product package (zip) from the repo.

.DESCRIPTION
  Produces dist/CodexDreamSkin-<version>-win-x64/ with:
    Install.ps1 / Uninstall.ps1 / README.txt / package-meta.json / payload/

  Version authority (ADR 0003):
    1) -Version parameter (required if repo token is still __SKIN_VERSION__)
    2) else stamped SKIN_VERSION_TOKEN already in packages/runtime (post-publish)
  No silent default like "1.3.25".

  Product package is a *distribution* path that copies already-stamped (or
  -Version-stamped) runtime into a zip. Daily developer path remains
  publish-runtime.ps1 -Version (sole write-back into the git tree).
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

function Get-StampedRuntimeToken([string]$Root) {
  $inj = Join-Path $Root "packages\runtime\scripts\injector.mjs"
  if (-not (Test-Path -LiteralPath $inj)) { return $null }
  $m = Select-String -Path $inj -Pattern 'SKIN_VERSION_TOKEN = "([^"]+)"' | Select-Object -First 1
  if (-not $m) { return $null }
  $v = $m.Matches[0].Groups[1].Value
  if ($v -match '^__') { return $null }
  return $v
}

if (-not $Version) {
  $Version = Get-StampedRuntimeToken -Root $RepoRoot
}
if (-not $Version) {
  throw @"
Version required (ADR 0003).
  Pass -Version x.y.z
  OR publish first so packages/runtime SKIN_VERSION_TOKEN is stamped (not __SKIN_VERSION__).
"@
}
if ($Version -notmatch '^\d+\.\d+\.\d+') {
  throw "Version must look like semver x.y.z (got: $Version)"
}

if (-not $OutDir) { $OutDir = Join-Path $RepoRoot "dist" }

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

# Tools + VBS entry helpers (#18 Codex 换肤 needs launch-switch-theme.vbs)
$tools = Join-Path $payload "tools"
New-Item -ItemType Directory -Force -Path $tools | Out-Null
foreach ($name in @(
  "install-all-skin-launchers.ps1",
  "install-ux-shortcuts.ps1",
  "generate-theme-thumbs.ps1",
  "probe-session-dom.mjs",
  "import-themes.ps1",
  "launch-switch-theme.vbs",
  "launch-codex-skin.vbs",
  "launch-switch-theme.js"
)) {
  $src = Join-Path $RepoRoot ("scripts\windows\" + $name)
  if (Test-Path -LiteralPath $src) { Copy-Item $src (Join-Path $tools $name) -Force }
}

# User-facing usage doc for install-ux "使用说明" shortcut
# Use codepoint labels so Windows PowerShell 5.1 (often GBK source decode) does not mojibake filenames.
$docsDir = Join-Path $payload "docs"
New-Item -ItemType Directory -Force -Path $docsDir | Out-Null
$usageSrc = Join-Path $RepoRoot "docs\usage.md"
$usageCnName = -join ([char]0x4F7F, [char]0x7528, [char]0x8BF4, [char]0x660E) + ".md" # 使用说明.md
if (Test-Path -LiteralPath $usageSrc) {
  Copy-Item $usageSrc (Join-Path $docsDir "usage.md") -Force
  Copy-Item $usageSrc (Join-Path $docsDir $usageCnName) -Force
  Write-Host ("  + docs/usage.md + docs/" + $usageCnName)
} else {
  Write-Warning "docs/usage.md missing — install-ux usage shortcut will skip"
}

# Native exe if built
$nativeSrc = Join-Path $RepoRoot "apps\native\CodexFastLaunch\bin\CodexFastLaunch.exe"
$nativeDstDir = Join-Path $payload "native"
New-Item -ItemType Directory -Force -Path $nativeDstDir | Out-Null
if (-not (Test-Path -LiteralPath $nativeSrc)) {
  $installed = Join-Path $env:LOCALAPPDATA "Programs\CodexDreamSkin\CodexFastLaunch.exe"
  if (Test-Path -LiteralPath $installed) { $nativeSrc = $installed }
}
if (Test-Path -LiteralPath $nativeSrc) {
  Copy-Item $nativeSrc (Join-Path $nativeDstDir "CodexFastLaunch.exe") -Force
  Write-Host "  + CodexFastLaunch.exe"
} else {
  Write-Warning "CodexFastLaunch.exe missing — package will use PS open path"
}

# VERSION file in runtime for installer (package authority inside the zip)
Set-Content -Path (Join-Path $payload "runtime\VERSION") -Value $Version -Encoding ascii -NoNewline

# Stamp SKIN_VERSION_TOKEN only inside the *package payload* (not the git tree).
# Git tree write-back remains publish-runtime.ps1 exclusive (ADR 0003).
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
$softReattachSrc = Join-Path $RepoRoot "scripts\windows\soft-reattach.ps1"
if (-not (Test-Path -LiteralPath $installSrc)) { throw "Missing Install-Product.ps1" }
Copy-Item $installSrc (Join-Path $stage "Install.ps1") -Force
if (Test-Path -LiteralPath $uninstallSrc) {
  Copy-Item $uninstallSrc (Join-Path $stage "Uninstall.ps1") -Force
}
# Install.ps1 dots soft-reattach.ps1 from same directory (product root).
if (Test-Path -LiteralPath $softReattachSrc) {
  Copy-Item $softReattachSrc (Join-Path $stage "soft-reattach.ps1") -Force
}

$meta = [ordered]@{
  schemaVersion = 1
  product = "CodexDreamSkin"
  version = $Version
  platform = "win-x64"
  builtAt = (Get-Date).ToUniversalTime().ToString("o")
  sourceCommit = ""
  themeCount = @(Get-ChildItem (Join-Path $payload "themes") -Directory -ErrorAction SilentlyContinue).Count
  versionAuthority = "Build-ProductPackage -Version or stamped runtime token; payload stamped only (git tree via publish-runtime.ps1)"
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

Install
  powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1

Uninstall
  powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
  (add -RemoveState to wipe user themes/active-theme)

Prerequisites
  - Microsoft Store OpenAI Codex
  - Node.js 20+ (import-themes / apply / doctor)

After install
  1. Click taskbar / Start Menu Codex (CodexFastLaunch)
  2. Switch theme: desktop "Codex 换肤" or F6
  3. Tools: Start Menu -> Codex 工具 (repair / post-update / usage)
  4. CLI:
     node "%LOCALAPPDATA%\Programs\CodexDreamSkin\cli\packages\core\cli.mjs" list
     node "...\cli.mjs" apply --theme genshin-night

NOTE
  Store tile bare launch cannot be rewritten (Windows package AUMID). Prefer the taskbar pin.
  Version in this zip: $Version (package-meta + runtime/VERSION + stamped token in payload).
  Developer publish path remains: publish-runtime.ps1 -Version (writes git tree).

Themes: $($meta.themeCount)
Built: $($meta.builtAt)
Commit: $($meta.sourceCommit)
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
