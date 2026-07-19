#Requires -Version 5.1
<#
.SYNOPSIS
  上游同步助手（ADR 0002）。只读上游、只写 vendor/ 与基线 JSON，从不改 runtime、从不 apply PS。

.DESCRIPTION
  两条线：
    线 A 视觉资产 — 把 upstream/windows/assets/{dream-skin.css,renderer-inject.js}
      刷进 vendor/dreamskin/assets/，再打印 vendor ↔ packages/runtime/assets 的 diff 摘要。
      promote（搬进 runtime）由人决定，本脚本不做。
    线 B PowerShell 修复 — 列出上游自基线以来动过 windows/scripts/** 与 windows/*.ps1
      的 commit 标题，供人工判断+手动移植。本脚本不 apply 任何 PS 改动。

  基线记于 docs/upstream-sync.json 的 lastSyncedUpstreamSha。

.PARAMETER RepoRoot
  仓库根，默认脚本推断。
.PARAMETER NoFetch
  跳过 git fetch upstream（离线/已 fetch 时用）。
.PARAMETER UpdateBaseline
  本轮吸收确认后，把 lastSyncedUpstreamSha 更新到当前 upstream/main 并写回 JSON。
  仅在你已 promote 资产 + 移植完想要的 PS 修复后使用。

.EXAMPLE
  pwsh -File scripts\windows\sync-upstream-assets.ps1
  pwsh -File scripts\windows\sync-upstream-assets.ps1 -UpdateBaseline
#>
[CmdletBinding()]
param(
  [string]$RepoRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
  [switch]$NoFetch,
  [switch]$UpdateBaseline
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

# --- paths -------------------------------------------------------------------
$syncJsonPath   = Join-Path $RepoRoot 'docs\upstream-sync.json'
$vendorAssets   = Join-Path $RepoRoot 'vendor\dreamskin\assets'
$runtimeAssets  = Join-Path $RepoRoot 'packages\runtime\assets'
$upstreamRef    = 'upstream/main'
# Files that flow file-level (line A). Not dream-reference.jpg — art is local.
$assetFiles     = @('dream-skin.css', 'renderer-inject.js')
# Upstream pathspecs watched for PS fixes (line B).
$psPathspecs    = @('windows/scripts/', 'windows/*.ps1')

function Invoke-Git {
  param([Parameter(ValueFromRemainingArguments)]$Args)
  $out = & git -C $RepoRoot @Args 2>&1
  if ($LASTEXITCODE -ne 0) { throw "git $($Args -join ' ') failed: $out" }
  return $out
}

# --- guards ------------------------------------------------------------------
if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.git'))) {
  throw "Not a git repo: $RepoRoot"
}
$remotes = Invoke-Git remote
if ($remotes -notcontains 'upstream') {
  throw "No 'upstream' remote. Add it: git remote add upstream https://github.com/Fei-Away/Codex-Dream-Skin.git"
}

if (-not $NoFetch) {
  Write-Host "Fetching upstream..." -ForegroundColor Cyan
  Invoke-Git fetch upstream | Out-Null
}

$upstreamSha = (Invoke-Git rev-parse --short $upstreamRef).Trim()

# --- baseline ----------------------------------------------------------------
if (-not (Test-Path -LiteralPath $syncJsonPath)) {
  throw "Baseline missing: $syncJsonPath (see ADR 0002)"
}
$baseline = Get-Content -LiteralPath $syncJsonPath -Raw | ConvertFrom-Json
$baseSha  = [string]$baseline.lastSyncedUpstreamSha

Write-Host ""
Write-Host "Upstream sync review" -ForegroundColor Green
Write-Host ("  baseline (last synced) : " + $baseSha)
Write-Host ("  upstream/main now      : " + $upstreamSha)
if ($baseSha -eq $upstreamSha) {
  Write-Host "  -> already at upstream HEAD; nothing new." -ForegroundColor DarkGray
}

# --- line A: refresh vendor mirror, then diff vs runtime ---------------------
Write-Host ""
Write-Host "== Line A: visual assets ==" -ForegroundColor Green
New-Item -ItemType Directory -Force -Path $vendorAssets | Out-Null
$promoteHints = @()
foreach ($name in $assetFiles) {
  $upstreamPath = "windows/assets/$name"
  # Pull the upstream blob into the vendor mirror (only-write vendor).
  $blob = Invoke-Git show ("{0}:{1}" -f $upstreamRef, $upstreamPath)
  $vendorFile = Join-Path $vendorAssets $name
  [System.IO.File]::WriteAllText($vendorFile, ($blob -join "`n"), [System.Text.UTF8Encoding]::new($false))

  $runtimeFile = Join-Path $runtimeAssets $name
  if (-not (Test-Path -LiteralPath $runtimeFile)) {
    Write-Host ("  [new] {0} — runtime has no counterpart" -f $name) -ForegroundColor Yellow
    $promoteHints += $name
    continue
  }
  # diff vendor (fresh upstream) vs runtime (our local-overridden copy)
  $diff = & git -C $RepoRoot diff --no-index --stat -- $runtimeFile $vendorFile 2>$null
  if ($diff) {
    Write-Host ("  [differs] {0}" -f $name) -ForegroundColor Yellow
    $diff | ForEach-Object { Write-Host ("      " + $_) }
    $promoteHints += $name
  } else {
    Write-Host ("  [same] {0} — runtime matches upstream" -f $name) -ForegroundColor DarkGray
  }
}
if ($promoteHints.Count -gt 0) {
  Write-Host ""
  Write-Host "  Review the diff, then promote by hand (protects local overrides:" -ForegroundColor Cyan
  Write-Host "  de-blur / artDataUrl null-safe / SKIN_VERSION_TOKEN):" -ForegroundColor Cyan
  foreach ($n in $promoteHints) {
    Write-Host ("    Copy-Item `"$vendorAssets\$n`" `"$runtimeAssets\$n`"  # after reviewing diff")
  }
}

# --- line B: list upstream PS commits since baseline (discover only) ---------
Write-Host ""
Write-Host "== Line B: PowerShell fixes (discover only, manual port) ==" -ForegroundColor Green
$range = "$baseSha..$upstreamRef"
$logArgs = @('log', $range, '--oneline', '--no-merges', '--') + $psPathspecs
$commits = & git -C $RepoRoot @logArgs 2>$null
if ($commits) {
  Write-Host ("  upstream commits touching PS since {0}:" -f $baseSha)
  $commits | ForEach-Object { Write-Host ("    " + $_) }
  Write-Host ""
  Write-Host "  These are NOT applied. Read titles, decide what to port by hand into" -ForegroundColor Cyan
  Write-Host "  apps/launcher/ or packages/core-win/ (structure diverged; no auto-apply)." -ForegroundColor Cyan
} else {
  Write-Host "  none since baseline." -ForegroundColor DarkGray
}

# --- optional: advance baseline ----------------------------------------------
if ($UpdateBaseline) {
  $baseline.lastSyncedUpstreamSha = $upstreamSha
  $baseline.syncedAt = (Get-Date).ToUniversalTime().ToString('o')
  $json = ($baseline | ConvertTo-Json -Depth 5) + "`n"
  [System.IO.File]::WriteAllText($syncJsonPath, $json, [System.Text.UTF8Encoding]::new($false))
  Write-Host ""
  Write-Host ("Baseline advanced -> {0}. Commit docs/upstream-sync.json (and any promoted assets)." -f $upstreamSha) -ForegroundColor Green
} else {
  Write-Host ""
  Write-Host "Baseline unchanged. After promoting assets + porting PS fixes, re-run with -UpdateBaseline." -ForegroundColor DarkGray
}
