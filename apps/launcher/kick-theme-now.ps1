#Requires -Version 5.1
# Instant theme kick. Prefer watch control plane; fallback to injector --once.
# Exit: 0 ok, 2 no-state, 3 incomplete/missing injector, 4 no-node, 5 cdp-closed, other=injector exit
param()
$ErrorActionPreference = "Stop"
$programRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$stateRoot = Join-Path $env:LOCALAPPDATA "CodexDreamSkin"
$statePath = Join-Path $stateRoot "state.json"
if (-not (Test-Path -LiteralPath $statePath)) { exit 2 }

# Optional shared helpers (install lib or repo packages)
foreach ($ui in @(
  (Join-Path $programRoot 'lib\launcher-ui.ps1'),
  (Join-Path $programRoot '..\..\packages\core-win\launcher-ui.ps1')
)) {
  if (Test-Path -LiteralPath $ui) { . $ui; break }
}

# 1) Control-plane kick (no second node)
if (Get-Command Invoke-CodexSkinControl -ErrorAction SilentlyContinue) {
  $cp = Invoke-CodexSkinControl -Action 'kick' -TimeoutMs 3500
  if ($null -ne $cp -and $cp.ok) { exit 0 }
}

$state = Get-Content -LiteralPath $statePath -Raw -Encoding utf8 | ConvertFrom-Json
$port = 0
try { $port = [int]$state.port } catch { exit 3 }
$browserId = [string]$state.browserId
if ($port -lt 1024 -or -not $browserId) { exit 3 }

# Prefer current runtime injector (state may lag after publish)
$injector = $null
try {
  $currentPath = Join-Path $programRoot "current.json"
  if (Test-Path -LiteralPath $currentPath) {
    $current = Get-Content -LiteralPath $currentPath -Raw -Encoding utf8 | ConvertFrom-Json
    $rel = [string]$current.relativeEnginePath
    if ($rel) {
      $candidate = Join-Path $programRoot (($rel -replace "/", "\") + "\scripts\injector.mjs")
      if (Test-Path -LiteralPath $candidate) { $injector = $candidate }
    }
  }
} catch {}
if (-not $injector -and $state.injectorPath -and (Test-Path -LiteralPath ([string]$state.injectorPath))) {
  $injector = [string]$state.injectorPath
}
if (-not $injector) { exit 3 }

$themeDir = Join-Path $stateRoot "active-theme"
if ($state.themeDir -and (Test-Path -LiteralPath ([string]$state.themeDir))) {
  $themeDir = [string]$state.themeDir
}

$node = $null
if ($state.nodePath -and (Test-Path -LiteralPath ([string]$state.nodePath))) {
  $node = [string]$state.nodePath
} else {
  $cmd = Get-Command node -ErrorAction SilentlyContinue
  if ($cmd) { $node = $cmd.Source }
}
if (-not $node) { exit 4 }

# Soft CDP probe
try {
  $req = [System.Net.HttpWebRequest]::Create(("http://127.0.0.1:{0}/json/version" -f $port))
  $req.Timeout = 800
  $req.ReadWriteTimeout = 800
  $req.Method = 'GET'
  $resp = $req.GetResponse()
  $resp.Close()
} catch {
  exit 5
}

$p = Start-Process -FilePath $node -ArgumentList @(
  $injector,
  "--once",
  "--port", "$port",
  "--browser-id", $browserId,
  "--theme-dir", $themeDir,
  "--timeout-ms", "8000"
) -WindowStyle Hidden -Wait -PassThru
if ($null -eq $p.ExitCode) { exit 0 }
exit [int]$p.ExitCode
