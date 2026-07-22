# Dry-run closure check for publish-runtime.ps1 runtime scripts whitelist.
# Does NOT touch %LOCALAPPDATA%\Programs\CodexDreamSkin or current.json.
#
# Exit codes:
#   0 = publish whitelist closed for injector ESM graph (theme-load included)
#   1 = missing required script / static whitelist hole / import failed
#   3 = unexpected error
#
# Usage:
#   pwsh -NoProfile -File scripts/windows/verify-publish-runtime-payload.ps1
#   pwsh -NoProfile -File scripts/windows/verify-publish-runtime-payload.ps1 -Json
param(
  [string]$RepoRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
  [switch]$Json
)

$ErrorActionPreference = "Stop"
try { & chcp.com 65001 | Out-Null } catch {}
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$report = [ordered]@{
  ok         = $false
  exitCode   = 3
  repoRoot   = $RepoRoot
  stageDir   = $null
  checks     = @()
  failed     = @()
}

function Add-Check([string]$Name, [bool]$Pass, [string]$Detail) {
  $item = [ordered]@{ name = $Name; pass = $Pass; detail = $Detail }
  $script:report.checks += $item
  if (-not $Pass) { $script:report.failed += $Name }
  if (-not $Json) {
    $mark = if ($Pass) { "ok" } else { "FAIL" }
    Write-Host ("[{0}] {1}: {2}" -f $mark, $Name, $Detail)
  }
}

try {
  $runtimeScripts = Join-Path $RepoRoot "packages\runtime\scripts"
  $publishScript = Join-Path $RepoRoot "scripts\windows\publish-runtime.ps1"
  if (-not (Test-Path -LiteralPath $runtimeScripts)) {
    throw "missing packages/runtime/scripts"
  }
  if (-not (Test-Path -LiteralPath $publishScript)) {
    throw "missing publish-runtime.ps1"
  }

  # Keep in lockstep with publish-runtime.ps1 $requiredRuntimeScripts.
  $requiredNames = @(
    "injector.mjs",
    "theme-load.mjs",
    "cdp-url-guard.mjs",
    "theme-catalog-budget.mjs",
    "image-metadata.mjs"
  )

  $publishText = [System.IO.File]::ReadAllText($publishScript)
  foreach ($name in $requiredNames) {
    $quoted = '"' + $name + '"'
    $inWhitelist = $publishText.Contains($quoted) -or $publishText.Contains("'" + $name + "'")
    Add-Check ("whitelist:" + $name) $inWhitelist ("publish-runtime.ps1 mentions $name")
  }

  foreach ($name in $requiredNames) {
    $src = Join-Path $runtimeScripts $name
    Add-Check ("repo:" + $name) (Test-Path -LiteralPath $src) $src
  }

  $stage = Join-Path ([System.IO.Path]::GetTempPath()) ("codexveil-publish-dryrun-" + [guid]::NewGuid().ToString("N"))
  $stageScripts = Join-Path $stage "scripts"
  $stageCore = Join-Path $stage "core"
  New-Item -ItemType Directory -Force -Path $stageScripts | Out-Null
  New-Item -ItemType Directory -Force -Path $stageCore | Out-Null
  $report.stageDir = $stage

  foreach ($name in $requiredNames) {
    $src = Join-Path $runtimeScripts $name
    if (Test-Path -LiteralPath $src) {
      Copy-Item $src (Join-Path $stageScripts $name) -Force
    }
  }
  # Optional helpers if present (mirrors publish optional loop).
  foreach ($extra in @("payload-builder.mjs", "fs-io.mjs", "wait-shell.mjs", "control-plane.mjs", "thumb.mjs")) {
    $src = Join-Path $runtimeScripts $extra
    if (Test-Path -LiteralPath $src) {
      Copy-Item $src (Join-Path $stageScripts $extra) -Force
    }
  }
  # image-metadata.mjs resolves ../core/image-metadata.mjs (publish always copies core).
  $coreMetaSrc = Join-Path $RepoRoot "packages\runtime\core\image-metadata.mjs"
  if (Test-Path -LiteralPath $coreMetaSrc) {
    Copy-Item $coreMetaSrc (Join-Path $stageCore "image-metadata.mjs") -Force
  }
  Add-Check "staged:core/image-metadata.mjs" (Test-Path -LiteralPath (Join-Path $stageCore "image-metadata.mjs")) `
    (Join-Path $stageCore "image-metadata.mjs")

  foreach ($name in $requiredNames) {
    $dst = Join-Path $stageScripts $name
    Add-Check ("staged:" + $name) (Test-Path -LiteralPath $dst) $dst
  }

  # Node must resolve theme-load (+ its deps) from staged layout (catches ERR_MODULE_NOT_FOUND).
  $node = Get-Command node -ErrorAction SilentlyContinue
  if (-not $node) {
    Add-Check "node:import-theme-load" $false "node not on PATH"
  } else {
    $stdoutPath = Join-Path $stage "stdout.txt"
    $stderrPath = Join-Path $stage "stderr.txt"
    # Static import from staged cwd — same relative graph as install-state versions/<id>/scripts/.
    $checkJs = @'
import { loadTheme, THEME_CHOICES } from "./theme-load.mjs";
if (typeof loadTheme !== "function" || !THEME_CHOICES) {
  throw new Error("theme-load exports missing");
}
console.log(JSON.stringify({ pass: true, export: "loadTheme" }));
'@
    $tmpJs = Join-Path $stageScripts "check-import.mjs"
    [System.IO.File]::WriteAllText($tmpJs, $checkJs, [System.Text.UTF8Encoding]::new($false))
    $p = Start-Process -FilePath $node.Source -ArgumentList @($tmpJs) `
      -WorkingDirectory $stageScripts -Wait -PassThru -NoNewWindow `
      -RedirectStandardOutput $stdoutPath `
      -RedirectStandardError $stderrPath
    $stderr = if (Test-Path -LiteralPath $stderrPath) { (Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue) } else { "" }
    if ($null -eq $stderr) { $stderr = "" }
    $passImport = ($p.ExitCode -eq 0)
    $detail = if ($passImport) { "theme-load import ok (staged ESM graph)" } else { "exit=$($p.ExitCode) stderr=$($stderr.Trim())" }
    Add-Check "node:import-theme-load" $passImport $detail

    # Syntax-check staged injector (does not load deps, but catches copy corruption).
    $injectorPath = Join-Path $stageScripts "injector.mjs"
    $checkOut = Join-Path $stage "check-out.txt"
    $checkErr = Join-Path $stage "check-err.txt"
    $pCheck = Start-Process -FilePath $node.Source -ArgumentList @("--check", $injectorPath) `
      -WorkingDirectory $stageScripts -Wait -PassThru -NoNewWindow `
      -RedirectStandardOutput $checkOut `
      -RedirectStandardError $checkErr
    $errCheck = if (Test-Path -LiteralPath $checkErr) { (Get-Content -LiteralPath $checkErr -Raw -ErrorAction SilentlyContinue) } else { "" }
    if ($null -eq $errCheck) { $errCheck = "" }
    Add-Check "node:--check-injector" ($pCheck.ExitCode -eq 0) $(if ($pCheck.ExitCode -eq 0) { "syntax ok" } else { $errCheck.Trim() })
  }

  # Fail closed if injector still imports theme-load but whitelist static check already covered.
  $injRepo = Join-Path $runtimeScripts "injector.mjs"
  if (Test-Path -LiteralPath $injRepo) {
    $injText = [System.IO.File]::ReadAllText($injRepo)
    $importsThemeLoad = $injText -match 'from\s+["'']\./theme-load\.mjs["'']'
    Add-Check "injector:imports-theme-load" $importsThemeLoad "injector.mjs must import ./theme-load.mjs"
  }

  $failedCount = @($report.failed).Count
  if ($failedCount -eq 0) {
    $report.ok = $true
    $report.exitCode = 0
  } else {
    $report.ok = $false
    $report.exitCode = 1
  }
} catch {
  $report.ok = $false
  if ($report.exitCode -eq 3 -or $report.exitCode -eq 0) { $report.exitCode = 3 }
  Add-Check "unexpected" $false $_.Exception.Message
  if ($report.exitCode -ne 1) { $report.exitCode = 3 }
} finally {
  if ($report.stageDir -and (Test-Path -LiteralPath $report.stageDir)) {
    try { Remove-Item -LiteralPath $report.stageDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
  }
}

if ($Json) {
  ($report | ConvertTo-Json -Depth 6)
} elseif (-not $report.ok) {
  Write-Host ("VERIFY FAIL exit={0} failed=[{1}]" -f $report.exitCode, ($report.failed -join ", "))
} else {
  Write-Host "VERIFY OK publish runtime payload closed (theme-load + required ESM graph)"
}

exit $report.exitCode
