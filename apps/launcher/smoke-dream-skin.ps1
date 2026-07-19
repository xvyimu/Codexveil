[CmdletBinding()]
param([ValidateRange(1024, 65535)][int]$Port = 9335)
$ErrorActionPreference = 'Stop'
$programRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$stateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
$open = Join-Path $programRoot 'open-codex-dream-skin.ps1'
$fail = 0
function Assert-True([bool]$cond, [string]$name) {
  if ($cond) { Write-Host ("PASS  " + $name) } else { Write-Host ("FAIL  " + $name); $script:fail++ }
}
Write-Host '=== Codex Skin smoke (multi-theme product line) ==='
$current = Get-Content (Join-Path $programRoot 'current.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$runtimeRoot = Join-Path $programRoot ($current.relativeEnginePath -replace '/', '\')
. (Join-Path $runtimeRoot 'scripts\common-windows.ps1')
. (Join-Path $runtimeRoot 'scripts\theme-windows.ps1')
$node = Get-DreamSkinNodeRuntime
$codex = Get-DreamSkinCodexInstall
$inj = Join-Path $runtimeRoot 'scripts\injector.mjs'
$statePath = Join-Path $stateRoot 'state.json'
Assert-True (Test-Path -LiteralPath $open) 'open-codex-dream-skin.ps1 exists'
Assert-True (Test-Path -LiteralPath $inj) 'injector.mjs exists'
Assert-True (Test-Path -LiteralPath (Join-Path $stateRoot 'active-theme\theme.json')) 'active-theme exists'
Assert-True ($null -ne $current.runtimeId) ('runtimeId=' + $current.runtimeId)

$locked = Test-DreamSkinThemesLocked -StateRoot $stateRoot
$catalog = @(Get-ChildItem -LiteralPath (Join-Path $stateRoot 'themes') -Directory -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -notmatch '^\.' })
if ($locked) {
  Write-Host 'MODE  single-skin lock'
  Assert-True $true 'themes locked (single-skin mode)'
} else {
  Write-Host 'MODE  multi-theme catalog'
  Assert-True (-not $locked) 'themes unlocked for multi-theme'
  Assert-True ($catalog.Count -ge 1) ('catalog has themes (count=' + $catalog.Count + ')')
}

$cdp = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $codex
Assert-True ($null -ne $cdp) 'CDP verified on port'
$state = $null
if (Test-Path -LiteralPath $statePath) { $state = Read-DreamSkinState -Path $statePath }
Assert-True ($null -ne $state) 'state.json readable'
if ($state -and $cdp) {
  Assert-True ($state.browserId -ceq $cdp.BrowserId) 'state browserId matches CDP'
  $alive = Test-DreamSkinInjectorAlive -State $state
  Assert-True $alive 'injector process alive'
  $verify = Invoke-DreamSkinNative -FilePath $node.Path -ArgumentList @(
    $inj, '--verify', '--port', "$Port", '--browser-id', $cdp.BrowserId, '--timeout-ms', '15000'
  )
  Assert-True ($verify.ExitCode -eq 0) 'verify pass'
}

$payload = & $node.Path $inj --check-payload --theme-dir (Join-Path $stateRoot 'active-theme') | Out-String
# In multi-theme mode catalog may include multiple entries; require at least 1 and budget OK.
Assert-True ($payload -match '"themeCount":\s*([1-9]\d*)') 'payload themeCount>=1'
Assert-True ($payload -match '"withinPayloadBudget":\s*true') 'payload within budget'
if ($payload -match '"themeCount":\s*(\d+)') {
  $tc = [int]$Matches[1]
  Write-Host ("INFO  payload themeCount=" + $tc)
  if (-not $locked) {
    Assert-True ($tc -ge 2 -or $catalog.Count -le 1) 'multi-theme payload carries catalog (or catalog empty)'
  }
}

if ($fail -eq 0 -and $cdp -and $state -and (Test-DreamSkinInjectorAlive -State $state)) {
  Assert-True $true 'healthy open skipped (preflight green)'
} else {
  $p = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile','-STA','-WindowStyle','Hidden','-ExecutionPolicy','RemoteSigned',
    '-File',$open,'-Port',"$Port",'-NoPrompt'
  ) -Wait -PassThru
  Assert-True ($p.ExitCode -eq 0) 'healthy open exit 0'
}

# CLI hot path present
$cli = 'D:\orca\codex-skin\packages\core\cli.mjs'
if (Test-Path -LiteralPath $cli) {
  Assert-True $true 'codex-skin CLI present'
} else {
  Assert-True $false 'codex-skin CLI present'
}

# Session/home DOM probe (conversation nodes optional when still on home)
$probe = Join-Path $programRoot 'probe-session-dom.mjs'
if (-not (Test-Path -LiteralPath $probe)) {
  $probe = Join-Path $runtimeRoot 'scripts\probe-session-dom.mjs'
}
if (-not (Test-Path -LiteralPath $probe)) {
  $probe = 'D:\orca\codex-skin\scripts\windows\probe-session-dom.mjs'
}
if ((Test-Path -LiteralPath $probe) -and $cdp) {
  $probeOut = & $node.Path $probe $Port 2>&1 | Out-String
  $probeOk = ($LASTEXITCODE -eq 0) -or ($probeOut -match '"pass":\s*true')
  Assert-True $probeOk 'session-dom probe pass (shell+skin)'
  if ($probeOut -match '"inConversation":\s*true') {
    Assert-True ($probeOut -match '"conversationPass":\s*true') 'conversation markers when in chat'
  } else {
    Write-Host 'INFO  probe on home route (conversation markers optional)'
  }
} else {
  Write-Host 'INFO  session-dom probe skipped (missing script or CDP)'
}

if ($fail -eq 0) {
  Write-Host 'SMOKE_PASS'
  exit 0
} else {
  Write-Host ("SMOKE_FAIL count=" + $fail)
  exit 2
}
