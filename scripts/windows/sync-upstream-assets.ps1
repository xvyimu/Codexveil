#Requires -Version 5.1
<#
.SYNOPSIS
  RETIRED (ADR 0006). Former upstream sync helper — does nothing useful.

.DESCRIPTION
  Codexveil is an independent product line. There is no `upstream` remote and no
  scheduled vendor refresh. This script exits non-zero so CI/agents cannot
  accidentally re-introduce a dependency on a third-party git remote.

  Optional manual review of the frozen snapshot:
    vendor/dreamskin/   (offline only; see NOTICE + docs/adr/0006-independent-product-line.md)

.EXAMPLE
  pwsh -File scripts\windows\sync-upstream-assets.ps1
  # always fails with a pointer to ADR 0006
#>
[CmdletBinding()]
param(
  [string]$RepoRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
  [switch]$NoFetch,
  [switch]$UpdateBaseline
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

Write-Host @"
[retired] sync-upstream-assets.ps1
  Codexveil no longer tracks an upstream remote (ADR 0006).
  - git remote: origin only (xvyimu/Codexveil)
  - vendor/dreamskin: frozen third-party snapshot (NOTICE) — not auto-synced
  - promote into packages/runtime: manual one-off only, with documented diff

See: docs/adr/0006-independent-product-line.md
RepoRoot: $RepoRoot
"@

exit 2
