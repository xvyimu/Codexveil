# Unlock DreamSkin themes, import bundled catalog, optionally re-lock.
param(
  [switch]$KeepUnlocked,
  [string]$RepoRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
)

$ErrorActionPreference = "Stop"
$lockScript = Join-Path $env:LOCALAPPDATA "Programs\CodexDreamSkin\lock-themes.ps1"
$node = (Get-Command node -ErrorAction Stop).Source
$cli = Join-Path $RepoRoot "packages\core\cli.mjs"

if (Test-Path -LiteralPath $lockScript) {
  Write-Host "Unlocking themes store..."
  & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $lockScript -Unlock
}

Write-Host "Importing bundled themes from repo..."
& $node $cli import-themes
if ($LASTEXITCODE -ne 0) { throw "import-themes failed with exit $LASTEXITCODE" }

if (-not $KeepUnlocked -and (Test-Path -LiteralPath $lockScript)) {
  Write-Host "NOTE: leaving themes UNLOCKED so multi-theme catalog works."
  Write-Host "To re-lock single-skin mode later: $lockScript"
}

Write-Host "Done. Use: node packages/core/cli.mjs apply --theme genshin-night"
