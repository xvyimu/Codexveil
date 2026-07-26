# Pure retention-plan helper for publish-runtime GC (debt#2).
# No filesystem access: takes runtime-id lists, returns keep/remove plan so the
# selection logic is unit-testable without running publish-runtime.ps1.
# Keep ASCII-only: publish-runtime may run under Windows PowerShell 5.1.

function Get-CodexSkinRetentionPlan {
  [CmdletBinding()]
  param(
    # runtime id of the just-published version; never removed.
    [Parameter(Mandatory = $true)][string]$CurrentRuntimeId,
    # previous current (from current.json.bak); kept if present. Optional.
    [AllowNull()][AllowEmptyString()][string]$PreviousRuntimeId,
    # all existing version dir names, newest first (caller sorts by LastWriteTime desc).
    [AllowNull()][string[]]$AllRuntimeIdsNewestFirst,
    # total versions to retain (>=1). Default 2 = current + one previous.
    [int]$KeepVersions = 2
  )

  if ($KeepVersions -lt 1) { $KeepVersions = 1 }
  $all = @($AllRuntimeIdsNewestFirst | Where-Object { $_ })

  $keep = New-Object 'System.Collections.Generic.List[string]'
  $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

  function _Add([string]$id) {
    if ([string]::IsNullOrWhiteSpace($id)) { return }
    if ($seen.Add($id)) { [void]$keep.Add($id) }
  }

  # Always retain current + explicit previous first (even if KeepVersions is small,
  # current + previous are safety-critical for rollback).
  _Add $CurrentRuntimeId
  _Add $PreviousRuntimeId

  # Fill remaining budget with newest dirs.
  foreach ($id in $all) {
    if ($keep.Count -ge $KeepVersions) { break }
    _Add $id
  }

  $remove = @($all | Where-Object { -not $seen.Contains($_) })

  return [pscustomobject]@{
    Keep         = $keep.ToArray()
    Remove       = $remove
    KeepVersions = $KeepVersions
  }
}
