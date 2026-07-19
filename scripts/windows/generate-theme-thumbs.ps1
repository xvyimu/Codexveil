# Generate thumbs for all catalog themes under CodexDreamSkin\themes (single node process).
param(
  [string]$ThemesRoot = (Join-Path $env:LOCALAPPDATA 'CodexDreamSkin\themes')
)
$ErrorActionPreference = 'Stop'
$thumbJs = Join-Path $PSScriptRoot '..\..\packages\runtime\scripts\thumb.mjs'
if (-not (Test-Path $thumbJs)) {
  $prog = Join-Path $env:LOCALAPPDATA 'Programs\CodexDreamSkin'
  $cur = Get-Content (Join-Path $prog 'current.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $thumbJs = Join-Path $prog (($cur.relativeEnginePath -replace '/', '\') + '\scripts\thumb.mjs')
}
if (-not (Test-Path $thumbJs)) { throw "thumb.mjs not found" }
if (-not (Test-Path -LiteralPath $ThemesRoot)) { throw "themes root missing: $ThemesRoot" }

$raw = & node $thumbJs --batch-root $ThemesRoot 2>&1 | Out-String
$exit = $LASTEXITCODE
$report = $null
try { $report = ($raw.Trim() | ConvertFrom-Json -ErrorAction Stop) } catch {}
if ($null -eq $report) {
  Write-Host $raw
  throw "thumb batch failed (exit=$exit)"
}

if ($report.items) {
  foreach ($item in $report.items) {
    $tag = if ($item.ok) { 'OK  ' } else { 'FAIL' }
    Write-Host ($tag + ' ' + $item.id + ' ' + $item.detail)
  }
}

$reportPath = Join-Path $ThemesRoot '.thumb-report.json'
$payload = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  themesRoot = $ThemesRoot
  total = [int]$report.total
  ok = [int]$report.ok
  fail = [int]$report.fail
  items = $report.items
}
$json = ($payload | ConvertTo-Json -Depth 6) + "`n"
[System.IO.File]::WriteAllText($reportPath, $json, [System.Text.UTF8Encoding]::new($false))
Write-Host ("DONE ok=$($report.ok) fail=$($report.fail) report=$reportPath")
if ([int]$report.fail -gt 0) { exit 2 }
exit 0
