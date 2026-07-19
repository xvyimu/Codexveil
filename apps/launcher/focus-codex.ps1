#Requires -Version 5.1
# Shared focus entry for control-plane / external callers.
# Exit 0 focused, 2 not focused, 1 error.
[CmdletBinding()]
param([int]$TimeoutMs = 600)
$ErrorActionPreference = 'Stop'
try {
  $programRoot = Join-Path $env:LOCALAPPDATA 'Programs\CodexDreamSkin'
  $ui = Join-Path $programRoot 'lib\launcher-ui.ps1'
  if (-not (Test-Path -LiteralPath $ui)) {
    $ui = Join-Path $PSScriptRoot '..\..\packages\core-win\launcher-ui.ps1'
  }
  . $ui
  $current = Get-Content (Join-Path $programRoot 'current.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $runtimeRoot = Join-Path $programRoot (($current.relativeEnginePath -replace '/', '\'))
  $common = Join-Path $runtimeRoot 'scripts\common-windows.ps1'
  if (-not (Test-Path -LiteralPath $common)) { throw "common-windows missing: $common" }
  . $common
  $codex = Get-DreamSkinCodexInstall
  $eq = { param($a,$b) Test-DreamSkinPathEqual -Left $a -Right $b }
  $ok = Focus-CodexSkinWindow -Codex $codex -PathEqual $eq -TimeoutMs $TimeoutMs
  if ($ok) { Write-Output 'FOCUSED'; exit 0 }
  Write-Output 'MISS'
  exit 2
} catch {
  Write-Output ('ERR:' + $_.Exception.Message)
  exit 1
}
