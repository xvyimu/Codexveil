# Publish codex-skin runtime into Programs\CodexDreamSkin\versions\<id>
# and flip current.json. Does not rewrite Start Menu (already points at open-*.ps1).
param(
  [string]$RepoRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
  [string]$Version = "1.3.0",
  [switch]$SkipImportThemes
)

$ErrorActionPreference = "Stop"
try { & chcp.com 65001 | Out-Null } catch {}
[Console]::OutputEncoding = [Text.Encoding]::UTF8
try { [Console]::InputEncoding = [Text.Encoding]::UTF8 } catch {}
$OutputEncoding = [Text.Encoding]::UTF8

$programRoot = Join-Path $env:LOCALAPPDATA "Programs\CodexDreamSkin"
if (-not (Test-Path -LiteralPath $programRoot)) {
  throw "CodexDreamSkin install not found: $programRoot"
}

$stamp = Get-Date -Format "yyyyMMddHHmmss"
$hash = -join ((1..6) | ForEach-Object { "{0:x}" -f (Get-Random -Max 16) })
$runtimeId = "$Version-$hash"
$dest = Join-Path $programRoot "versions\$runtimeId"

Write-Host "Publishing runtime $runtimeId"
New-Item -ItemType Directory -Force -Path (Join-Path $dest "scripts") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $dest "assets") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $dest "core") | Out-Null

# Runtime injector + assets from unified repo
$runtime = Join-Path $RepoRoot "packages\runtime"
Copy-Item (Join-Path $runtime "scripts\injector.mjs") (Join-Path $dest "scripts\injector.mjs") -Force
Copy-Item (Join-Path $runtime "scripts\cdp-url-guard.mjs") (Join-Path $dest "scripts\cdp-url-guard.mjs") -Force
Copy-Item (Join-Path $runtime "scripts\theme-catalog-budget.mjs") (Join-Path $dest "scripts\theme-catalog-budget.mjs") -Force
Copy-Item (Join-Path $runtime "scripts\image-metadata.mjs") (Join-Path $dest "scripts\image-metadata.mjs") -Force
foreach ($extra in @("fs-io.mjs", "wait-shell.mjs", "control-plane.mjs", "thumb.mjs", "probe-session-dom.mjs")) {
  $srcExtra = Join-Path $runtime ("scripts\" + $extra)
  if (-not (Test-Path -LiteralPath $srcExtra) -and $extra -eq 'probe-session-dom.mjs') {
    $srcExtra = Join-Path $RepoRoot "scripts\windows\probe-session-dom.mjs"
  }
  if (Test-Path -LiteralPath $srcExtra) {
    Copy-Item $srcExtra (Join-Path $dest ("scripts\" + $extra)) -Force
  }
}
Copy-Item (Join-Path $runtime "core\image-metadata.mjs") (Join-Path $dest "core\image-metadata.mjs") -Force
Copy-Item (Join-Path $runtime "assets\*") (Join-Path $dest "assets\") -Force
# Also keep wait-shell in state root for open launcher Wait-CodexShell
$stateRoot = Join-Path $env:LOCALAPPDATA "CodexDreamSkin"
New-Item -ItemType Directory -Force -Path $stateRoot | Out-Null
if (Test-Path -LiteralPath (Join-Path $runtime "scripts\wait-shell.mjs")) {
  Copy-Item (Join-Path $runtime "scripts\wait-shell.mjs") (Join-Path $stateRoot "wait-shell.mjs") -Force
}
# Ensure default seed art exists (theme store init requires it).
# Prefer repo runtime assets (already copied above); else newest versions/*/assets copy.
$seedArt = Join-Path $dest "assets\dream-reference.jpg"
if (-not (Test-Path -LiteralPath $seedArt)) {
  $repoSeed = Join-Path $runtime "assets\dream-reference.jpg"
  $fallback = $null
  if (Test-Path -LiteralPath $repoSeed) {
    $fallback = $repoSeed
  } else {
    $versionsDir = Join-Path $programRoot "versions"
    if (Test-Path -LiteralPath $versionsDir) {
      $candidate = Get-ChildItem $versionsDir -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {
          $p = Join-Path $_.FullName "assets\dream-reference.jpg"
          if (Test-Path -LiteralPath $p) {
            Get-Item -LiteralPath $p
          }
        } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
      if ($candidate) { $fallback = $candidate.FullName }
    }
  }
  if ($fallback) {
    Copy-Item $fallback $seedArt -Force
  } else {
    Write-Warning "dream-reference.jpg missing; Initialize-DreamSkinThemeStore may fail on first run"
  }
}

# Windows modules
$coreWin = Join-Path $RepoRoot "packages\core-win"
foreach ($name in @("common-windows.ps1","theme-windows.ps1","config-utf8.ps1","runtime-windows.ps1","launcher-ui.ps1")) {
  $src = Join-Path $coreWin $name
  if (Test-Path -LiteralPath $src) {
    Copy-Item $src (Join-Path $dest "scripts\$name") -Force
  }
}

# Shared launcher UI also lives at programRoot\lib for open-*.ps1
$libDir = Join-Path $programRoot "lib"
New-Item -ItemType Directory -Force -Path $libDir | Out-Null
$launcherUi = Join-Path $coreWin "launcher-ui.ps1"
if (Test-Path -LiteralPath $launcherUi) {
  Copy-Item $launcherUi (Join-Path $libDir "launcher-ui.ps1") -Force
  Copy-Item $launcherUi (Join-Path $dest "scripts\launcher-ui.ps1") -Force
}

# Daily entry scripts at program root (not only under versions/).
# launch-dream-skin.ps1 must sit at programRoot so Ensure-CodexSkinTray / current.json
# resolution (PSScriptRoot = programRoot) keep working after the vendor→first-party move.
$launcherDir = Join-Path $RepoRoot "apps\launcher"
foreach ($name in @(
  "open-codex-dream-skin.ps1",
  "check-and-fix.ps1",
  "switch-theme-ui.ps1",
  "smoke-dream-skin.ps1",
  "post-update-regression.ps1",
  "kick-theme-now.ps1",
  "show-feedback.ps1",
  "focus-codex.ps1",
  "launch-dream-skin.ps1"
)) {
  $src = Join-Path $launcherDir $name
  if (Test-Path -LiteralPath $src) {
    # PS 5.1 prefers BOM for Chinese comments
    $text = [System.IO.File]::ReadAllText($src)
    $bom = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText((Join-Path $programRoot $name), $text, $bom)
  }
}
# silent launch helpers
foreach ($name in @("launch-codex-skin.vbs","launch-switch-theme.vbs","install-all-skin-launchers.ps1","generate-theme-thumbs.ps1","probe-session-dom.mjs")) {
  $src = Join-Path $RepoRoot ("scripts\windows\" + $name)
  if (Test-Path -LiteralPath $src) {
    Copy-Item $src (Join-Path $programRoot $name) -Force
  }
}

# Native fast launcher (CodexFastLaunch.exe): rebuild if source present, install to programRoot.
# Taskbar Codex.lnk primary entry; /health hit path is ~100ms cold start.
# Keep this block ASCII-only: Windows PowerShell 5.1 mis-parses UTF-8 (no BOM) Chinese comments.
try {
  $nativeDir = Join-Path $RepoRoot 'apps\native\CodexFastLaunch'
  $nativeSrc = Join-Path $nativeDir 'CodexFastLaunch.cs'
  $nativeExe = Join-Path $nativeDir 'bin\CodexFastLaunch.exe'
  $csc = Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
  if (-not (Test-Path -LiteralPath $csc)) {
    $csc = Join-Path $env:SystemRoot 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
  }
  if ((Test-Path -LiteralPath $nativeSrc) -and (Test-Path -LiteralPath $csc)) {
    $binDir = Join-Path $nativeDir 'bin'
    New-Item -ItemType Directory -Force -Path $binDir | Out-Null
    $ico = Join-Path $programRoot 'codex-icon.ico'
    $cscArgs = @(
      '/nologo','/target:winexe','/platform:anycpu','/optimize+','/debug-',
      ('/out:' + $nativeExe),
      '/reference:System.dll','/reference:System.Core.dll',
      $nativeSrc
    )
    if (Test-Path -LiteralPath $ico) { $cscArgs = @('/win32icon:' + $ico) + $cscArgs }
    Write-Host "Building CodexFastLaunch.exe..."
    $pCsc = Start-Process -FilePath $csc -ArgumentList $cscArgs -Wait -PassThru -NoNewWindow
    if ($pCsc.ExitCode -ne 0) {
      Write-Warning ("csc exit=" + $pCsc.ExitCode + "; keep previous CodexFastLaunch.exe if any")
    }
  }
  if (Test-Path -LiteralPath $nativeExe) {
    Copy-Item $nativeExe (Join-Path $programRoot 'CodexFastLaunch.exe') -Force
    Write-Host ("CodexFastLaunch.exe -> " + (Join-Path $programRoot 'CodexFastLaunch.exe'))
  } else {
    Write-Warning 'CodexFastLaunch.exe not built; taskbar will fall back to PowerShell open script'
  }
} catch {
  Write-Warning ("native launcher build: " + $_.Exception.Message)
}

# Runtime-root scripts (versions/<id>/scripts/): first-party only (ADR 0006).
# tray + restore live under apps/launcher after sovereign move out of vendor/;
# launch is also mirrored here so a versions/<id>/scripts copy exists, but the
# load-bearing entry is programRoot\launch-dream-skin.ps1 (copied above).
# install-dream-skin / verify-dream-skin are dead legacy helpers — no longer shipped.
foreach ($name in @(
  "start-dream-skin.ps1",
  "tray-dream-skin.ps1",
  "restore-dream-skin.ps1",
  "launch-dream-skin.ps1"
)) {
  $src = Join-Path $launcherDir $name
  if (Test-Path -LiteralPath $src) {
    Copy-Item $src (Join-Path $dest ("scripts\" + $name)) -Force
  } else {
    Write-Warning ("missing first-party launcher script: " + $name)
  }
}

Set-Content -Path (Join-Path $dest "VERSION") -Value $Version -Encoding ascii -NoNewline

# --- Single version source ---------------------------------------------------
# The runtime injector + renderer declare `const SKIN_VERSION_TOKEN = "..."`.
# In the repo it stays "__SKIN_VERSION__" (dev runs evaluate that to "dev").
# Publish stamps the release version into BOTH the repo source (so git shows the
# published version) and the just-copied versions/<id> files (so the running
# skin reports the right version and verify's version===expectedVersion holds).
# The regex matches whatever literal is currently assigned, so re-publishing
# over an already-stamped repo copy replaces the old version cleanly.
$versionTargets = @(
  (Join-Path $RepoRoot 'packages\runtime\scripts\injector.mjs'),
  (Join-Path $RepoRoot 'packages\runtime\assets\renderer-inject.js'),
  (Join-Path $dest 'scripts\injector.mjs'),
  (Join-Path $dest 'assets\renderer-inject.js')
)
$versionReplacement = 'const SKIN_VERSION_TOKEN = "' + $Version + '";'
foreach ($target in $versionTargets) {
  if (-not (Test-Path -LiteralPath $target)) { continue }
  $text = [System.IO.File]::ReadAllText($target)
  $text = [regex]::Replace($text, 'const SKIN_VERSION_TOKEN = "[^"]*";', $versionReplacement)
  [System.IO.File]::WriteAllText($target, $text, [System.Text.UTF8Encoding]::new($false))
}
Write-Host "Stamped SKIN_VERSION=$Version into repo + runtime copies"

# dream-skin runtime marker
$runtimeJson = (@{
  schemaVersion = 1
  product = "codex-skin"
  version = $Version
  runtimeId = $runtimeId
  publishedAt = (Get-Date).ToUniversalTime().ToString("o")
  sourceRepo = $RepoRoot
} | ConvertTo-Json -Depth 5) + "`n"
[System.IO.File]::WriteAllText((Join-Path $dest ".dream-skin-runtime.json"), $runtimeJson, [System.Text.UTF8Encoding]::new($false))

# Flip current.json with backup
$currentPath = Join-Path $programRoot "current.json"
if (Test-Path -LiteralPath $currentPath) {
  $bak = Join-Path $programRoot ("current.json.bak-" + $stamp)
  Copy-Item $currentPath $bak -Force
  Write-Host "Backed up current.json -> $bak"
}

$currentObj = [ordered]@{
  schemaVersion = 1
  product = "CodexDreamSkin"
  version = $Version
  runtimeId = $runtimeId
  relativeEnginePath = ("versions/" + $runtimeId)
  updatedAt = (Get-Date).ToUniversalTime().ToString("o")
  codexSkinRepo = $RepoRoot
}
# UTF-8 without BOM — PowerShell Set-Content -Encoding utf8 writes BOM and breaks ConvertFrom-Json in open launcher
$currentJson = ($currentObj | ConvertTo-Json -Depth 5) + "`n"
[System.IO.File]::WriteAllText($currentPath, $currentJson, [System.Text.UTF8Encoding]::new($false))
Write-Host "current.json -> $runtimeId"

# GC old runtime versions: keep current + previous (and never delete the just-published one).
try {
  $versionsDir = Join-Path $programRoot 'versions'
  if (Test-Path -LiteralPath $versionsDir) {
    $keep = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    [void]$keep.Add($runtimeId)
    # Prefer previous current from backup if present
    $bakFiles = @(Get-ChildItem $programRoot -Filter 'current.json.bak-*' -File -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending | Select-Object -First 1)
    foreach ($bak in $bakFiles) {
      try {
        $prev = Get-Content $bak.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($prev.runtimeId) { [void]$keep.Add([string]$prev.runtimeId) }
      } catch {}
    }
    # Also keep newest non-current as a safety previous if backup missing
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

# UX shortcuts refresh (top-level daily + advanced folder)
$ux = Join-Path $RepoRoot "scripts\windows\install-ux-shortcuts.ps1"
if (Test-Path -LiteralPath $ux) {
  try {
    Write-Host "Refreshing UX shortcuts..."
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ux
  } catch {
    Write-Warning ("install-ux-shortcuts: " + $_.Exception.Message)
  }
}

if (-not $SkipImportThemes) {
  $import = Join-Path $RepoRoot "scripts\windows\import-themes.ps1"
  if (Test-Path -LiteralPath $import) {
    Write-Host "Importing multi-theme catalog..."
    & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $import -KeepUnlocked -RepoRoot $RepoRoot
  }
}

# Refresh post-update report (G5-C): hard timeout so Quiet -Repair cannot hang publish forever.
# G5-C: post-update Quiet 任一 check 失败会 exit 2；soft reattach 为正式降级路径（非发版失败）。
# On timeout/failure → soft reattach (shared with Install-Product.ps1).
# TD-02: best-effort print failed check names from post-update-report.json (does not affect exit).
. (Join-Path $PSScriptRoot "soft-reattach.ps1")
. (Join-Path $PSScriptRoot "post-update-failure-summary.ps1")

try {
  $post = Join-Path $programRoot 'post-update-regression.ps1'
  if (Test-Path -LiteralPath $post) {
    $postTimeoutSec = 60
    Write-Host "Refreshing post-update report (Quiet, timeout ${postTimeoutSec}s)..."
    # -Repair reattaches onto the just-published runtime; bounded wait avoids hang (G5).
    $pPost = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
      '-NoProfile','-ExecutionPolicy','Bypass','-File',$post,'-Quiet','-Repair'
    ) -PassThru -WindowStyle Hidden
    $finished = $pPost.WaitForExit($postTimeoutSec * 1000)
    if (-not $finished) {
      try {
        # Kill process tree when possible (Windows).
        Stop-Process -Id $pPost.Id -Force -ErrorAction SilentlyContinue
        Get-CimInstance Win32_Process -Filter "ParentProcessId=$($pPost.Id)" -ErrorAction SilentlyContinue |
          ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }
      } catch {}
      Write-CodexSkinPostUpdateFailureSummary
      $okReattach = [bool](Invoke-CodexSkinSoftReattach -RuntimeRoot $dest -RuntimeId $runtimeId -StateRoot $stateRoot)
      if ($okReattach) {
        Write-Host "post-update skipped/failed (timeout) → soft reattach OK"
      } else {
        Write-Warning "post-update timed out — soft reattach failed/skipped; click taskbar Codex"
      }
    } elseif ($pPost.ExitCode -ne 0) {
      Write-CodexSkinPostUpdateFailureSummary
      $okReattach = [bool](Invoke-CodexSkinSoftReattach -RuntimeRoot $dest -RuntimeId $runtimeId -StateRoot $stateRoot)
      if ($okReattach) {
        Write-Host ("post-update skipped/failed (exit=" + $pPost.ExitCode + ") → soft reattach OK")
      } else {
        Write-Warning ("post-update exit=" + $pPost.ExitCode + " — soft reattach failed/skipped; click taskbar Codex")
      }
    } else {
      Write-Host ("post-update exit=" + $pPost.ExitCode)
    }
  }
} catch {
  Write-Warning ("post-update refresh: " + $_.Exception.Message)
  try {
    Write-CodexSkinPostUpdateFailureSummary
    $okReattach = [bool](Invoke-CodexSkinSoftReattach -RuntimeRoot $dest -RuntimeId $runtimeId -StateRoot $stateRoot)
    if ($okReattach) {
      Write-Host "post-update skipped/failed (error) → soft reattach OK"
    } else {
      Write-Warning "soft reattach after post-update error failed/skipped; click taskbar Codex"
    }
  } catch {
    Write-Warning ("soft reattach after post-update error: " + $_.Exception.Message)
  }
}

# Mark report with published runtime stamp even if post-update is partial.
try {
  $reportPath = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin\post-update-report.json'
  if (Test-Path -LiteralPath $reportPath) {
    $rep = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $rep | Add-Member -NotePropertyName publishedRuntimeId -NotePropertyValue $runtimeId -Force
    $rep | Add-Member -NotePropertyName currentRuntimeId -NotePropertyValue $runtimeId -Force
    $rep | Add-Member -NotePropertyName stale -NotePropertyValue $false -Force
    $json = ($rep | ConvertTo-Json -Depth 8) + "`n"
    [System.IO.File]::WriteAllText($reportPath, $json, [System.Text.UTF8Encoding]::new($false))
  }
} catch {}

Write-Host @"

Published.
Next:
  1) Close Codex completely if a naked/old session is stuck
  2) Click taskbar Codex (Dream Skin launcher) to start watch injector on 9335
  3) node `"$RepoRoot\packages\core\cli.mjs`" apply --theme genshin-night
  4) node `"$RepoRoot\packages\core\cli.mjs`" doctor
  5) Optional session DOM probe after opening a chat:
     node `"$programRoot\probe-session-dom.mjs`"
"@
