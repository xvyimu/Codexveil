[CmdletBinding()]
param(
  [switch]$SkipTests,
  [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'release')
)

$ErrorActionPreference = 'Stop'
$WindowsRoot = Split-Path -Parent $PSScriptRoot
$VersionPath = Join-Path $WindowsRoot 'VERSION'
$utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)
$Version = $utf8Strict.GetString([System.IO.File]::ReadAllBytes($VersionPath)).Trim()
if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$') {
  throw "Windows release VERSION is invalid: $Version"
}
$RepositoryVersionPath = Join-Path (Split-Path -Parent $WindowsRoot) 'VERSION'
if ([System.IO.File]::Exists($RepositoryVersionPath)) {
  $RepositoryVersion = $utf8Strict.GetString(
    [System.IO.File]::ReadAllBytes($RepositoryVersionPath)
  ).Trim()
  if ($RepositoryVersion -cne $Version) {
    throw "Windows VERSION $Version does not match repository VERSION $RepositoryVersion."
  }
}

if (-not $SkipTests) {
  $powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
  & $powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $WindowsRoot 'tests\run-tests.ps1')
  if ($LASTEXITCODE -ne 0) { throw "Windows regression suite failed with exit code $LASTEXITCODE." }
}

$topLevelFiles = @('VERSION', 'SKILL.md', 'CHANGELOG.md', 'README.md', 'README.en.md')
$directoryAllowlist = [ordered]@{
  scripts = @('.ps1', '.mjs')
  assets = @('.css', '.js', '.json', '.jpg', '.jpeg', '.png', '.webp')
  references = @('.md')
  agents = @('.yaml', '.yml')
}
$sourceFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]
foreach ($relativePath in $topLevelFiles) {
  $path = Join-Path $WindowsRoot $relativePath
  if (-not [System.IO.File]::Exists($path)) { throw "Required Windows release file is missing: $relativePath" }
  $file = Get-Item -LiteralPath $path -Force
  if (($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "Windows release file is a reparse point: $relativePath"
  }
  $sourceFiles.Add($file)
}
foreach ($directoryName in $directoryAllowlist.Keys) {
  $directory = Join-Path $WindowsRoot $directoryName
  if (-not [System.IO.Directory]::Exists($directory)) {
    throw "Required Windows release directory is missing: $directoryName"
  }
  foreach ($item in Get-ChildItem -LiteralPath $directory -Recurse -Force | Sort-Object FullName) {
    $relativePath = $item.FullName.Substring($WindowsRoot.TrimEnd('\').Length + 1)
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "Windows release tree contains a reparse point: $relativePath"
    }
    if ($item.PSIsContainer) { continue }
    if ($directoryAllowlist[$directoryName] -cnotcontains $item.Extension.ToLowerInvariant()) {
      throw "Windows release directory contains a non-allowlisted file: $relativePath"
    }
    $sourceFiles.Add($item)
  }
}

$rootPrefix = $WindowsRoot.TrimEnd('\') + '\'
$records = @($sourceFiles | ForEach-Object {
  [pscustomobject][ordered]@{
    relativePath = $_.FullName.Substring($rootPrefix.Length).Replace('\', '/')
    bytes = [int64]$_.Length
    sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    sourcePath = $_.FullName
  }
} | Sort-Object relativePath)
$coreRoot = @(
  (Join-Path $WindowsRoot 'core'),
  (Join-Path (Split-Path -Parent $WindowsRoot) 'core')
) | Where-Object { [System.IO.Directory]::Exists($_) } | Select-Object -First 1
if (-not $coreRoot) { throw 'Windows release shared core is missing.' }
$coreRootItem = Get-Item -LiteralPath $coreRoot -Force
if (($coreRootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
  throw "Windows release shared core is a reparse point: $coreRoot"
}
$corePrefix = $coreRoot.TrimEnd('\') + '\'
$coreRecords = @(Get-ChildItem -LiteralPath $coreRoot -Recurse -Force | ForEach-Object {
  if (($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "Windows release shared core contains a reparse point: $($_.FullName)"
  }
  if ($_.PSIsContainer) { return }
  if ($_.Extension -cne '.mjs') { throw "Windows release shared core contains a non-allowlisted file: $($_.FullName)" }
  [pscustomobject][ordered]@{
    relativePath = 'core/' + $_.FullName.Substring($corePrefix.Length).Replace('\', '/')
    bytes = [int64]$_.Length
    sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    sourcePath = $_.FullName
  }
})
$records = @($records + $coreRecords | Sort-Object relativePath)
$manifest = [ordered]@{
  schemaVersion = 1
  product = 'CodexDreamSkinWindows'
  version = $Version
  minimumNode = '22'
  minimumPowerShell = '5.1'
  files = @($records | Select-Object relativePath, bytes, sha256)
}
$manifestBytes = $utf8Strict.GetBytes(($manifest | ConvertTo-Json -Depth 6) + "`r`n")

$outputRoot = [System.IO.Path]::GetFullPath($OutputDirectory)
[System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$archiveName = "codex-dream-skin-windows-v$Version.zip"
$archivePath = Join-Path $outputRoot $archiveName
$temporaryArchive = Join-Path $outputRoot (".$archiveName.$([guid]::NewGuid().ToString('N')).tmp")
$packageRoot = 'codex-dream-skin-windows'
$fixedTimestamp = [DateTimeOffset]::Parse('2000-01-01T00:00:00Z')

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
  $archiveStream = [System.IO.File]::Open(
    $temporaryArchive,
    [System.IO.FileMode]::CreateNew,
    [System.IO.FileAccess]::Write,
    [System.IO.FileShare]::None
  )
  try {
    $archive = New-Object System.IO.Compression.ZipArchive(
      $archiveStream,
      [System.IO.Compression.ZipArchiveMode]::Create,
      $false
    )
    try {
      foreach ($record in $records) {
        $entry = $archive.CreateEntry(
          "$packageRoot/$($record.relativePath)",
          [System.IO.Compression.CompressionLevel]::Optimal
        )
        $entry.LastWriteTime = $fixedTimestamp
        $entryStream = $entry.Open()
        $sourceStream = [System.IO.File]::OpenRead($record.sourcePath)
        try { $sourceStream.CopyTo($entryStream) }
        finally { $sourceStream.Dispose(); $entryStream.Dispose() }
      }
      $manifestEntry = $archive.CreateEntry(
        "$packageRoot/release-manifest.json",
        [System.IO.Compression.CompressionLevel]::Optimal
      )
      $manifestEntry.LastWriteTime = $fixedTimestamp
      $manifestStream = $manifestEntry.Open()
      try { $manifestStream.Write($manifestBytes, 0, $manifestBytes.Length) }
      finally { $manifestStream.Dispose() }
    } finally {
      $archive.Dispose()
    }
  } finally {
    $archiveStream.Dispose()
  }
  Move-Item -LiteralPath $temporaryArchive -Destination $archivePath -Force
} finally {
  if ([System.IO.File]::Exists($temporaryArchive)) {
    [System.IO.File]::Delete($temporaryArchive)
  }
}

$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
$checksumPath = Join-Path $outputRoot 'SHA256SUMS.txt'
[System.IO.File]::WriteAllText($checksumPath, "$archiveHash  $archiveName`r`n", $utf8Strict)
Write-Host "Created $archivePath"
Write-Host "SHA-256 $archiveHash"
