# Release probe discipline helper (PROJECT §9.4).
# Prints home/conversation prerequisites + expected JSON keys.
# By default runs probe-session-dom.mjs and returns its exit code.
# Use -SkipRun for docs/CI-friendly print-only (exit 0).
param(
  [string]$RepoRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
  [int]$Port = 9335,
  [switch]$SkipRun
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

Write-Host "=== Run-ReleaseProbes (PROJECT §9.4) ==="
Write-Host "RepoRoot: $RepoRoot"
Write-Host ""
Write-Host "Prerequisites:"
Write-Host "  - Codex Desktop running (taskbar)"
Write-Host "  - CDP listening on port $Port"
Write-Host "  - Skin already injected (watch / soft reattach)"
Write-Host ""
Write-Host "Expectations (PROJECT §9.4):"
Write-Host '  home:          JSON keys "ok": true, "dreamStyle": true, "pass": true; exit 0'
Write-Host "                 (no page → exit 2)"
Write-Host '  conversation:  open a chat first, then re-run; "conversationPass": true; exit 0'
Write-Host "                 (fail → exit 3)"
Write-Host ""
Write-Host "Commands:"
Write-Host "  npm run probe:session"
Write-Host "  node scripts/windows/probe-session-dom.mjs"
Write-Host "  pwsh -NoProfile -File scripts/windows/Run-ReleaseProbes.ps1 [-Port $Port] [-SkipRun]"
Write-Host ""

if ($SkipRun) {
  Write-Host "SkipRun: not invoking CDP probe (print-only)."
  exit 0
}

$probe = Join-Path $RepoRoot "scripts\windows\probe-session-dom.mjs"
if (-not (Test-Path -LiteralPath $probe)) {
  Write-Error "probe script missing: $probe"
  exit 1
}

Write-Host "Running: node `"$probe`" $Port"
Push-Location $RepoRoot
try {
  & node $probe $Port
  $code = $LASTEXITCODE
} finally {
  Pop-Location
}
Write-Host "probe exit: $code"
exit $code
