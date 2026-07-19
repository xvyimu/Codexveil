#Requires -Version 5.1
# Thin Chinese feedback entry for VBS / external callers (ASCII-only path args).
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Code,
  [string]$Detail = '',
  [int]$Ms = 3200
)
$ErrorActionPreference = 'Continue'
$programRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ui = Join-Path $programRoot 'lib\launcher-ui.ps1'
if (-not (Test-Path -LiteralPath $ui)) {
  $ui = Join-Path $PSScriptRoot '..\..\packages\core-win\launcher-ui.ps1'
}
if (Test-Path -LiteralPath $ui) {
  . $ui
  if ($Code -ieq 'first-run') {
    [void](Show-CodexSkinFirstRunGuide)
  } else {
    [void](Show-CodexSkinUserFeedback -Code $Code -Detail $Detail -Ms $Ms)
  }
  exit 0
}
exit 1
