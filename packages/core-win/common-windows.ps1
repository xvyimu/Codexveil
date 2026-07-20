. (Join-Path $PSScriptRoot 'config-utf8.ps1')

function Enter-DreamSkinOperationLock {
  $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $mutex = [System.Threading.Mutex]::new($false, "Local\CodexDreamSkin.$sid.Operation")
  $acquired = $false
  try {
    $acquired = $mutex.WaitOne(0)
  } catch [System.Threading.AbandonedMutexException] {
    $acquired = $true
  }
  if (-not $acquired) {
    $mutex.Dispose()
    throw 'Another Codex Dream Skin install, start, restore, or verify operation is already running.'
  }
  return $mutex
}

function Exit-DreamSkinOperationLock {
  param([Parameter(Mandatory = $true)][System.Threading.Mutex]$Mutex)
  try { $Mutex.ReleaseMutex() } finally { $Mutex.Dispose() }
}

function Assert-DreamSkinPort {
  param([Parameter(Mandatory = $true)][int]$Port)
  if ($Port -lt 1024 -or $Port -gt 65535) { throw "Port must be between 1024 and 65535: $Port" }
}

function Test-DreamSkinPathEqual {
  param([string]$Left, [string]$Right)
  if (-not $Left -or -not $Right) { return $false }
  try {
    return ([System.IO.Path]::GetFullPath($Left).TrimEnd('\') -ieq [System.IO.Path]::GetFullPath($Right).TrimEnd('\'))
  } catch {
    return $false
  }
}

function Test-DreamSkinPathWithin {
  param([string]$Path, [string]$Root)
  if (-not $Path -or -not $Root) { return $false }
  try {
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $prefix = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    return $fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
  } catch {
    return $false
  }
}

function Test-DreamSkinCommandLineToken {
  param([string]$CommandLine, [string]$Token)
  if (-not $CommandLine -or -not $Token) { return $false }
  $pattern = '(?i)(?:^|[\s"])' + [regex]::Escape($Token) + '(?=$|[\s"])'
  return [regex]::IsMatch($CommandLine, $pattern)
}

function Test-DreamSkinTrayCommandLine {
  param([string]$CommandLine, [string]$TrayScript)
  if (-not $CommandLine -or -not $TrayScript) { return $false }
  try { $fullTrayScript = [System.IO.Path]::GetFullPath($TrayScript) } catch { return $false }
  foreach ($unsafeMode in @('-Command', '-EncodedCommand', '-C', '-E')) {
    if (Test-DreamSkinCommandLineToken -CommandLine $CommandLine -Token $unsafeMode) { return $false }
  }
  return (Test-DreamSkinCommandLineToken -CommandLine $CommandLine -Token '-File') -and
    (Test-DreamSkinCommandLineToken -CommandLine $CommandLine -Token $fullTrayScript)
}

function Stop-DreamSkinTrayProcess {
  param(
    [Parameter(Mandatory = $true)][string]$TrayScript,
    [int]$ExcludeProcessId = $PID
  )
  $fullTrayScript = [System.IO.Path]::GetFullPath($TrayScript)
  $processes = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'" `
    -ErrorAction Stop
  foreach ($process in $processes) {
    if ($process.ProcessId -eq $ExcludeProcessId -or -not $process.CommandLine) { continue }
    if (Test-DreamSkinTrayCommandLine -CommandLine $process.CommandLine -TrayScript $fullTrayScript) {
      Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
      Wait-Process -Id $process.ProcessId -Timeout 5 -ErrorAction SilentlyContinue
    }
  }
}

function ConvertTo-DreamSkinProcessArgument {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)
  if ($Value.Contains('"')) { throw 'Process arguments containing a double quote are not supported.' }
  if ($Value -notmatch '\s') { return $Value }
  $escaped = [regex]::Replace($Value, '(\\+)$', '$1$1')
  return '"' + $escaped + '"'
}

function Get-DreamSkinProcessExecutablePath {
  param([Parameter(Mandatory = $true)][object]$ProcessInfo)
  if ($ProcessInfo.ExecutablePath) { return "$($ProcessInfo.ExecutablePath)" }
  try {
    $process = Get-Process -Id ([int]$ProcessInfo.ProcessId) -ErrorAction Stop
    if ($process.Path) { return "$($process.Path)" }
    return "$($process.MainModule.FileName)"
  } catch {
    return $null
  }
}

# Windows PowerShell 5.1 promotes redirected native-command stderr lines to
# ErrorRecords; while $ErrorActionPreference is 'Stop' the first stderr line
# becomes a terminating NativeCommandError before the exit code can be read.
# Run the command with the preference relaxed and report output + exit code.
function Invoke-DreamSkinNative {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$ArgumentList = @(),
    [switch]$DiscardStderr
  )
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    if ($DiscardStderr) {
      $output = @(& $FilePath @ArgumentList 2>$null | ForEach-Object { "$_" })
    } else {
      $output = @(& $FilePath @ArgumentList 2>&1 | ForEach-Object { "$_" })
    }
    return [pscustomobject]@{ Output = $output; ExitCode = $LASTEXITCODE }
  } finally {
    $ErrorActionPreference = $previousPreference
  }
}

function Get-DreamSkinNodeRuntime {
  param([int]$MinimumMajor = 22)

  $command = Get-Command node.exe -ErrorAction SilentlyContinue
  if (-not $command) { $command = Get-Command node -ErrorAction SilentlyContinue }
  if (-not $command) { throw "Node.js $MinimumMajor or newer is required and was not found in PATH." }
  $versionProbe = Invoke-DreamSkinNative -FilePath $command.Source -ArgumentList @('-p', 'process.versions.node') -DiscardStderr
  $version = ($versionProbe.Output -join '').Trim()
  if ($versionProbe.ExitCode -ne 0 -or -not $version) { throw 'The Node.js runtime could not be validated.' }
  $pathProbe = Invoke-DreamSkinNative -FilePath $command.Source -ArgumentList @('-p', 'process.execPath') -DiscardStderr
  $runtimePath = ($pathProbe.Output -join '').Trim()
  if ($pathProbe.ExitCode -ne 0 -or -not $runtimePath -or -not (Test-Path -LiteralPath $runtimePath)) {
    throw 'The Node.js executable path could not be validated.'
  }
  $signature = Get-AuthenticodeSignature -FilePath $runtimePath
  $subject = "$($signature.SignerCertificate.Subject)"
  if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or
    $subject -notmatch '(?i)(?:^|,)CN=OpenJS Foundation(?:,|$)') {
    throw "Node.js runtime must have a valid OpenJS Foundation signature: $runtimePath"
  }
  $major = 0
  if (-not [int]::TryParse(($version -split '\.')[0], [ref]$major) -or $major -lt $MinimumMajor) {
    throw "Node.js $MinimumMajor or newer is required; found $version at $runtimePath."
  }
  return [pscustomobject]@{ Path = $runtimePath; Version = $version; Major = $major; SignatureSubject = $subject }
}

function ConvertTo-DreamSkinCodexInstall {
  param([Parameter(Mandatory = $true)][object]$Package)
  # Compatibility: Store updates may change SignatureKind/layout. Accept OpenAI.Codex
  # packages that expose a launchable desktop exe under app\.
  $name = "$($Package.Name)"
  if ($name -notmatch '^(OpenAI\.Codex|OpenAI\.ChatGPT)$') { return $null }
  if (-not $Package.InstallLocation -or -not $Package.PackageFullName -or -not $Package.PackageFamilyName) {
    return $null
  }
  if ([bool]$Package.IsFramework) { return $null }

  $packageRoot = "$($Package.InstallLocation)"
  $exeCandidates = @(
    (Join-Path $packageRoot 'app\ChatGPT.exe'),
    (Join-Path $packageRoot 'app\Codex.exe'),
    (Join-Path $packageRoot 'ChatGPT.exe'),
    (Join-Path $packageRoot 'Codex.exe')
  )
  $executable = $null
  foreach ($candidate in $exeCandidates) {
    if (Test-Path -LiteralPath $candidate) { $executable = $candidate; break }
  }
  if (-not $executable) { return $null }

  return [pscustomobject]@{
    PackageRoot = $packageRoot
    Executable = $executable
    Version = "$($Package.Version)"
    PackageFullName = "$($Package.PackageFullName)"
    PackageFamilyName = "$($Package.PackageFamilyName)"
    SignatureKind = "$($Package.SignatureKind)"
  }
}

function Get-DreamSkinRegisteredCodexInstalls {
  # Prefer exact name, then fuzzy OpenAI.*Codex* for future package renames.
  $packages = @()
  try {
    $packages += @(Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction SilentlyContinue)
  } catch {}
  try {
    $packages += @(Get-AppxPackage -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match 'OpenAI\.(Codex|ChatGPT)' -and -not $_.IsFramework })
  } catch {}

  $installs = @()
  $seen = @{}
  foreach ($package in ($packages | Sort-Object Version -Descending)) {
    $key = "$($package.PackageFullName)"
    if ($seen.ContainsKey($key)) { continue }
    $seen[$key] = $true
    $install = ConvertTo-DreamSkinCodexInstall -Package $package
    if ($null -ne $install) { $installs += $install }
  }
  return @($installs | Sort-Object {
    $v = $null
    if ([version]::TryParse([string]$_.Version, [ref]$v)) { $v } else { [version]'0.0' }
  } -Descending)
}

function Get-DreamSkinCodexInstall {
  $installs = @(Get-DreamSkinRegisteredCodexInstalls)
  if ($installs.Count -gt 0) { return $installs[0] }

  # Fallback: running desktop process path (helps mid-upgrade / path remap windows)
  foreach ($proc in @(Get-CimInstance Win32_Process -Filter "Name='ChatGPT.exe' or Name='Codex.exe'" -ErrorAction SilentlyContinue)) {
    if (-not $proc.ExecutablePath) { continue }
    if ($proc.CommandLine -match '\s--type=') { continue }
    $exe = [string]$proc.ExecutablePath
    if ($exe -notmatch 'OpenAI\.Codex|ChatGPT\.exe|\\app\\Codex\.exe') { continue }
    if (-not (Test-Path -LiteralPath $exe)) { continue }
    $root = Split-Path -Parent (Split-Path -Parent $exe)
    if ($exe -match '\\app\\[^\\]+\.exe$') {
      $root = Split-Path -Parent (Split-Path -Parent $exe)
    }
    return [pscustomobject]@{
      PackageRoot = $root
      Executable = $exe
      Version = 'running'
      PackageFullName = 'running-process'
      PackageFamilyName = 'running-process'
      SignatureKind = 'Unknown'
    }
  }

  throw 'The official OpenAI.Codex package is not installed or cannot be resolved after update. Install/open Codex once, then re-run skin launcher.'
}

function Get-DreamSkinCodexStatePathCandidate {
  param([AllowNull()][object]$State)
  if ($null -eq $State -or -not $State.codexExe -or -not $State.codexPackageRoot) { return $null }
  $executable = "$($State.codexExe)"
  $packageRoot = "$($State.codexPackageRoot)"
  # Accept ChatGPT.exe / Codex.exe under app\ or package root (Store layout drift).
  $expected = @(
    (Join-Path $packageRoot 'app\ChatGPT.exe'),
    (Join-Path $packageRoot 'app\Codex.exe'),
    (Join-Path $packageRoot 'ChatGPT.exe'),
    (Join-Path $packageRoot 'Codex.exe')
  )
  $matched = $false
  foreach ($candidate in $expected) {
    if (Test-DreamSkinPathEqual -Left $executable -Right $candidate) { $matched = $true; break }
  }
  if (-not $matched) { return $null }
  return [pscustomobject]@{
    PackageRoot = $packageRoot
    Executable = $executable
    Version = "$($State.codexVersion)"
    FromState = $true
    RegisteredPackageVerified = $false
  }
}

function Resolve-DreamSkinCodexInstallFromState {
  param(
    [AllowNull()][object]$State,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$RegisteredInstalls
  )
  $candidate = Get-DreamSkinCodexStatePathCandidate -State $State
  if ($null -eq $candidate) { return $null }

  $hasFullName = [bool]$State.codexPackageFullName
  $hasFamilyName = [bool]$State.codexPackageFamilyName
  if ($hasFullName -xor $hasFamilyName) { return $null }
  foreach ($install in $RegisteredInstalls) {
    $pathMatches = (Test-DreamSkinPathEqual -Left $candidate.PackageRoot -Right $install.PackageRoot) -and
      (Test-DreamSkinPathEqual -Left $candidate.Executable -Right $install.Executable)
    if (-not $pathMatches) { continue }
    if ($hasFullName -and ("$($State.codexPackageFullName)" -ine $install.PackageFullName -or
      "$($State.codexPackageFamilyName)" -ine $install.PackageFamilyName)) {
      continue
    }
    return [pscustomobject]@{
      PackageRoot = $install.PackageRoot
      Executable = $install.Executable
      Version = $install.Version
      PackageFullName = $install.PackageFullName
      PackageFamilyName = $install.PackageFamilyName
      SignatureKind = $install.SignatureKind
      FromState = $true
      RegisteredPackageVerified = $true
    }
  }
  return $null
}

function Get-DreamSkinCodexInstallFromState {
  param([AllowNull()][object]$State)
  try { $installs = @(Get-DreamSkinRegisteredCodexInstalls) } catch { return $null }
  return Resolve-DreamSkinCodexInstallFromState -State $State -RegisteredInstalls $installs
}

function Test-DreamSkinWebSocketUrl {
  param([string]$Value, [int]$Port)
  try {
    $uri = [Uri]$Value
    $hostName = $uri.Host.ToLowerInvariant()
    return ($uri.IsAbsoluteUri -and $uri.Scheme -eq 'ws' -and $uri.Port -eq $Port -and
      $hostName -in @('127.0.0.1', 'localhost', '::1', '[::1]') -and -not $uri.UserInfo -and
      -not $uri.Query -and -not $uri.Fragment -and
      $uri.AbsolutePath -cmatch '^/devtools/(?:page|browser)/[A-Za-z0-9._-]{1,200}$')
  } catch {
    return $false
  }
}

function Test-DreamSkinCdpPageTarget {
  param([AllowNull()][object]$Target, [int]$Port)
  if ($null -eq $Target -or "$($Target.type)" -cne 'page' -or
    "$($Target.url)" -notlike 'app://*') {
    return $false
  }
  if ($Target.id -isnot [string]) { return $false }
  $targetId = "$($Target.id)"
  $webSocketUrl = "$($Target.webSocketDebuggerUrl)"
  if (-not (Test-DreamSkinBrowserId -Value $targetId) -or
    -not (Test-DreamSkinWebSocketUrl -Value $webSocketUrl -Port $Port)) {
    return $false
  }
  try {
    return ([Uri]$webSocketUrl).AbsolutePath -ceq "/devtools/page/$targetId"
  } catch {
    return $false
  }
}

function Get-DreamSkinCdpTargets {
  param([int]$Port)
  try {
    $targets = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/list" -TimeoutSec 2 `
      -MaximumRedirection 0 -ErrorAction Stop
    return @($targets | Where-Object { Test-DreamSkinCdpPageTarget -Target $_ -Port $Port })
  } catch {
    return @()
  }
}

function Test-DreamSkinBrowserId {
  param([string]$Value)
  return [bool]($Value -and $Value.Length -le 200 -and $Value -cmatch '^[A-Za-z0-9._-]+$')
}

function Get-DreamSkinCdpBrowserIdentity {
  param([int]$Port)
  try {
    $version = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/version" -TimeoutSec 2 `
      -MaximumRedirection 0 -ErrorAction Stop
    $webSocketUrl = "$($version.webSocketDebuggerUrl)"
    if (-not (Test-DreamSkinWebSocketUrl -Value $webSocketUrl -Port $Port)) { return $null }
    $uri = [Uri]$webSocketUrl
    $match = [regex]::Match($uri.AbsolutePath, '^/devtools/browser/(?<id>[A-Za-z0-9._-]{1,200})$')
    if (-not $match.Success -or $uri.Query -or $uri.Fragment) { return $null }
    $browserId = $match.Groups['id'].Value
    if (-not (Test-DreamSkinBrowserId -Value $browserId)) { return $null }
    return [pscustomobject]@{
      BrowserId = $browserId
      WebSocketDebuggerUrl = $webSocketUrl
      Browser = "$($version.Browser)"
    }
  } catch {
    return $null
  }
}

function Get-DreamSkinPortListeners {
  param([int]$Port)
  if (-not (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) {
    throw 'Get-NetTCPConnection is required to verify CDP listener ownership.'
  }
  return @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
}

function Test-DreamSkinPortAvailable {
  param([int]$Port)
  return (Get-DreamSkinPortListeners -Port $Port).Count -eq 0
}

function Test-DreamSkinCodexPortOwner {
  param([int]$Port, [Parameter(Mandatory = $true)][object]$Codex)
  $listeners = Get-DreamSkinPortListeners -Port $Port
  if ($listeners.Count -eq 0) { return $false }
  foreach ($listener in $listeners) {
    if ($listener.LocalAddress -notin @('127.0.0.1', '::1')) { return $false }
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$listener.OwningProcess)" -ErrorAction SilentlyContinue
    $processPath = if ($process) { Get-DreamSkinProcessExecutablePath -ProcessInfo $process } else { $null }
    if (-not $processPath -or -not (Test-DreamSkinPathEqual -Left $processPath -Right $Codex.Executable)) {
      return $false
    }
  }
  return $true
}

function Get-DreamSkinVerifiedCdpIdentity {
  param([int]$Port, [Parameter(Mandatory = $true)][object]$Codex)
  if (-not (Test-DreamSkinCodexPortOwner -Port $Port -Codex $Codex)) { return $null }
  $browser = Get-DreamSkinCdpBrowserIdentity -Port $Port
  if ($null -eq $browser) { return $null }
  $targets = Get-DreamSkinCdpTargets -Port $Port
  if ($targets.Count -eq 0) { return $null }
  if (-not (Test-DreamSkinCodexPortOwner -Port $Port -Codex $Codex)) { return $null }
  return [pscustomobject]@{
    BrowserId = $browser.BrowserId
    BrowserWebSocketDebuggerUrl = $browser.WebSocketDebuggerUrl
    Browser = $browser.Browser
    TargetCount = $targets.Count
  }
}

function Test-DreamSkinCodexCdpEndpoint {
  param([int]$Port, [Parameter(Mandatory = $true)][object]$Codex)
  return $null -ne (Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $Codex)
}

function Select-DreamSkinPort {
  param([int]$PreferredPort)
  for ($candidate = $PreferredPort; $candidate -le [Math]::Min(65535, $PreferredPort + 100); $candidate++) {
    if (Test-DreamSkinPortAvailable -Port $candidate) { return $candidate }
  }
  throw "No free loopback port was found between $PreferredPort and $([Math]::Min(65535, $PreferredPort + 100))."
}

function Wait-DreamSkinPortAvailable {
  param([int]$Port, [int]$TimeoutSeconds = 5)
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  do {
    if (Test-DreamSkinPortAvailable -Port $Port) { return $true }
    Start-Sleep -Milliseconds 200
  } while ((Get-Date) -lt $deadline)
  return $false
}

function Read-DreamSkinState {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  try {
    $state = (Read-DreamSkinUtf8File -Path $Path) | ConvertFrom-Json -ErrorAction Stop
    if ($null -eq $state -or $state -is [string] -or $state -is [array]) { throw 'State root must be an object.' }
    $properties = @($state.PSObject.Properties.Name)
    if ($properties -contains 'platform' -and "$($state.platform)" -ine 'windows') {
      throw 'State platform is not Windows.'
    }
    $schemaVersion = 1
    if ($properties -contains 'schemaVersion') {
      $schemaVersion = 0
      if (-not [int]::TryParse("$($state.schemaVersion)", [ref]$schemaVersion) -or
        $schemaVersion -lt 1 -or $schemaVersion -gt 3) {
        throw 'State schema is not supported.'
      }
    }
    if ($schemaVersion -ge 3) {
      foreach ($required in @(
        'platform', 'port', 'injectorPid', 'injectorStartedAt', 'injectorPath', 'nodePath',
        'codexExe', 'codexPackageRoot', 'codexPackageFullName', 'codexPackageFamilyName', 'browserId'
      )) {
        if ($properties -notcontains $required -or -not $state.$required) {
          throw "State schema 3 is missing required field: $required"
        }
      }
    }
    if ($properties -contains 'port') {
      $statePort = 0
      if (-not [int]::TryParse("$($state.port)", [ref]$statePort)) { throw 'State port is invalid.' }
      Assert-DreamSkinPort -Port $statePort
    }
    if ($properties -contains 'injectorPid' -and $null -ne $state.injectorPid) {
      $statePid = 0
      if (-not [int]::TryParse("$($state.injectorPid)", [ref]$statePid) -or $statePid -le 0) {
        throw 'State injector PID is invalid.'
      }
    }
    if ($properties -contains 'browserId' -and $state.browserId -and
      -not (Test-DreamSkinBrowserId -Value "$($state.browserId)")) {
      throw 'State browser ID is invalid.'
    }
    return $state
  } catch {
    throw "Dream Skin state is unreadable; it was preserved for inspection: $Path"
  }
}

function Write-DreamSkinState {
  param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][object]$State)
  $json = $State | ConvertTo-Json -Depth 6
  Write-DreamSkinUtf8FileAtomically -Path $Path -Content ($json + "`r`n")
}

function Archive-DreamSkinStateFile {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $directory = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($Path))
  $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss-fff')
  $archivePath = Join-Path $directory "state.stale-$stamp-$([guid]::NewGuid().ToString('N')).json"
  Move-Item -LiteralPath $Path -Destination $archivePath -ErrorAction Stop
  return $archivePath
}

function Get-DreamSkinProcessStartedAt {
  param([int]$ProcessId)
  try {
    return (Get-Process -Id $ProcessId -ErrorAction Stop).StartTime.ToUniversalTime().ToString('o')
  } catch {
    return $null
  }
}

function Test-DreamSkinWatchInjectorCommandLine {
  param(
    [string]$CommandLine,
    [string]$InjectorPath = $null,
    [AllowNull()][object]$Port = $null
  )
  if (-not $CommandLine) { return $false }
  if ($CommandLine -notmatch '(?i)injector\.mjs') { return $false }
  if (-not (Test-DreamSkinCommandLineToken -CommandLine $CommandLine -Token '--watch')) { return $false }
  if ($InjectorPath -and -not (Test-DreamSkinCommandLineToken -CommandLine $CommandLine -Token $InjectorPath)) {
    return $false
  }
  if ($null -ne $Port -and "$Port" -ne '') {
    $portPattern = '(?i)(?:^|\s)--port(?:=|\s+)' + [regex]::Escape("$Port") + '(?=$|\s)'
    if (-not [regex]::IsMatch($CommandLine, $portPattern)) { return $false }
  }
  return $true
}

function Stop-DreamSkinWatchInjectors {
  <#
    .SYNOPSIS
      Kill every node --watch injector.mjs (optionally filtered by path/port).
    .NOTES
      Single-instance policy: at most one watch injector may live. Callers that
      are about to Start-Process a new watch MUST call this first and treat a
      non-zero leftover count as hard failure (do not start a second daemon).
  #>
  param(
    [string]$InjectorPath = $null,
    [AllowNull()][object]$Port = $null,
    [int]$ExcludeProcessId = 0
  )
  $stopped = @()
  $left = @()
  $nodes = @(Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue)
  foreach ($proc in $nodes) {
    $procId = [int]$proc.ProcessId
    if ($ExcludeProcessId -gt 0 -and $procId -eq $ExcludeProcessId) { continue }
    $cmd = [string]$proc.CommandLine
    if (-not (Test-DreamSkinWatchInjectorCommandLine -CommandLine $cmd -InjectorPath $InjectorPath -Port $Port)) {
      # Path/port filter missed, but bare injector.mjs --watch still counts as
      # a product-line peer (old runtimeId path, publish drift, etc.).
      if (-not (Test-DreamSkinWatchInjectorCommandLine -CommandLine $cmd)) { continue }
      if ($InjectorPath -or ($null -ne $Port -and "$Port" -ne '')) {
        # Prefer filtered kills first; unrestricted sweep is the fallback below.
        continue
      }
    }
    try { $null = & taskkill.exe /PID $procId /T /F 2>$null } catch {}
    try { Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue } catch {}
    $stopped += $procId
  }
  if ($stopped.Count -gt 0) {
    Start-Sleep -Milliseconds 400
  }
  # Second pass: any remaining watch injector (no path filter) — publish/reattach
  # must not leave orphans on a previous versions/<id>/scripts/injector.mjs.
  $nodes = @(Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue)
  foreach ($proc in $nodes) {
    $procId = [int]$proc.ProcessId
    if ($ExcludeProcessId -gt 0 -and $procId -eq $ExcludeProcessId) { continue }
    $cmd = [string]$proc.CommandLine
    if (-not (Test-DreamSkinWatchInjectorCommandLine -CommandLine $cmd)) { continue }
    try { $null = & taskkill.exe /PID $procId /T /F 2>$null } catch {}
    try { Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue } catch {}
    if ($stopped -notcontains $procId) { $stopped += $procId }
  }
  if ($stopped.Count -gt 0) {
    try { Wait-Process -Id $stopped[0] -Timeout 2 -ErrorAction SilentlyContinue } catch {}
    Start-Sleep -Milliseconds 200
  }
  $nodes = @(Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue)
  foreach ($proc in $nodes) {
    $procId = [int]$proc.ProcessId
    if ($ExcludeProcessId -gt 0 -and $procId -eq $ExcludeProcessId) { continue }
    if (Test-DreamSkinWatchInjectorCommandLine -CommandLine ([string]$proc.CommandLine)) {
      $left += $procId
    }
  }
  return [pscustomobject]@{
    Stopped = $stopped
    Left    = $left
    Ok      = ($left.Count -eq 0)
  }
}

function Stop-DreamSkinRecordedInjector {
  param([AllowNull()][object]$State)
  # Always sweep watch injectors first so identity-mismatch / stale PID cannot
  # leave a second daemon when open/check start a new one.
  $port = $null
  $expectedInjector = $null
  if ($null -ne $State) {
    if ($State.port) { $port = $State.port }
    if ($State.injectorPath) {
      $expectedInjector = "$($State.injectorPath)"
    } elseif ($State.skillRoot) {
      $expectedInjector = Join-Path "$($State.skillRoot)" 'scripts\injector.mjs'
    }
  }

  if ($null -ne $State -and $State.injectorPid) {
    $processId = [int]$State.injectorPid
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $processId" -ErrorAction SilentlyContinue
    if ($process) {
      $processPath = Get-DreamSkinProcessExecutablePath -ProcessInfo $process
      $commandLine = "$($process.CommandLine)"
      $isNodeExecutable = $processPath -and ([System.IO.Path]::GetFileName("$processPath") -ieq 'node.exe')
      $looksLikeInjector = $isNodeExecutable -and (
        (Test-DreamSkinWatchInjectorCommandLine -CommandLine $commandLine -InjectorPath $expectedInjector -Port $port) -or
        (Test-DreamSkinWatchInjectorCommandLine -CommandLine $commandLine)
      )
      if ($looksLikeInjector) {
        try { $null = & taskkill.exe /PID $processId /T /F 2>$null } catch {}
        try { Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue } catch {}
        try { Wait-Process -Id $processId -Timeout 2 -ErrorAction SilentlyContinue } catch {}
      }
      # Identity mismatch: do NOT throw — fall through to global sweep so a new
      # injector can still be started without dual-open. State is rewritten by caller.
    }
  }

  $sweep = Stop-DreamSkinWatchInjectors -InjectorPath $expectedInjector -Port $port
  if (-not $sweep.Ok) {
    # Last unrestricted attempt
    $sweep = Stop-DreamSkinWatchInjectors
  }
  if (-not $sweep.Ok) {
    throw ("Dream Skin watch injector(s) still running after stop: PID " + ($sweep.Left -join ','))
  }
  return $true
}

function Get-DreamSkinCodexProcesses {
  param([Parameter(Mandatory = $true)][object]$Codex)
  return @(Get-CimInstance Win32_Process -Filter "Name = 'ChatGPT.exe'" -ErrorAction SilentlyContinue |
    Where-Object {
      $processPath = Get-DreamSkinProcessExecutablePath -ProcessInfo $_
      Test-DreamSkinPathEqual -Left $processPath -Right $Codex.Executable
    })
}

function Test-DreamSkinInjectorAlive {
  param([Parameter(Mandatory = $true)]$State)
  if ($null -eq $State -or -not $State.injectorPid) { return $false }
  try {
    $proc = Get-Process -Id ([int]$State.injectorPid) -ErrorAction Stop
    return ($proc.ProcessName -ieq 'node')
  } catch {
    return $false
  }
}

function Stop-DreamSkinCodex {
  param([Parameter(Mandatory = $true)][object]$Codex, [switch]$AllowForce)
  $processes = Get-DreamSkinCodexProcesses -Codex $Codex
  if ($processes.Count -eq 0) { return }
  foreach ($item in $processes) {
    try { [void](Get-Process -Id $item.ProcessId -ErrorAction Stop).CloseMainWindow() } catch {}
  }

  $deadline = (Get-Date).AddSeconds(15)
  while ((Get-DreamSkinCodexProcesses -Codex $Codex).Count -gt 0 -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 250
  }
  $remaining = Get-DreamSkinCodexProcesses -Codex $Codex
  if ($remaining.Count -eq 0) { return }
  if (-not $AllowForce) {
    throw 'Codex did not close within 15 seconds. Close it manually or explicitly authorize a forced restart.'
  }
  foreach ($item in $remaining) {
    $current = Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$item.ProcessId)" -ErrorAction SilentlyContinue
    $currentPath = if ($current) { Get-DreamSkinProcessExecutablePath -ProcessInfo $current } else { $null }
    if ($currentPath -and (Test-DreamSkinPathEqual -Left $currentPath -Right $Codex.Executable)) {
      Stop-Process -Id $item.ProcessId -Force -ErrorAction SilentlyContinue
    }
  }
  Start-Sleep -Milliseconds 500
  if ((Get-DreamSkinCodexProcesses -Codex $Codex).Count -gt 0) { throw 'Codex could not be stopped safely.' }
}

function Confirm-DreamSkinRestart {
  param([string]$Message)
  $shell = New-Object -ComObject WScript.Shell
  return $shell.Popup($Message, 0, 'Codex Dream Skin', 52) -eq 6
}
