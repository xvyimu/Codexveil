#Requires -Version 5.1
<#
.SYNOPSIS
  Install Codex Dream Skin from a product package (or repo layout).

.DESCRIPTION
  Layout expected next to this script OR under -PackageRoot:

    Install-Product.ps1          (this file; may also be named Install.ps1)
    payload/
      runtime/                   packages/runtime (scripts + assets + core)
      core-win/                  packages/core-win
      launcher/                  apps/launcher
      themes/                    themes/* (heige source, 11 sets)
      packages/
        core/                    CLI + discover/cdp/state
        themes/                  schema/store/adapter
      native/                    optional CodexFastLaunch.exe
      tools/                     install-ux-shortcuts.ps1, install-all-skin-launchers.ps1, ...

  Writes to:
    %LOCALAPPDATA%\Programs\CodexDreamSkin   (program root)
    %LOCALAPPDATA%\CodexDreamSkin            (state / themes / active-theme)

  Prerequisites: Windows 10/11, Node.js ≥20 on PATH (for CLI import/apply),
  official OpenAI Codex Store package for daily skin injection.
#>
[CmdletBinding()]
param(
  [string]$PackageRoot = $PSScriptRoot,
  [string]$Version = "",
  [switch]$SkipShortcuts,
  [switch]$SkipImportThemes,
  [switch]$NoStart
)

$ErrorActionPreference = "Stop"
try {
  & chcp.com 65001 | Out-Null
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  try { [Console]::OutputEncoding = $utf8 } catch {}
  try { [Console]::InputEncoding = $utf8 } catch {}
  $OutputEncoding = $utf8
} catch {}

function Resolve-PayloadRoot([string]$Root) {
  $candidates = @(
    (Join-Path $Root "payload"),
    $Root
  )
  foreach ($c in $candidates) {
    $rt = Join-Path $c "runtime"
    if (Test-Path -LiteralPath (Join-Path $rt "scripts\injector.mjs")) { return $c }
    if (Test-Path -LiteralPath (Join-Path $rt "scripts\injector.mjs".Replace("\", [IO.Path]::DirectorySeparatorChar))) { return $c }
  }
  # Repo layout fallback: package root is repo root
  $repoRuntime = Join-Path $Root "packages\runtime"
  if (Test-Path -LiteralPath (Join-Path $repoRuntime "scripts\injector.mjs")) {
    return $Root
  }
  throw "Cannot find runtime payload under $Root (expected payload/runtime or packages/runtime)."
}

function Copy-Tree([string]$Src, [string]$Dst) {
  if (-not (Test-Path -LiteralPath $Src)) { throw "Missing source: $Src" }
  New-Item -ItemType Directory -Force -Path $Dst | Out-Null
  Copy-Item -Path (Join-Path $Src "*") -Destination $Dst -Recurse -Force
}

function Get-TokenFromInjector([string]$InjectorPath) {
  if (-not (Test-Path -LiteralPath $InjectorPath)) { return $null }
  $m = Select-String -Path $InjectorPath -Pattern 'SKIN_VERSION_TOKEN = "([^"]+)"' | Select-Object -First 1
  if (-not $m) { return $null }
  $v = $m.Matches[0].Groups[1].Value
  if ($v -match '^__') { return $null }
  return $v
}

function Get-PackageVersion([string]$Payload, [string]$Explicit) {
  # ADR 0003: never invent a hardcoded default like "1.3.25".
  if ($Explicit) {
    if ($Explicit -notmatch '^\d+\.\d+\.\d+') {
      throw "Version must look like semver x.y.z (got: $Explicit)"
    }
    return $Explicit
  }
  $meta = Join-Path $PackageRoot "package-meta.json"
  if (Test-Path -LiteralPath $meta) {
    try {
      $m = Get-Content -LiteralPath $meta -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($m.version -and "$($m.version)" -notmatch '^__') { return [string]$m.version }
    } catch {}
  }
  foreach ($verFile in @(
    (Join-Path $Payload "runtime\VERSION"),
    (Join-Path $PackageRoot "packages\runtime\VERSION")
  )) {
    if (Test-Path -LiteralPath $verFile) {
      $v = (Get-Content -LiteralPath $verFile -Raw).Trim()
      if ($v -and $v -notmatch '^__') { return $v }
    }
  }
  foreach ($inj in @(
    (Join-Path $Payload "runtime\scripts\injector.mjs"),
    (Join-Path $Payload "packages\runtime\scripts\injector.mjs")
  )) {
    $tok = Get-TokenFromInjector -InjectorPath $inj
    if ($tok) { return $tok }
  }
  throw @"
Cannot resolve package version (ADR 0003).
  Pass -Version x.y.z, or ship package-meta.json / payload/runtime/VERSION / stamped injector token.
  No hardcoded default is used.
"@
}

function Get-ContentHash6([string[]]$Paths) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $ms = New-Object System.IO.MemoryStream
    foreach ($p in $Paths) {
      if (-not (Test-Path -LiteralPath $p)) { continue }
      $bytes = [System.IO.File]::ReadAllBytes($p)
      $ms.Write($bytes, 0, $bytes.Length)
    }
    $ms.Position = 0
    $hash = $sha.ComputeHash($ms)
    $hex = -join ($hash | ForEach-Object { $_.ToString("x2") })
    return $hex.Substring(0, 6)
  } finally {
    $sha.Dispose()
  }
}

$payloadRoot = Resolve-PayloadRoot -Root $PackageRoot
$isRepoLayout = Test-Path -LiteralPath (Join-Path $payloadRoot "packages\runtime\scripts\injector.mjs")

if ($isRepoLayout) {
  $runtimeSrc = Join-Path $payloadRoot "packages\runtime"
  $coreWinSrc = Join-Path $payloadRoot "packages\core-win"
  $launcherSrc = Join-Path $payloadRoot "apps\launcher"
  $themesSrc = Join-Path $payloadRoot "themes"
  $corePkgSrc = Join-Path $payloadRoot "packages\core"
  $themesPkgSrc = Join-Path $payloadRoot "packages\themes"
  $toolsSrc = Join-Path $payloadRoot "scripts\windows"
  $docsSrc = Join-Path $payloadRoot "docs"
  $nativeExeSrc = Join-Path $payloadRoot "apps\native\CodexFastLaunch\bin\CodexFastLaunch.exe"
} else {
  $runtimeSrc = Join-Path $payloadRoot "runtime"
  $coreWinSrc = Join-Path $payloadRoot "core-win"
  $launcherSrc = Join-Path $payloadRoot "launcher"
  $themesSrc = Join-Path $payloadRoot "themes"
  $corePkgSrc = Join-Path $payloadRoot "packages\core"
  $themesPkgSrc = Join-Path $payloadRoot "packages\themes"
  $toolsSrc = Join-Path $payloadRoot "tools"
  $docsSrc = Join-Path $payloadRoot "docs"
  $nativeExeSrc = Join-Path $payloadRoot "native\CodexFastLaunch.exe"
}

$version = Get-PackageVersion -Payload $payloadRoot -Explicit $Version
$hashSeed = @(
  (Join-Path $runtimeSrc "scripts\injector.mjs"),
  (Join-Path $runtimeSrc "assets\renderer-inject.js"),
  (Join-Path $runtimeSrc "VERSION")
)
$hash6 = Get-ContentHash6 -Paths $hashSeed
if (-not $hash6) { $hash6 = "000000" }
$runtimeId = "$version-$hash6"

$programRoot = Join-Path $env:LOCALAPPDATA "Programs\CodexDreamSkin"
$stateRoot = Join-Path $env:LOCALAPPDATA "CodexDreamSkin"
$dest = Join-Path $programRoot "versions\$runtimeId"

Write-Host "Codex Dream Skin install"
Write-Host "  package : $PackageRoot"
Write-Host "  payload : $payloadRoot"
Write-Host "  version : $version"
Write-Host "  runtime : $runtimeId"
Write-Host "  program : $programRoot"

New-Item -ItemType Directory -Force -Path (Join-Path $dest "scripts") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $dest "assets") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $dest "core") | Out-Null
New-Item -ItemType Directory -Force -Path $stateRoot | Out-Null

# Runtime scripts + assets
foreach ($name in @("injector.mjs", "image-metadata.mjs", "wait-shell.mjs", "control-plane.mjs", "thumb.mjs", "probe-session-dom.mjs")) {
  $src = Join-Path $runtimeSrc ("scripts\" + $name)
  if (Test-Path -LiteralPath $src) {
    Copy-Item $src (Join-Path $dest ("scripts\" + $name)) -Force
  }
}
$imgCore = Join-Path $runtimeSrc "core\image-metadata.mjs"
if (Test-Path -LiteralPath $imgCore) {
  Copy-Item $imgCore (Join-Path $dest "core\image-metadata.mjs") -Force
}
Copy-Item (Join-Path $runtimeSrc "assets\*") (Join-Path $dest "assets\") -Force

# Align install-tree token with resolved package version (payload-only; not git tree).
# Git tree write-back remains publish-runtime.ps1 exclusive (ADR 0003).
$versionReplacement = 'const SKIN_VERSION_TOKEN = "' + $version + '";'
foreach ($rel in @("scripts\injector.mjs", "assets\renderer-inject.js")) {
  $target = Join-Path $dest $rel
  if (-not (Test-Path -LiteralPath $target)) { continue }
  $text = [System.IO.File]::ReadAllText($target)
  if ($text -notmatch [regex]::Escape($versionReplacement)) {
    $text = [regex]::Replace($text, 'const SKIN_VERSION_TOKEN = "[^"]*";', $versionReplacement)
    [System.IO.File]::WriteAllText($target, $text, [System.Text.UTF8Encoding]::new($false))
  }
}
Set-Content -Path (Join-Path $dest "VERSION") -Value $version -Encoding ascii -NoNewline

# core-win into version scripts + program lib
$libDir = Join-Path $programRoot "lib"
New-Item -ItemType Directory -Force -Path $libDir | Out-Null
foreach ($name in @("common-windows.ps1", "theme-windows.ps1", "config-utf8.ps1", "runtime-windows.ps1", "launcher-ui.ps1")) {
  $src = Join-Path $coreWinSrc $name
  if (Test-Path -LiteralPath $src) {
    Copy-Item $src (Join-Path $dest ("scripts\" + $name)) -Force
    if ($name -eq "launcher-ui.ps1") {
      Copy-Item $src (Join-Path $libDir "launcher-ui.ps1") -Force
    }
  }
}

# Daily entry scripts at program root (UTF-8 BOM for PS 5.1 Chinese)
$bom = New-Object System.Text.UTF8Encoding $true
foreach ($name in @(
  "open-codex-dream-skin.ps1",
  "check-and-fix.ps1",
  "switch-theme-ui.ps1",
  "smoke-dream-skin.ps1",
  "post-update-regression.ps1",
  "kick-theme-now.ps1",
  "show-feedback.ps1",
  "focus-codex.ps1",
  "start-dream-skin.ps1"
)) {
  $src = Join-Path $launcherSrc $name
  if (Test-Path -LiteralPath $src) {
    $text = [System.IO.File]::ReadAllText($src)
    [System.IO.File]::WriteAllText((Join-Path $programRoot $name), $text, $bom)
  }
}

# Tools + VBS (#18 Codex switch theme needs launch-switch-theme.vbs)
foreach ($name in @(
  "install-all-skin-launchers.ps1",
  "install-ux-shortcuts.ps1",
  "generate-theme-thumbs.ps1",
  "probe-session-dom.mjs",
  "launch-switch-theme.vbs",
  "launch-codex-skin.vbs",
  "launch-switch-theme.js"
)) {
  $src = Join-Path $toolsSrc $name
  if (-not (Test-Path -LiteralPath $src) -and $isRepoLayout) {
    $src = Join-Path $payloadRoot ("scripts\windows\" + $name)
  }
  if (Test-Path -LiteralPath $src) {
    Copy-Item $src (Join-Path $programRoot $name) -Force
  }
}

# Usage docs for install-ux Set-Doc (#18 tools/usage shortcut)
$usageCnName = -join ([char]0x4F7F, [char]0x7528, [char]0x8BF4, [char]0x660E) + ".md"
$usageCandidates = @(
  (Join-Path $docsSrc $usageCnName),
  (Join-Path $docsSrc "usage.md"),
  (Join-Path $payloadRoot ("docs\" + $usageCnName)),
  (Join-Path $payloadRoot "docs\usage.md"),
  (Join-Path $PackageRoot "docs\usage.md")
)
$usageHit = $usageCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if ($usageHit) {
  Copy-Item $usageHit (Join-Path $programRoot $usageCnName) -Force
  Copy-Item $usageHit (Join-Path $programRoot "USAGE.md") -Force
  Write-Host "usage doc -> program root"
} else {
  Write-Warning "usage.md not in package; tools/usage shortcut will skip"
}

# CLI packages (for import-themes / apply / doctor from install tree)
$cliRoot = Join-Path $programRoot "cli"
if ((Test-Path -LiteralPath $corePkgSrc) -and (Test-Path -LiteralPath $themesPkgSrc)) {
  New-Item -ItemType Directory -Force -Path (Join-Path $cliRoot "packages") | Out-Null
  Copy-Tree $corePkgSrc (Join-Path $cliRoot "packages\core")
  Copy-Tree $themesPkgSrc (Join-Path $cliRoot "packages\themes")
  # themes package imports ../runtime/scripts/thumb.mjs — point via junction/copy under cli
  $cliRuntimeScripts = Join-Path $cliRoot "packages\runtime\scripts"
  New-Item -ItemType Directory -Force -Path $cliRuntimeScripts | Out-Null
  $thumb = Join-Path $dest "scripts\thumb.mjs"
  if (Test-Path -LiteralPath $thumb) {
    Copy-Item $thumb (Join-Path $cliRuntimeScripts "thumb.mjs") -Force
  }
  # bundled themes for import-themes (cli resolves repoRoot = cli parent of packages)
  if (Test-Path -LiteralPath $themesSrc) {
    Copy-Tree $themesSrc (Join-Path $cliRoot "themes")
  }
  # tiny package.json marker
  $pkg = @{ name = "codex-skin-cli"; version = $version; private = $true; type = "module" } | ConvertTo-Json
  [System.IO.File]::WriteAllText((Join-Path $cliRoot "package.json"), $pkg + "`n", [System.Text.UTF8Encoding]::new($false))
}

# Native fast launcher
if (Test-Path -LiteralPath $nativeExeSrc) {
  Copy-Item $nativeExeSrc (Join-Path $programRoot "CodexFastLaunch.exe") -Force
  Write-Host "CodexFastLaunch.exe installed"
} else {
  Write-Host "CodexFastLaunch.exe not in package; taskbar will use PowerShell open script"
}

# wait-shell seed in state root
$waitShell = Join-Path $dest "scripts\wait-shell.mjs"
if (Test-Path -LiteralPath $waitShell) {
  Copy-Item $waitShell (Join-Path $stateRoot "wait-shell.mjs") -Force
}

# Runtime marker + current.json
$runtimeJson = (@{
  schemaVersion = 1
  product = "codex-skin"
  version = $version
  runtimeId = $runtimeId
  publishedAt = (Get-Date).ToUniversalTime().ToString("o")
  source = "product-package"
} | ConvertTo-Json -Depth 5) + "`n"
[System.IO.File]::WriteAllText((Join-Path $dest ".dream-skin-runtime.json"), $runtimeJson, [System.Text.UTF8Encoding]::new($false))

$currentPath = Join-Path $programRoot "current.json"
if (Test-Path -LiteralPath $currentPath) {
  $bak = Join-Path $programRoot ("current.json.bak-" + (Get-Date -Format "yyyyMMddHHmmss"))
  Copy-Item $currentPath $bak -Force
}
$currentObj = [ordered]@{
  schemaVersion = 1
  product = "CodexDreamSkin"
  version = $version
  runtimeId = $runtimeId
  relativeEnginePath = ("versions/" + $runtimeId)
  updatedAt = (Get-Date).ToUniversalTime().ToString("o")
  installedFrom = "product-package"
}
[System.IO.File]::WriteAllText(
  $currentPath,
  (($currentObj | ConvertTo-Json -Depth 5) + "`n"),
  [System.Text.UTF8Encoding]::new($false)
)
Write-Host "current.json -> $runtimeId"

# GC old versions: keep current + one previous (newest non-current)
try {
  $versionsDir = Join-Path $programRoot "versions"
  if (Test-Path -LiteralPath $versionsDir) {
    $keep = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    [void]$keep.Add($runtimeId)
    $all = @(Get-ChildItem $versionsDir -Directory | Sort-Object LastWriteTime -Descending)
    foreach ($dir in $all) {
      if ($keep.Count -ge 2) { break }
      [void]$keep.Add($dir.Name)
    }
    foreach ($dir in $all) {
      if ($keep.Contains($dir.Name)) { continue }
      try {
        Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction Stop
        Write-Host "GC removed old runtime $($dir.Name)"
      } catch {
        Write-Warning ("GC skip $($dir.Name): " + $_.Exception.Message)
      }
    }
  }
} catch {
  Write-Warning ("GC versions failed: " + $_.Exception.Message)
}

# Import themes via CLI if node available
if (-not $SkipImportThemes) {
  $node = $null
  try { $node = (Get-Command node -ErrorAction Stop).Source } catch {}
  $cli = Join-Path $cliRoot "packages\core\cli.mjs"
  if ($node -and (Test-Path -LiteralPath $cli)) {
    Write-Host "Importing bundled themes..."
    & $node $cli import-themes
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "import-themes exit=$LASTEXITCODE (you can re-run later)"
    }
  } else {
    Write-Warning "node or CLI missing; skip import-themes. Install Node ≥20 and re-run Import."
  }
}

if (-not $SkipShortcuts) {
  $ux = Join-Path $programRoot "install-ux-shortcuts.ps1"
  if (Test-Path -LiteralPath $ux) {
    Write-Host "Installing UX shortcuts..."
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ux
  }
  $all = Join-Path $programRoot "install-all-skin-launchers.ps1"
  if (Test-Path -LiteralPath $all) {
    Write-Host "Rebinding Codex/ChatGPT shortcuts..."
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $all
  }
}

# Soft reattach: flip live watch injector onto the just-installed runtime
# (shared helper; always passes --theme-dir StateRoot\active-theme).
try {
  $softHelper = Join-Path $PSScriptRoot "soft-reattach.ps1"
  if (-not (Test-Path -LiteralPath $softHelper)) {
    # Product zip: helper lives next to Install.ps1 after Build copies scripts/windows.
    $softHelper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "soft-reattach.ps1"
  }
  if (Test-Path -LiteralPath $softHelper) {
    . $softHelper
    [void](Invoke-CodexSkinSoftReattach -RuntimeRoot $dest -RuntimeId $runtimeId -StateRoot $stateRoot)
  } else {
    Write-Warning "soft-reattach.ps1 missing; click taskbar Codex after install"
  }
} catch {
  Write-Warning ("soft reattach: " + $_.Exception.Message)
}

Write-Host ""
Write-Host "Installed Codex Dream Skin $version ($runtimeId)"
Write-Host "Next:"
Write-Host "  1) Ensure OpenAI Codex (Store) is installed"
Write-Host "  2) Click taskbar / Start Menu Codex (if injector not already running)"
Write-Host "  3) Optional: node `"$cliRoot\packages\core\cli.mjs`" apply --theme genshin-night"
Write-Host "  4) Optional: node `"$cliRoot\packages\core\cli.mjs`" doctor"
Write-Host "Note: Store tile bare launch is an OS limit — use the taskbar pin."

if (-not $NoStart) {
  $open = Join-Path $programRoot "open-codex-dream-skin.ps1"
  if (Test-Path -LiteralPath $open) {
    Write-Host "Starting skin launcher (quiet)..."
    Start-Process -FilePath "powershell.exe" -ArgumentList @(
      "-NoProfile", "-STA", "-WindowStyle", "Hidden",
      "-ExecutionPolicy", "Bypass",
      "-File", $open, "-Port", "9335", "-NoPrompt"
    ) -WindowStyle Hidden | Out-Null
  }
}
