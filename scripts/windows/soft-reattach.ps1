# Soft reattach shared by publish-runtime.ps1 and Install-Product.ps1.
# Stops old CodexDreamSkin versions/*/injector.mjs watchers and starts the new
# watch injector with explicit --theme-dir under StateRoot\active-theme so
# control-plane stateRootGuess lands on the real state root (not versions/<id>).
# Dot-source this file; do not execute as a standalone product entry.

function Invoke-CodexSkinSoftReattach {
  param(
    [Parameter(Mandatory = $true)][string]$RuntimeRoot,
    [Parameter(Mandatory = $true)][string]$RuntimeId,
    [Parameter(Mandatory = $true)][string]$StateRoot,
    [int]$Port = 9335
  )
  $nodeCmd = $null
  try { $nodeCmd = (Get-Command node -ErrorAction Stop).Source } catch {}
  $injPath = Join-Path $RuntimeRoot "scripts\injector.mjs"
  if (-not $nodeCmd -or -not (Test-Path -LiteralPath $injPath)) {
    Write-Warning "soft reattach skipped: node or injector missing"
    return $false
  }

  $browserId = $null
  $statePath = Join-Path $StateRoot "state.json"
  if (Test-Path -LiteralPath $statePath) {
    try {
      $st = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($st.browserId) { $browserId = [string]$st.browserId }
    } catch {}
  }

  $oldInjectors = @(
    Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
      Where-Object { $_.CommandLine -and ($_.CommandLine -match 'CodexDreamSkin\\versions\\.*injector\.mjs') }
  )
  $hadInjector = $oldInjectors.Count -gt 0
  foreach ($proc in $oldInjectors) {
    try {
      Write-Host "Stopping old injector PID $($proc.ProcessId)"
      Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    } catch {}
  }
  if (-not ($hadInjector -or $browserId)) {
    Write-Host "soft reattach: no live injector/browserId — click taskbar Codex after install/publish"
    return $false
  }

  $themeDir = Join-Path $StateRoot "active-theme"
  if (-not (Test-Path -LiteralPath $themeDir)) {
    New-Item -ItemType Directory -Force -Path $themeDir | Out-Null
  }

  $argList = @(
    $injPath,
    "--watch",
    "--port", "$Port",
    "--theme-dir", $themeDir,
    "--state-root", $StateRoot
  )
  if ($browserId) { $argList += @("--browser-id", $browserId) }

  Write-Host "soft reattach: starting watch injector on $RuntimeId (theme-dir=$themeDir state-root=$StateRoot)..."
  $started = Start-Process -FilePath $nodeCmd -ArgumentList $argList -WindowStyle Hidden -PassThru
  Start-Sleep -Milliseconds 800
  if ($started -and -not $started.HasExited -and (Test-Path -LiteralPath $statePath)) {
    try {
      $st2 = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
      $st2 | Add-Member -NotePropertyName injectorPid -NotePropertyValue $started.Id -Force
      $st2 | Add-Member -NotePropertyName injectorPath -NotePropertyValue $injPath -Force
      $st2 | Add-Member -NotePropertyName runtimeId -NotePropertyValue $RuntimeId -Force
      $st2 | Add-Member -NotePropertyName themeDir -NotePropertyValue $themeDir -Force
      $st2 | Add-Member -NotePropertyName updatedAt -NotePropertyValue ((Get-Date).ToUniversalTime().ToString("o")) -Force
      $json = ($st2 | ConvertTo-Json -Depth 8) + "`n"
      [System.IO.File]::WriteAllText($statePath, $json, [System.Text.UTF8Encoding]::new($false))
      Write-Host "soft reattach: injector PID=$($started.Id)"
      return $true
    } catch {
      Write-Warning ("soft reattach state patch: " + $_.Exception.Message)
    }
  }
  return $false
}
