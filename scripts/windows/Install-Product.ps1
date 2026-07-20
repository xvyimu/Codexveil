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

function Get-PackageVersion([string]$Payload, [string]$Explicit) {
  if ($Explicit) { return $Explicit }
  $meta = Join-Path $PackageRoot "package-meta.json"
  if (Test-Path -LiteralPath $meta) {
    try {
      $m = Get-Content -LiteralPath $meta -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($m.version) { return [string]$m.version }
    } catch {}
  }
  $verFile = Join-Path $Payload "runtime\VERSION"
  if (-not (Test-Path -LiteralPath $verFile)) {
    $verFile = Join-Path $PackageRoot "packages\runtime\VERSION"
  }
  if (Test-Path -LiteralPath $verFile) {
    $v = (Get-Content -LiteralPath $verFile -Raw).Trim()
    if ($v) { return $v }
  }
  return "1.3.25"
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
  $nativeExeSrc = Join-Path $payloadRoot "apps\native\CodexFastLaunch\bin\CodexFastLaunch.exe"
} else {
  $runtimeSrc = Join-Path $payloadRoot "runtime"
  $coreWinSrc = Join-Path $payloadRoot "core-win"
  $launcherSrc = Join-Path $payloadRoot "launcher"
  $themesSrc = Join-Path $payloadRoot "themes"
  $corePkgSrc = Join-Path $payloadRoot "packages\core"
  $themesPkgSrc = Join-Path $payloadRoot "packages\themes"
  $toolsSrc = Join-Path $payloadRoot "tools"
  $nativeExeSrc = Join-Path $payloadRoot "native\CodexFastLaunch.exe"
}

$version = Get-PackageVersion -Payload $payloadRoot -Explicit $Version
$hash = -join ((1..6) | ForEach-Object { "{0:x}" -f (Get-Random -Max 16) })
$runtimeId = "$version-$hash"

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

# Stamp version token in installed copies
$versionReplacement = 'const SKIN_VERSION_TOKEN = "' + $version + '";'
foreach ($rel in @("scripts\injector.mjs", "assets\renderer-inject.js")) {
  $target = Join-Path $dest $rel
  if (-not (Test-Path -LiteralPath $target)) { continue }
  $text = [System.IO.File]::ReadAllText($target)
  $text = [regex]::Replace($text, 'const SKIN_VERSION_TOKEN = "[^"]*";', $versionReplacement)
  [System.IO.File]::WriteAllText($target, $text, [System.Text.UTF8Encoding]::new($false))
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

# Tools
foreach ($name in @(
  "install-all-skin-launchers.ps1",
  "install-ux-shortcuts.ps1",
  "generate-theme-thumbs.ps1",
  "probe-session-dom.mjs"
)) {
  $src = Join-Path $toolsSrc $name
  if (Test-Path -LiteralPath $src) {
    Copy-Item $src (Join-Path $programRoot $name) -Force
  }
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

Write-Host ""
Write-Host "Installed Codex Dream Skin $version ($runtimeId)"
Write-Host "Next:"
Write-Host "  1) Ensure OpenAI Codex (Store) is installed"
Write-Host "  2) Click taskbar / Start Menu Codex"
Write-Host "  3) Optional: node `"$cliRoot\packages\core\cli.mjs`" apply --theme genshin-night"
Write-Host "  4) Optional: node `"$cliRoot\packages\core\cli.mjs`" doctor"

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
