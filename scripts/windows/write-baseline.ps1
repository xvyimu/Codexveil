# Generate docs/BASELINE.generated.md from git HEAD + `node packages/core/cli.mjs doctor`.
# Exit 0 only when file is fully written. On git/doctor/JSON failure: exit ≠0 and do not leave a corrupt baseline.
param(
  [string]$RepoRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
)

$ErrorActionPreference = "Stop"
try { & chcp.com 65001 | Out-Null } catch {}
try {
  [Console]::OutputEncoding = [Text.Encoding]::UTF8
} catch {}
try {
  [Console]::InputEncoding = [Text.Encoding]::UTF8
} catch {}
$OutputEncoding = [Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $RepoRoot)) {
  Write-Error "RepoRoot not found: $RepoRoot"
  exit 1
}

$fullHead = & git -C $RepoRoot rev-parse HEAD 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($fullHead)) {
  Write-Error "git rev-parse HEAD failed (not a git repo or git missing)"
  exit 1
}
$fullHead = $fullHead.Trim()

$shortHead = & git -C $RepoRoot rev-parse --short HEAD 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($shortHead)) {
  Write-Error "git rev-parse --short HEAD failed"
  exit 1
}
$shortHead = $shortHead.Trim()

$doctorStdout = $null
$doctorExit = 0
Push-Location $RepoRoot
try {
  $doctorStdout = & node packages/core/cli.mjs doctor 2>&1 | Out-String
  $doctorExit = $LASTEXITCODE
} finally {
  Pop-Location
}

if ($doctorExit -ne 0) {
  Write-Error "doctor exited $doctorExit"
  if ($doctorStdout) { Write-Host $doctorStdout }
  exit $doctorExit
}

$jsonText = $doctorStdout.Trim()
# doctor may print only JSON; if mixed, take last JSON object-ish line blob
try {
  $j = $jsonText | ConvertFrom-Json
} catch {
  Write-Error "doctor stdout is not valid JSON"
  if ($doctorStdout) { Write-Host $doctorStdout }
  exit 1
}

$expectedRuntimeId = $null
$fresh = $null
if ($null -ne $j.injectorPathFreshness) {
  $expectedRuntimeId = $j.injectorPathFreshness.expectedRuntimeId
  $fresh = $j.injectorPathFreshness.fresh
}
$themeCount = $j.themeCount
$generatedAt = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$generateCommand = "pwsh -NoProfile -File scripts/windows/write-baseline.ps1"

# Format nullable fields for markdown table
function Format-Cell($v) {
  if ($null -eq $v) { return "null" }
  if ($v -is [bool]) { return ($(if ($v) { "true" } else { "false" })) }
  return [string]$v
}

$md = @"
<!-- 由 scripts/windows/write-baseline.ps1 生成；勿手改。重跑：pwsh -NoProfile -File scripts/windows/write-baseline.ps1 -->
# BASELINE (generated)

| 字段 | 值 |
|------|-----|
| fullHead | $fullHead |
| shortHead | $shortHead |
| expectedRuntimeId | $(Format-Cell $expectedRuntimeId) |
| fresh | $(Format-Cell $fresh) |
| themeCount | $(Format-Cell $themeCount) |
| generatedAt | $generatedAt |
| generateCommand | ``$generateCommand`` |
"@

$outPath = Join-Path $RepoRoot "docs\BASELINE.generated.md"
$tmpPath = Join-Path $RepoRoot ("docs\BASELINE.generated.md.tmp." + [guid]::NewGuid().ToString("N"))
try {
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($tmpPath, $md.TrimEnd() + "`n", $utf8NoBom)
  Move-Item -LiteralPath $tmpPath -Destination $outPath -Force
} catch {
  if (Test-Path -LiteralPath $tmpPath) {
    Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue
  }
  Write-Error "failed to write baseline: $_"
  exit 1
}

Write-Host "Wrote $outPath"
Write-Host ("  shortHead={0} expectedRuntimeId={1} fresh={2} themeCount={3}" -f $shortHead, (Format-Cell $expectedRuntimeId), (Format-Cell $fresh), (Format-Cell $themeCount))
exit 0
