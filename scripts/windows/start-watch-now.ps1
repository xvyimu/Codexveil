$ErrorActionPreference = 'Stop'
$stateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
$programRoot = Join-Path $env:LOCALAPPDATA 'Programs\CodexDreamSkin'
$current = Get-Content -LiteralPath (Join-Path $programRoot 'current.json') -Raw -Encoding utf8 | ConvertFrom-Json
$rel = ([string]$current.relativeEnginePath).Replace([char]47, [char]92)
$runtime = Join-Path $programRoot $rel
$injector = Join-Path $runtime 'scripts\injector.mjs'
Write-Host "runtime=$runtime"
Write-Host "injector=$(Test-Path -LiteralPath $injector) path=$injector"
$node = (Get-Command node).Source
$version = Invoke-RestMethod -Uri 'http://127.0.0.1:9335/json/version' -TimeoutSec 2
$ws = [string]$version.webSocketDebuggerUrl
if ($ws -notmatch '/devtools/browser/([A-Za-z0-9._-]+)$') { throw "bad browser ws: $ws" }
$browserId = $Matches[1]
Write-Host "browserId=$browserId"
$port = 9335
$themeDir = Join-Path $stateRoot 'active-theme'
$pauseFile = Join-Path $stateRoot 'paused'
$stdout = Join-Path $stateRoot 'injector.log'
$stderr = Join-Path $stateRoot 'injector-error.log'
if (Test-Path -LiteralPath $pauseFile) { Remove-Item -LiteralPath $pauseFile -Force }
Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object {
  $_.CommandLine -and $_.CommandLine.Contains('injector.mjs')
} | ForEach-Object {
  Write-Host "Stopping injector $($_.ProcessId)"
  Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}
$argLine = @(
  $injector
  '--watch'
  '--port'
  "$port"
  '--browser-id'
  $browserId
  '--theme-dir'
  $themeDir
  '--pause-file'
  $pauseFile
)
Write-Host "Starting: $node $($argLine -join ' ')"
$proc = Start-Process -FilePath $node -ArgumentList $argLine -WindowStyle Hidden -PassThru `
  -RedirectStandardOutput $stdout -RedirectStandardError $stderr
Start-Sleep -Seconds 4
Write-Host "pid=$($proc.Id) exited=$($proc.HasExited)"
if ($proc.HasExited) {
  Write-Host 'STDERR:'
  if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr -Raw }
  Write-Host 'STDOUT:'
  if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout -Raw }
  exit 1
}
$state = @{
  schemaVersion = 3
  platform = 'windows'
  port = $port
  injectorPid = $proc.Id
  injectorStartedAt = (Get-Date).ToUniversalTime().ToString('o')
  injectorPath = $injector
  nodePath = $node
  browserId = $browserId
  themeDir = $themeDir
  pauseFile = $pauseFile
  createdAt = (Get-Date).ToUniversalTime().ToString('o')
  product = 'codex-skin'
  runtimeId = [string]$current.runtimeId
} | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText((Join-Path $stateRoot 'state.json'), $state + "`n", [Text.UTF8Encoding]::new($false))
Write-Host 'state written'
& $node $injector --verify --port $port --browser-id $browserId --timeout-ms 25000
Write-Host "verify exit=$LASTEXITCODE"
if (Test-Path -LiteralPath $stderr) {
  Write-Host 'stderr tail:'
  Get-Content -LiteralPath $stderr -Tail 40
}
if (Test-Path -LiteralPath $stdout) {
  Write-Host 'stdout tail:'
  Get-Content -LiteralPath $stdout -Tail 40
}
