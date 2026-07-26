# Unit tests for Get-CodexSkinRetentionPlan (debt#2). No filesystem access.
# Run: pwsh -NoProfile -File scripts/windows/lib/version-retention.test.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'version-retention.ps1')

$script:Failed = 0
function Assert-True([bool]$Cond, [string]$Msg) {
  if ($Cond) { Write-Host "ok: $Msg" }
  else { $script:Failed++; Write-Host "FAIL: $Msg" }
}
function Assert-Eq($Actual, $Expected, [string]$Msg) {
  $a = ($Actual -join ',')
  $e = ($Expected -join ',')
  Assert-True ($a -eq $e) "$Msg (got [$a], want [$e])"
}

# 1. Default keep=2: current + previous retained, older removed.
{
  $p = Get-CodexSkinRetentionPlan -CurrentRuntimeId 'v3' -PreviousRuntimeId 'v2' `
    -AllRuntimeIdsNewestFirst @('v3','v2','v1') -KeepVersions 2
  Assert-Eq $p.Keep @('v3','v2') 'keep=2 retains current+previous'
  Assert-Eq $p.Remove @('v1') 'keep=2 removes oldest'
}.Invoke()

# 2. No previous (backup missing): fill from newest dirs.
{
  $p = Get-CodexSkinRetentionPlan -CurrentRuntimeId 'v3' -PreviousRuntimeId $null `
    -AllRuntimeIdsNewestFirst @('v3','v2','v1') -KeepVersions 2
  Assert-Eq $p.Keep @('v3','v2') 'no-previous fills newest'
  Assert-Eq $p.Remove @('v1') 'no-previous removes rest'
}.Invoke()

# 3. Current not yet in dir list (just published, dir may be listed): dedupe.
{
  $p = Get-CodexSkinRetentionPlan -CurrentRuntimeId 'v3' -PreviousRuntimeId 'v2' `
    -AllRuntimeIdsNewestFirst @('v2','v1') -KeepVersions 2
  Assert-Eq $p.Keep @('v3','v2') 'current absent from dirs still kept'
  Assert-Eq $p.Remove @('v1') 'removes v1'
}.Invoke()

# 4. KeepVersions larger than available: remove nothing.
{
  $p = Get-CodexSkinRetentionPlan -CurrentRuntimeId 'v2' -PreviousRuntimeId 'v1' `
    -AllRuntimeIdsNewestFirst @('v2','v1') -KeepVersions 5
  Assert-Eq $p.Remove @() 'keep>=count removes nothing'
}.Invoke()

# 5. KeepVersions=1 still protects current+previous (safety floor).
{
  $p = Get-CodexSkinRetentionPlan -CurrentRuntimeId 'v3' -PreviousRuntimeId 'v2' `
    -AllRuntimeIdsNewestFirst @('v3','v2','v1') -KeepVersions 1
  Assert-True ($p.Keep -contains 'v3') 'keep=1 still retains current'
  Assert-True ($p.Keep -contains 'v2') 'keep=1 still retains previous'
  Assert-Eq $p.Remove @('v1') 'keep=1 removes only non-current/previous'
}.Invoke()

# 6. Re-publish same version (new hash dir each time): old hashes GC'd.
{
  $p = Get-CodexSkinRetentionPlan -CurrentRuntimeId '1.3.25-ccc' -PreviousRuntimeId '1.3.25-bbb' `
    -AllRuntimeIdsNewestFirst @('1.3.25-ccc','1.3.25-bbb','1.3.25-aaa') -KeepVersions 2
  Assert-Eq $p.Remove @('1.3.25-aaa') 're-publish same version GCs old hash dirs'
}.Invoke()

if ($script:Failed -gt 0) {
  Write-Host "version-retention.test: $script:Failed failure(s)"
  exit 1
}
Write-Host 'version-retention.test: pass'
