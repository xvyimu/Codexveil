# TD-01: Compare install-tree runtime under current.json with repo packages/runtime.
# Detects "git green but install still old" (e.g. control-plane without tokensEqual).
# Exit codes:
#   0 = all required checks pass
#   1 = drift / missing markers / hash mismatch
#   2 = install or current.json missing (cannot compare)
#   3 = bad args / unexpected error
param(
  [string]$RepoRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
  [string]$ProgramRoot = (Join-Path $env:LOCALAPPDATA "Programs\CodexDreamSkin"),
  [switch]$Json
)

$ErrorActionPreference = "Stop"
try { & chcp.com 65001 | Out-Null } catch {}
try {
  [Console]::OutputEncoding = [Text.Encoding]::UTF8
} catch {}

function Get-FileSha256([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-FileContains([string]$Path, [string]$Pattern) {
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  # Do not use -Quiet with "$null -ne": $null -ne $false is $true (false positive).
  $hit = Select-String -LiteralPath $Path -Pattern $Pattern -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -First 1
  return $null -ne $hit
}

$report = [ordered]@{
  ok              = $false
  exitCode        = 3
  repoRoot        = $RepoRoot
  programRoot     = $ProgramRoot
  runtimeId       = $null
  relativeEngine  = $null
  installRuntime  = $null
  checks          = @()
  failed          = @()
  notes           = @()
}

function Add-Check([string]$Name, [bool]$Pass, [string]$Detail) {
  $item = [ordered]@{ name = $Name; pass = $Pass; detail = $Detail }
  $script:report.checks += $item
  if (-not $Pass) { $script:report.failed += $Name }
  $mark = if ($Pass) { "ok" } else { "FAIL" }
  if (-not $Json) {
    Write-Host ("[{0}] {1}: {2}" -f $mark, $Name, $Detail)
  }
}

try {
  $currentPath = Join-Path $ProgramRoot "current.json"
  if (-not (Test-Path -LiteralPath $ProgramRoot)) {
    Add-Check "programRoot" $false "missing: $ProgramRoot"
    $report.exitCode = 2
    $report.notes += "Install CodexDreamSkin first (Install.ps1 or publish-runtime.ps1)."
    throw "no-install"
  }
  if (-not (Test-Path -LiteralPath $currentPath)) {
    Add-Check "current.json" $false "missing: $currentPath"
    $report.exitCode = 2
    throw "no-current"
  }

  $current = Get-Content -LiteralPath $currentPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $runtimeId = [string]$current.runtimeId
  $rel = [string]$current.relativeEnginePath
  if (-not $runtimeId -or -not $rel) {
    Add-Check "current.json fields" $false "runtimeId/relativeEnginePath missing"
    $report.exitCode = 1
    throw "bad-current"
  }
  $report.runtimeId = $runtimeId
  $report.relativeEngine = $rel

  $installRuntime = Join-Path $ProgramRoot ($rel -replace '/', '\')
  $report.installRuntime = $installRuntime
  if (-not (Test-Path -LiteralPath $installRuntime)) {
    Add-Check "install runtime dir" $false "missing: $installRuntime"
    $report.exitCode = 2
    throw "no-runtime-dir"
  }
  Add-Check "current.json" $true "runtimeId=$runtimeId relativeEnginePath=$rel"

  $repoRuntime = Join-Path $RepoRoot "packages\runtime"
  if (-not (Test-Path -LiteralPath $repoRuntime)) {
    Add-Check "repo packages/runtime" $false "missing: $repoRuntime"
    $report.exitCode = 3
    throw "no-repo-runtime"
  }
  Add-Check "repo packages/runtime" $true $repoRuntime

  # Files that must byte-match after a correct publish (control-plane is not version-stamped).
  $exactPairs = @(
    @{ Rel = "scripts\control-plane.mjs"; Required = $true },
    @{ Rel = "scripts\wait-shell.mjs"; Required = $false },
    @{ Rel = "scripts\thumb.mjs"; Required = $false },
    @{ Rel = "scripts\image-metadata.mjs"; Required = $false },
    @{ Rel = "core\image-metadata.mjs"; Required = $false }
  )

  foreach ($pair in $exactPairs) {
    $repoFile = Join-Path $repoRuntime $pair.Rel
    $instFile = Join-Path $installRuntime $pair.Rel
    $name = "hash:" + $pair.Rel
    if (-not (Test-Path -LiteralPath $repoFile)) {
      if ($pair.Required) {
        Add-Check $name $false "repo file missing"
      } else {
        Add-Check $name $true "repo optional missing — skip"
      }
      continue
    }
    if (-not (Test-Path -LiteralPath $instFile)) {
      Add-Check $name $(-not $pair.Required) $(if ($pair.Required) { "install file missing" } else { "install optional missing — ok" })
      continue
    }
    $hRepo = Get-FileSha256 $repoFile
    $hInst = Get-FileSha256 $instFile
    $pass = ($hRepo -eq $hInst)
    $detail = if ($pass) {
      "match sha256=$($hRepo.Substring(0, 12))…"
    } else {
      "DRIFT repo=$($hRepo.Substring(0, 12))… install=$($hInst.Substring(0, 12))… → run publish-runtime.ps1 -Version <line>"
    }
    Add-Check $name $pass $detail
  }

  # Version-stamped sources: compare if both exist; mismatch often means unstamped dev vs published (still flag).
  $stamped = @(
    "scripts\injector.mjs",
    "assets\renderer-inject.js"
  )
  foreach ($relFile in $stamped) {
    $repoFile = Join-Path $repoRuntime $relFile
    $instFile = Join-Path $installRuntime $relFile
    $name = "hash:" + $relFile
    if (-not (Test-Path -LiteralPath $repoFile) -or -not (Test-Path -LiteralPath $instFile)) {
      Add-Check $name $false "repo or install missing"
      continue
    }
    $hRepo = Get-FileSha256 $repoFile
    $hInst = Get-FileSha256 $instFile
    $pass = ($hRepo -eq $hInst)
    $detail = if ($pass) {
      "match sha256=$($hRepo.Substring(0, 12))…"
    } else {
      "DRIFT (often unstamped repo vs install, or unpublished changes) repo=$($hRepo.Substring(0, 12))… install=$($hInst.Substring(0, 12))…"
    }
    Add-Check $name $pass $detail
  }

  # Security / contract markers on install control-plane (must match current product contract).
  $cpInstall = Join-Path $installRuntime "scripts\control-plane.mjs"
  $cpRepo = Join-Path $repoRuntime "scripts\control-plane.mjs"
  if (Test-Path -LiteralPath $cpInstall) {
    Add-Check "marker:tokensEqual" (Test-FileContains $cpInstall "tokensEqual") "install control-plane"
    Add-Check "marker:timingSafeEqual" (Test-FileContains $cpInstall "timingSafeEqual") "install control-plane"
    Add-Check "marker:header-only-comment" (
      (Test-FileContains $cpInstall "Query ?token= is ignored") -or
      (Test-FileContains $cpInstall "Intentionally ignore url.searchParams.get")
    ) "install control-plane documents header-only auth"
    # Anti-marker: old admit path should not remain as active compare (string still ok in comments).
    $raw = Get-Content -LiteralPath $cpInstall -Raw -Encoding UTF8
    $oldAuth = $raw -match 'qToken\s*!==\s*token\s*&&\s*hToken\s*!==\s*token'
    Add-Check "marker:no-legacy-qToken-auth" (-not $oldAuth) $(if ($oldAuth) { "legacy qToken!==token auth still present" } else { "legacy query auth absent" })
  } else {
    Add-Check "marker:control-plane present" $false $cpInstall
  }

  if (Test-Path -LiteralPath $cpRepo) {
    Add-Check "repo marker:tokensEqual" (Test-FileContains $cpRepo "tokensEqual") "repo control-plane (source of truth)"
  }

  # soft-reattach contract exists in repo (publish path depends on it).
  $soft = Join-Path $RepoRoot "scripts\windows\soft-reattach.ps1"
  if (Test-Path -LiteralPath $soft) {
    $softRaw = Get-Content -LiteralPath $soft -Raw -Encoding UTF8
    Add-Check "soft-reattach:--theme-dir" ($softRaw -match '--theme-dir') "scripts/windows/soft-reattach.ps1"
    Add-Check "soft-reattach:--state-root" ($softRaw -match '--state-root') "scripts/windows/soft-reattach.ps1"
  } else {
    Add-Check "soft-reattach.ps1" $false "missing in repo"
  }

  $failedCount = @($report.failed).Count
  if ($failedCount -eq 0) {
    $report.ok = $true
    $report.exitCode = 0
    $report.notes += "Install runtime matches repo contract for checked files/markers."
  } else {
    $report.ok = $false
    if ($report.exitCode -eq 3) { $report.exitCode = 1 }
    if ($report.exitCode -ne 2) { $report.exitCode = 1 }
    $report.notes += "Publish with: pwsh -File scripts\windows\publish-runtime.ps1 -RepoRoot `"$RepoRoot`" -Version <line>"
    $report.notes += "Then re-run this script and: node packages/core/cli.mjs doctor"
  }
} catch {
  if ($report.exitCode -eq 3 -and $report.failed.Count -eq 0) {
    $report.exitCode = 3
    $report.notes += $_.Exception.Message
    if (-not $Json) { Write-Host "ERROR: $($_.Exception.Message)" }
  }
}

if ($Json) {
  $report | ConvertTo-Json -Depth 6
} else {
  Write-Host ""
  Write-Host ("Result: ok={0} exit={1} failed={2}" -f $report.ok, $report.exitCode, (@($report.failed) -join ', '))
  foreach ($n in $report.notes) { Write-Host "note: $n" }
}

exit $report.exitCode
