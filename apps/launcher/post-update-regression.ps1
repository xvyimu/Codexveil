[CmdletBinding()]
param(
  [ValidateRange(1024, 65535)][int]$Port = 9335,
  [switch]$Repair,
  [switch]$Quiet
)
$ErrorActionPreference = "Stop"
# UTF-8 console bootstrap (PAIN-POINTS #22). Full helper also runs when launcher-ui is dotted.
try {
  & chcp.com 65001 | Out-Null
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  try { [Console]::OutputEncoding = $utf8 } catch {}
  try { [Console]::InputEncoding = $utf8 } catch {}
  $OutputEncoding = $utf8
} catch {}

# PSModulePath hardening for Windows PowerShell 5.1.
#
# 触发场景：从 pwsh (PS 7) 里 Start-Process powershell.exe 调本脚本时，
# 子进程会继承父进程的 PSModulePath——里面已被注入 PS 7 的 Documents\PowerShell\Modules /
# Program Files\PowerShell\Modules / scoop\apps\pwsh\...\Modules。这些目录里的
# Microsoft.PowerShell.Security 是 net5.0/net6.0 编译，PS 5.1 (.NET Framework)
# 加载会抛「无法加载该模块」，Get-AuthenticodeSignature 一进 common-windows.ps1
# 的 Get-DreamSkinNodeRuntime 就整条链失败——这正是 publish-runtime 之后 report 显示
# error / stale 的根因（见 PAIN-POINTS #11）。
if ($PSVersionTable.PSEdition -eq 'Desktop') {
  $ps5Modules = @(
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Modules'),
    (Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'),
    (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\Modules')
  )
  $env:PSModulePath = ($ps5Modules -join ';')
  try { Import-Module Microsoft.PowerShell.Security -ErrorAction Stop } catch {
    Write-Warning ("Import Microsoft.PowerShell.Security failed after PSModulePath reset: " + $_.Exception.Message)
  }
}
$programRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$stateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
$logPath = Join-Path $stateRoot 'post-update-regression.log'
$open = Join-Path $programRoot 'open-codex-dream-skin.ps1'
$smoke = Join-Path $programRoot 'smoke-dream-skin.ps1'
$fix = Join-Path $programRoot 'check-and-fix.ps1'
$reportPath = Join-Path $stateRoot 'post-update-report.json'

function Log([string]$m) {
  [System.IO.Directory]::CreateDirectory($stateRoot) | Out-Null
  [System.IO.File]::AppendAllText($logPath, ('{0:u} {1}' -f (Get-Date), $m) + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
  if (-not $Quiet) { Write-Host $m }
}

$report = [ordered]@{
  startedAt = (Get-Date).ToUniversalTime().ToString('o')
  port = $Port
  checks = @()
  pass = $false
  repaired = $false
  recommendations = @()
}

function Add-Check([string]$name, [bool]$ok, [string]$detail = '') {
  $script:report.checks += [ordered]@{ name = $name; pass = $ok; detail = $detail }
  if ($ok) { Log ("PASS  " + $name + $(if ($detail) { ' :: ' + $detail } else { '' })) }
  else { Log ("FAIL  " + $name + $(if ($detail) { ' :: ' + $detail } else { '' })) }
}

try {
  if (-not (Test-Path -LiteralPath $open)) { throw 'open-codex-dream-skin.ps1 missing' }
  if (-not (Test-Path -LiteralPath $smoke)) { throw 'smoke-dream-skin.ps1 missing' }

  $current = Get-Content (Join-Path $programRoot 'current.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $runtimeRoot = Join-Path $programRoot ($current.relativeEnginePath -replace '/', '\')
  . (Join-Path $runtimeRoot 'scripts\common-windows.ps1')
  . (Join-Path $runtimeRoot 'scripts\theme-windows.ps1')
  # launcher-ui: Test-CodexSkinInjectorPathFresh / Resolve-CodexSkinRuntimeRoot / Repair helpers
  $launcherUi = @(
    (Join-Path $programRoot 'lib\launcher-ui.ps1'),
    (Join-Path $runtimeRoot 'scripts\launcher-ui.ps1')
  ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if ($launcherUi) { . $launcherUi }

  $node = Get-DreamSkinNodeRuntime
  $codex = Get-DreamSkinCodexInstall
  $report.codex = [ordered]@{
    executable = $codex.Executable
    packageRoot = $codex.PackageRoot
    packageFullName = $codex.PackageFullName
    version = $codex.Version
  }
  $report.runtimeId = $current.runtimeId

  Add-Check 'runtime current.json' ($current.runtimeId -and (Test-Path -LiteralPath $runtimeRoot)) $current.runtimeId
  Add-Check 'codex package resolvable' ([bool]$codex.Executable -and (Test-Path -LiteralPath $codex.Executable)) $codex.Executable
  Add-Check 'open launcher present' (Test-Path -LiteralPath $open)

  $statePath = Join-Path $stateRoot 'state.json'
  $state = $null
  if (Test-Path -LiteralPath $statePath) {
    try { $state = Read-DreamSkinState -Path $statePath } catch {}
  }
  if ($state) {
    $report.savedState = [ordered]@{
      browserId = $state.browserId
      injectorPid = $state.injectorPid
      codexExe = $state.codexExe
      codexVersion = $state.codexVersion
      packageFullName = $state.codexPackageFullName
      injectorPath = $state.injectorPath
      runtimeId = $state.runtimeId
    }
    $packageDrift = -not (
      (Test-DreamSkinPathEqual -Left $state.codexExe -Right $codex.Executable) -and
      ("$($state.codexPackageFullName)" -ceq "$($codex.PackageFullName)")
    )
    Add-Check 'state package matches current Codex' (-not $packageDrift) (
      'state=' + $state.codexPackageFullName + ' current=' + $codex.PackageFullName
    )
    if ($packageDrift) {
      $report.recommendations += 'Codex Store package changed; Repair will re-probe and normalize state.'
      if ($Repair) {
        Log 'package drift detected; forcing repair reattach path'
      }
    }
  } else {
    Add-Check 'state.json present' $false 'missing or unreadable'
    $report.recommendations += 'No state yet; first successful open will create it.'
  }

  # Always rebind user launchers to skin entry after updates (idempotent)
  $rebind = Join-Path $programRoot 'install-all-skin-launchers.ps1'
  if (Test-Path -LiteralPath $rebind) {
    Log 'rebinding Codex/ChatGPT shortcuts to skin launcher'
    $pBind = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
      '-NoProfile','-ExecutionPolicy','Bypass','-File',$rebind
    ) -Wait -PassThru -WindowStyle Hidden
    Add-Check 'rebind skin launchers' ($pBind.ExitCode -eq 0) ('exit=' + $pBind.ExitCode)
  } else {
    Add-Check 'rebind skin launchers' $false 'install-all-skin-launchers.ps1 missing'
    $report.recommendations += 'Missing install-all-skin-launchers.ps1; shortcuts may reopen bare Codex after Store reset.'
  }

  # Ensure adaptive wait-shell exists for DOM renames
  $waitShell = Join-Path $stateRoot 'wait-shell.mjs'
  $waitSrc = Join-Path $runtimeRoot 'scripts\wait-shell.mjs'
  if (Test-Path -LiteralPath $waitSrc) {
    Copy-Item -LiteralPath $waitSrc -Destination $waitShell -Force
    Add-Check 'wait-shell adaptive probe installed' $true $waitShell
  } else {
    Add-Check 'wait-shell adaptive probe installed' (Test-Path -LiteralPath $waitShell) $waitShell
  }

  # CDP can flap briefly during theme kick / injector audit; soft-retry before declaring miss.
  $cdp = $null
  for ($i = 0; $i -lt 4 -and $null -eq $cdp; $i++) {
    $cdp = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $codex
    if ($null -eq $cdp) { Start-Sleep -Milliseconds 400 }
  }
  Add-Check 'CDP verified against current Codex' ($null -ne $cdp) $(if ($cdp) { $cdp.BrowserId } else { 'none' })

  # Always run smoke when CDP healthy; if not healthy and -Repair, open/fix first.
  # Prefer soft reattach (no -RestartExisting) when process is already up — avoids killing live sessions.
  if ($null -eq $cdp -and $Repair) {
    Log 'CDP missing; Repair requested -> open launcher (soft reattach first)'
    $argList = @('-NoProfile','-STA','-WindowStyle','Hidden','-ExecutionPolicy','RemoteSigned','-File',$open,'-Port',"$Port",'-NoPrompt')
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Wait -PassThru
    $cdp = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $codex
    if ($null -eq $cdp) {
      Log 'soft reattach still no CDP; retry open with -RestartExisting'
      $argList = @('-NoProfile','-STA','-WindowStyle','Hidden','-ExecutionPolicy','RemoteSigned','-File',$open,'-Port',"$Port",'-NoPrompt','-RestartExisting')
      $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Wait -PassThru
      $cdp = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $codex
    }
    $report.repaired = ($p.ExitCode -eq 0) -or ($null -ne $cdp)
    Add-Check 'repair open launcher' (($p.ExitCode -eq 0) -or ($null -ne $cdp)) ('exit=' + $p.ExitCode)
  } elseif ($null -eq $cdp -and -not $Repair) {
    $report.recommendations += 'CDP not up. Start taskbar Codex, or re-run with -Repair.'
  }

  # Reattach whenever runtime/injector drifted, package changed, or -Repair asked.
  # Without this, publish flips current.json but leaves the old watch injector
  # running; smoke then fails verify against the new scripts while the old
  # control-plane/renderer keep serving (seen on 1.3.22->1.3.23 publishes).
  $needsFix = $false
  $driftReason = ''
  if ($null -ne $cdp -and $null -ne $state) {
    try {
      if (Get-Command Test-CodexSkinInjectorPathFresh -ErrorAction SilentlyContinue) {
        # Resolve runtime info for freshness compare
        if (-not (Get-Variable -Name runtimeInfo -Scope Local -ErrorAction SilentlyContinue)) {
          if (Get-Command Resolve-CodexSkinRuntimeRoot -ErrorAction SilentlyContinue) {
            $runtimeInfo = Resolve-CodexSkinRuntimeRoot -ProgramRoot $programRoot
          }
        }
        if ($runtimeInfo) {
          $fresh = Test-CodexSkinInjectorPathFresh -State $state -RuntimeInfo $runtimeInfo
          if (-not $fresh.fresh) {
            $needsFix = $true
            $driftReason = [string]$fresh.reason
          }
        }
      } elseif ($state.runtimeId -and $current.runtimeId -and ("$($state.runtimeId)" -cne "$($current.runtimeId)")) {
        $needsFix = $true
        $driftReason = 'runtimeId-drift'
      }
    } catch {}
  }
  if ($Repair) {
    if ($null -ne $cdp) { $needsFix = $true }
    if ($state -and $report.checks | Where-Object { $_.name -eq 'state package matches current Codex' -and -not $_.pass }) {
      $needsFix = $true
      if (-not $driftReason) { $driftReason = 'package-drift' }
    }
  }
  if ($needsFix) {
    Log ('running check-and-fix -Quiet (normalize/reattach' + $(if ($driftReason) { '; ' + $driftReason } else { '' }) + ')')
    $pFix = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
      '-NoProfile','-STA','-WindowStyle','Hidden','-ExecutionPolicy','RemoteSigned',
      '-File',$fix,'-Port',"$Port",'-Quiet'
    ) -Wait -PassThru
    $report.repaired = $report.repaired -or ($pFix.ExitCode -eq 0)
    Add-Check 'check-and-fix' ($pFix.ExitCode -eq 0) ('exit=' + $pFix.ExitCode + $(if ($driftReason) { ' ' + $driftReason } else { '' }))
    # Refresh state after reattach so smoke sees the new injector path.
    if (Test-Path -LiteralPath $statePath) {
      try { $state = Read-DreamSkinState -Path $statePath } catch {}
    }
  }

  $smokeOut = Join-Path $stateRoot 'post-update-smoke-out.txt'
  $smokeErr = Join-Path $stateRoot 'post-update-smoke-err.txt'
  $pSmoke = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile','-ExecutionPolicy','RemoteSigned','-File',$smoke,'-Port',"$Port"
  ) -Wait -PassThru -RedirectStandardOutput $smokeOut -RedirectStandardError $smokeErr
  $smokeText = ''
  if (Test-Path -LiteralPath $smokeOut) { $smokeText = Get-Content -LiteralPath $smokeOut -Raw }
  Add-Check 'smoke-dream-skin.ps1' ($pSmoke.ExitCode -eq 0 -and $smokeText -match 'SMOKE_PASS') ('exit=' + $pSmoke.ExitCode)
  $report.smokeExit = $pSmoke.ExitCode

  $failed = @($report.checks | Where-Object { -not $_.pass })
  $report.pass = ($failed.Count -eq 0)
  $report.finishedAt = (Get-Date).ToUniversalTime().ToString('o')
  try {
    $report.currentRuntimeId = [string]$current.runtimeId
    $report.publishedRuntimeId = [string]$current.runtimeId
    $report.stale = $false
  } catch {}
  $json = $report | ConvertTo-Json -Depth 6
  [System.IO.File]::WriteAllText($reportPath, $json, [System.Text.UTF8Encoding]::new($false))
  Log ('report -> ' + $reportPath)

  if ($report.pass) {
    # User-facing tip: keep using skinned taskbar entry after Store updates.
    try {
      $fb = Join-Path $programRoot 'show-feedback.ps1'
      if (Test-Path -LiteralPath $fb) {
        Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
          '-NoProfile','-ExecutionPolicy','Bypass','-File',$fb,'-Code','post-update'
        ) | Out-Null
      }
    } catch {}
    try {
      Write-CodexSkinOpenStatus -Phase 'ready' -Detail 'post-update pass' -Code 'post-update' -Ok $true
    } catch {
      # open-status helper may be unavailable if launcher-ui not loaded
      try {
        $statusPath = Join-Path $stateRoot 'open-status.json'
        $obj = @{ phase = 'ready'; detail = 'post-update pass'; code = 'post-update'; ok = $true; updatedAt = (Get-Date).ToUniversalTime().ToString('o') }
        [System.IO.File]::WriteAllText($statusPath, (($obj | ConvertTo-Json -Compress) + "`n"), [Text.UTF8Encoding]::new($false))
      } catch {}
    }
    if (-not $Quiet) { Write-Host 'POST_UPDATE_PASS' }
    exit 0
  }
  if (-not $Quiet) {
    Write-Host 'POST_UPDATE_FAIL'
    Write-Host 'Recommendations:'
    foreach ($r in $report.recommendations) { Write-Host (' - ' + $r) }
  }
  exit 2
} catch {
  Log ('failed: ' + $_.Exception.Message)
  $report.pass = $false
  $report.error = $_.Exception.Message
  $report.finishedAt = (Get-Date).ToUniversalTime().ToString('o')
  try {
    [System.IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Depth 6), [System.Text.UTF8Encoding]::new($false))
  } catch {}
  if (-not $Quiet) { Write-Host ('POST_UPDATE_ERROR: ' + $_.Exception.Message) }
  exit 1
}
