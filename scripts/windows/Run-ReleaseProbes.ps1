# Release probe discipline helper (PROJECT §9.4).
# Prints home/conversation prerequisites + expected JSON keys.
# By default: CDP precheck → run probe-session-dom.mjs → write docs/evidence/runs/ leave-behind.
# No CDP (default): write status=skipped evidence, exit 0 (scaffold OK; not a release pass).
# -SkipRun: print-only exit 0. -RequireCdp: no CDP → exit 2. -NoEvidence: skip repo file write.
param(
  [string]$RepoRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
  [int]$Port = 9335,
  [switch]$SkipRun,
  [string]$EvidenceDir = "",
  [switch]$NoEvidence,
  [switch]$RequireCdp
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

if ([string]::IsNullOrWhiteSpace($EvidenceDir)) {
  $EvidenceDir = Join-Path $RepoRoot "docs\evidence\runs"
}

function Format-NullableBool {
  param($Value)
  if ($null -eq $Value) { return "null" }
  if ($Value -is [bool]) { return ($(if ($Value) { "true" } else { "false" })) }
  return [string]$Value
}

function Test-CdpReachable {
  param([int]$CdpPort)
  $uri = "http://127.0.0.1:$CdpPort/json/list"
  try {
    $resp = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
    if ($resp.StatusCode -ne 200) { return $false }
    $body = $resp.Content
    if ([string]::IsNullOrWhiteSpace($body)) { return $false }
    try {
      $parsed = $body | ConvertFrom-Json
      # Prefer array (CDP list); also accept non-empty 200 body as reachable
      if ($parsed -is [System.Array]) { return $true }
      if ($null -ne $parsed) { return $true }
      return $true
    } catch {
      # HTTP 200 but not JSON — still treat as reachable endpoint
      return $true
    }
  } catch {
    return $false
  }
}

function Write-EvidenceFile {
  param(
    [string]$Dir,
    [hashtable]$Payload
  )
  if (-not (Test-Path -LiteralPath $Dir)) {
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
  }
  if (-not (Test-Path -LiteralPath $Dir)) {
    throw "EvidenceDir not creatable: $Dir"
  }
  $stamp = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
  $name = "probe-session-$stamp" + "Z.json"
  $path = Join-Path $Dir $name
  if (Test-Path -LiteralPath $path) {
    $hex = ("{0:x2}" -f (Get-Random -Maximum 256))
    $name = "probe-session-$stamp" + "Z-$hex.json"
    $path = Join-Path $Dir $name
  }
  $json = $Payload | ConvertTo-Json -Depth 20
  $tmp = $path + ".tmp." + [guid]::NewGuid().ToString("N")
  try {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($tmp, $json.TrimEnd() + "`n", $utf8NoBom)
    Move-Item -LiteralPath $tmp -Destination $path -Force
  } catch {
    if (Test-Path -LiteralPath $tmp) {
      Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
    throw
  }
  return $path
}

function New-SkipSummary {
  return [ordered]@{
    ok               = $null
    dreamStyle       = $null
    pass             = $null
    conversationPass = $null
    onHome           = $null
    inConversation   = $null
  }
}

function Get-SummaryFromProbe {
  param($ProbeObj)
  if ($null -eq $ProbeObj) { return (New-SkipSummary) }
  return [ordered]@{
    ok               = $(if ($null -ne $ProbeObj.ok) { [bool]$ProbeObj.ok } else { $null })
    dreamStyle       = $(if ($null -ne $ProbeObj.dreamStyle) { [bool]$ProbeObj.dreamStyle } else { $null })
    pass             = $(if ($null -ne $ProbeObj.pass) { [bool]$ProbeObj.pass } else { $null })
    conversationPass = $(if ($null -ne $ProbeObj.conversationPass) { [bool]$ProbeObj.conversationPass } else { $null })
    onHome           = $(if ($null -ne $ProbeObj.onHome) { [bool]$ProbeObj.onHome } else { $null })
    inConversation   = $(if ($null -ne $ProbeObj.inConversation) { [bool]$ProbeObj.inConversation } else { $null })
  }
}

Write-Host "=== Run-ReleaseProbes (PROJECT §9.4) ==="
Write-Host "RepoRoot: $RepoRoot"
Write-Host "EvidenceDir: $EvidenceDir"
Write-Host ""
Write-Host "Prerequisites:"
Write-Host "  - Codex Desktop running (taskbar)"
Write-Host "  - CDP listening on port $Port"
Write-Host "  - Skin already injected (watch / soft reattach)"
Write-Host "  - Tip: npm run doctor (optional precheck)"
Write-Host ""
Write-Host "Expectations (PROJECT §9.4):"
Write-Host '  home:          JSON keys "ok": true, "dreamStyle": true, "pass": true; exit 0'
Write-Host "                 (no page → exit 2)"
Write-Host '  conversation:  open a chat first, then re-run; "conversationPass": true; exit 0'
Write-Host "                 (fail → exit 3)"
Write-Host "  evidence:      docs/evidence/runs/probe-session-*.json (gitignored real dumps)"
Write-Host "  note:          status=skipped or -SkipRun ≠ release complete"
Write-Host ""
Write-Host "Commands:"
Write-Host "  npm run probe:session"
Write-Host "  node scripts/windows/probe-session-dom.mjs"
Write-Host "  pwsh -NoProfile -File scripts/windows/Run-ReleaseProbes.ps1 [-Port $Port] [-SkipRun] [-NoEvidence] [-RequireCdp]"
Write-Host ""

if ($SkipRun) {
  Write-Host "SkipRun: not invoking CDP probe (print-only)."
  Write-Host "Evidence file: (none)"
  Write-Host "summary: status=skipped exit=0 ok=null dreamStyle=null pass=null conversationPass=null"
  Write-Host "note: SkipRun is not release evidence; 未跑真机不算发版完成."
  exit 0
}

$probe = Join-Path $RepoRoot "scripts\windows\probe-session-dom.mjs"
$command = "node scripts/windows/probe-session-dom.mjs $Port"
$generatedAt = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$evidencePath = $null

if (-not (Test-Path -LiteralPath $probe)) {
  Write-Host "probe script missing: $probe"
  if (-not $NoEvidence) {
    try {
      $payload = [ordered]@{
        schemaVersion  = 1
        kind           = "release-probe-session"
        status         = "skipped"
        reason         = "probe-script-missing"
        generatedAt    = $generatedAt
        port           = $Port
        repoRoot       = $RepoRoot
        probeScript    = "scripts/windows/probe-session-dom.mjs"
        probeExitCode  = $null
        cdpReachable   = $null
        command        = $command
        summary        = (New-SkipSummary)
        probe          = $null
      }
      $evidencePath = Write-EvidenceFile -Dir $EvidenceDir -Payload $payload
      Write-Host "Evidence file: $evidencePath"
    } catch {
      Write-Error "failed to write evidence: $_"
      exit 1
    }
  } else {
    Write-Host "Evidence file: (none)"
  }
  Write-Host "summary: status=skipped exit=1 ok=null dreamStyle=null pass=null conversationPass=null"
  Write-Error "probe script missing: $probe"
  exit 1
}

$cdpOk = Test-CdpReachable -CdpPort $Port
Write-Host ("CDP reachable (port {0}): {1}" -f $Port, ($(if ($cdpOk) { "yes" } else { "no" })))

if (-not $cdpOk) {
  Write-Host "CDP unavailable — not running probe."
  Write-Host "conversation requires an open chat after CDP is up; 未跑真机不算发版完成."
  Write-Host "skipped / no-cdp: scaffold leave-behind only (not a release pass)."

  if (-not $NoEvidence) {
    try {
      $payload = [ordered]@{
        schemaVersion  = 1
        kind           = "release-probe-session"
        status         = "skipped"
        reason         = "no-cdp"
        generatedAt    = $generatedAt
        port           = $Port
        repoRoot       = $RepoRoot
        probeScript    = "scripts/windows/probe-session-dom.mjs"
        probeExitCode  = $null
        cdpReachable   = $false
        command        = $command
        summary        = (New-SkipSummary)
        probe          = $null
      }
      $evidencePath = Write-EvidenceFile -Dir $EvidenceDir -Payload $payload
      Write-Host "Evidence file: $evidencePath"
    } catch {
      Write-Error "failed to write evidence: $_"
      exit 1
    }
  } else {
    Write-Host "Evidence file: (none)"
  }

  Write-Host "summary: status=skipped exit=$(if ($RequireCdp) { 2 } else { 0 }) ok=null dreamStyle=null pass=null conversationPass=null"

  if ($RequireCdp) {
    Write-Host "RequireCdp: exiting 2 (cdp-unreachable / no-cdp)."
    exit 2
  }
  exit 0
}

# CDP available — run probe
Write-Host "home: current page can be probed now."
Write-Host "conversation: open any chat first, then re-run if you need conversationPass."
Write-Host "Running: node `"$probe`" $Port"

$stdoutLines = @()
$probeExit = 0
Push-Location $RepoRoot
try {
  $stdoutLines = & node $probe $Port 2>&1 | ForEach-Object { "$_" }
  $probeExit = $LASTEXITCODE
  if ($null -eq $probeExit) { $probeExit = 0 }
} finally {
  Pop-Location
}

$stdoutText = ($stdoutLines -join "`n").Trim()
if ($stdoutText) {
  Write-Host $stdoutText
}
Write-Host "probe exit: $probeExit"

$probeObj = $null
$summary = New-SkipSummary
$probeField = $null
$rawNote = $null

if (-not [string]::IsNullOrWhiteSpace($stdoutText)) {
  try {
    $probeObj = $stdoutText | ConvertFrom-Json
    $summary = Get-SummaryFromProbe -ProbeObj $probeObj
    $probeField = $probeObj
  } catch {
    $max = 32 * 1024
    $raw = $stdoutText
    if ($raw.Length -gt $max) { $raw = $raw.Substring(0, $max) }
    $rawNote = $raw
    $probeField = [ordered]@{ rawStdout = $raw }
    $summary = New-SkipSummary
  }
}

if ($null -ne $summary.inConversation -and -not [bool]$summary.inConversation) {
  Write-Host "note: inConversation=false — conversation not covered; open a chat and re-run for conversationPass."
}

if (-not $NoEvidence) {
  try {
    $payload = [ordered]@{
      schemaVersion  = 1
      kind           = "release-probe-session"
      status         = "ran"
      reason         = $null
      generatedAt    = $generatedAt
      port           = $Port
      repoRoot       = $RepoRoot
      probeScript    = "scripts/windows/probe-session-dom.mjs"
      probeExitCode  = [int]$probeExit
      cdpReachable   = $true
      command        = $command
      summary        = $summary
      probe          = $probeField
    }
    $evidencePath = Write-EvidenceFile -Dir $EvidenceDir -Payload $payload
    Write-Host "Evidence file: $evidencePath"
  } catch {
    Write-Error "failed to write evidence: $_"
    exit 1
  }
} else {
  Write-Host "Evidence file: (none)"
}

Write-Host (
  "summary: status=ran exit={0} ok={1} dreamStyle={2} pass={3} conversationPass={4}" -f `
    $probeExit,
    (Format-NullableBool $summary.ok),
    (Format-NullableBool $summary.dreamStyle),
    (Format-NullableBool $summary.pass),
    (Format-NullableBool $summary.conversationPass)
)

exit $probeExit
