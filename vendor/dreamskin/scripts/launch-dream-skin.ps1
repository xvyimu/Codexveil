[CmdletBinding()]
param(
  [ValidateRange(0, 65535)][int]$Port = 0,
  [switch]$ShowMenu
)

$ErrorActionPreference = 'Stop'

function Read-LauncherJson {
  param([Parameter(Mandatory = $true)][string]$Path)
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $encoding = [System.Text.UTF8Encoding]::new($false, $true)
  return $encoding.GetString($bytes) | ConvertFrom-Json -ErrorAction Stop
}

function Assert-LauncherPathSafe {
  param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Root)
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
  if (-not $fullPath.StartsWith($fullRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'The selected Dream Skin runtime escapes its managed program root.'
  }
  $current = $fullPath
  while ($current.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    if ([System.IO.File]::Exists($current) -or [System.IO.Directory]::Exists($current)) {
      $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
      if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "The Dream Skin runtime contains a reparse point: $current"
      }
    }
    if ($current -ceq $fullRoot) { break }
    $parent = [System.IO.Path]::GetDirectoryName($current)
    if (-not $parent -or $parent -ceq $current) { break }
    $current = $parent
  }
  return $fullPath
}

$programRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$currentPath = Join-Path $programRoot 'current.json'
$current = Read-LauncherJson -Path $currentPath
if ($current.schemaVersion -ne 1 -or $current.runtimeId -notmatch '^[0-9A-Za-z._-]{1,96}$') {
  throw 'The Dream Skin current runtime pointer is invalid.'
}
$expectedRelative = "versions/$($current.runtimeId)"
if ($current.relativeEnginePath -cne $expectedRelative) {
  throw 'The Dream Skin current runtime path does not match its runtime ID.'
}
$runtimeRoot = Assert-LauncherPathSafe `
  -Path (Join-Path $programRoot ($current.relativeEnginePath -replace '/', '\')) -Root $programRoot
$manifestPath = Assert-LauncherPathSafe -Path (Join-Path $runtimeRoot '.dream-skin-runtime.json') -Root $programRoot
$manifest = Read-LauncherJson -Path $manifestPath
if ($manifest.schemaVersion -ne 1 -or $manifest.runtimeId -cne $current.runtimeId) {
  throw 'The Dream Skin runtime manifest does not match current.json.'
}
$trayScript = Assert-LauncherPathSafe `
  -Path (Join-Path $runtimeRoot 'scripts\tray-dream-skin.ps1') -Root $programRoot
if (-not [System.IO.File]::Exists($trayScript)) { throw 'The installed Dream Skin tray script is missing.' }
if ($Port -ne 0 -and $Port -lt 1024) { throw 'Port must be 0 or between 1024 and 65535.' }

$powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
$quote = [char]34
$arguments = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File ' +
  $quote + $trayScript + $quote
if ($Port -ne 0) { $arguments += " -Port $Port" }
if ($ShowMenu) { $arguments += ' -ShowMenu' }
Start-Process -FilePath $powershell -ArgumentList $arguments -WindowStyle Hidden | Out-Null
