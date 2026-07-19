if (-not (Get-Command Write-DreamSkinUtf8FileAtomically -CommandType Function -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'config-utf8.ps1')
}

function Assert-DreamSkinRuntimePathSafe {
  param([Parameter(Mandatory = $true)][string]$Path)
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $current = $fullPath
  while ($current) {
    if ([System.IO.File]::Exists($current) -or [System.IO.Directory]::Exists($current)) {
      $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
      if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Dream Skin runtime path contains a junction or symbolic link: $current"
      }
    }
    $parent = [System.IO.Path]::GetDirectoryName($current)
    if (-not $parent -or $parent -ceq $current) { break }
    $current = $parent
  }
  return $fullPath
}

function Assert-DreamSkinRuntimeTreeSafe {
  param([Parameter(Mandatory = $true)][string]$Root)
  $fullRoot = Assert-DreamSkinRuntimePathSafe -Path $Root
  if (-not [System.IO.Directory]::Exists($fullRoot)) { return $fullRoot }
  $pending = [System.Collections.Generic.Stack[string]]::new()
  $pending.Push($fullRoot)
  while ($pending.Count -gt 0) {
    $directory = $pending.Pop()
    foreach ($item in Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop) {
      if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Dream Skin runtime tree contains a junction or symbolic link: $($item.FullName)"
      }
      if ($item.PSIsContainer) { $pending.Push($item.FullName) }
    }
  }
  return $fullRoot
}

function Get-DreamSkinRuntimeFileRecords {
  param([Parameter(Mandatory = $true)][string]$SkillRoot)
  $fullRoot = Assert-DreamSkinRuntimeTreeSafe -Root $SkillRoot
  $entries = @()
  foreach ($relativeRoot in @('scripts', 'assets')) {
    $sourceRoot = Join-Path $fullRoot $relativeRoot
    if (-not [System.IO.Directory]::Exists($sourceRoot)) {
      throw "Dream Skin runtime source is missing: $sourceRoot"
    }
    $prefix = $fullRoot.TrimEnd('\') + '\'
    $entries += Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Force -ErrorAction Stop |
      ForEach-Object {
        [pscustomobject]@{
          relativePath = $_.FullName.Substring($prefix.Length).Replace('\', '/')
          source = $_
        }
      }
  }
  $coreRoot = @(
    (Join-Path $fullRoot 'core'),
    (Join-Path (Split-Path -Parent $fullRoot) 'core')
  ) | Where-Object { [System.IO.Directory]::Exists($_) } | Select-Object -First 1
  if (-not $coreRoot) { throw 'Dream Skin shared core source is missing.' }
  $coreRoot = Assert-DreamSkinRuntimeTreeSafe -Root $coreRoot
  $corePrefix = $coreRoot.TrimEnd('\') + '\'
  $entries += Get-ChildItem -LiteralPath $coreRoot -Recurse -File -Force -ErrorAction Stop |
    ForEach-Object {
      if ($_.Extension -cne '.mjs') { throw "Dream Skin shared core contains an unsupported file: $($_.FullName)" }
      [pscustomobject]@{
        relativePath = 'core/' + $_.FullName.Substring($corePrefix.Length).Replace('\', '/')
        source = $_
      }
    }
  $versionPath = Join-Path $fullRoot 'VERSION'
  if (-not [System.IO.File]::Exists($versionPath)) { throw "Dream Skin VERSION is missing: $versionPath" }
  $entries += [pscustomobject]@{ relativePath = 'VERSION'; source = Get-Item -LiteralPath $versionPath -Force }
  return @($entries | ForEach-Object {
    [pscustomobject]@{
      relativePath = $_.relativePath
      bytes = [int64]$_.source.Length
      sha256 = (Get-FileHash -LiteralPath $_.source.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
      sourcePath = $_.source.FullName
    }
  } | Sort-Object relativePath)
}

function Get-DreamSkinRuntimeLayout {
  param([Parameter(Mandatory = $true)][string]$ProgramRoot)
  $root = [System.IO.Path]::GetFullPath($ProgramRoot)
  return [pscustomobject]@{
    Root = $root
    Marker = Join-Path $root '.dream-skin-program-root.json'
    Current = Join-Path $root 'current.json'
    Launcher = Join-Path $root 'launch-dream-skin.ps1'
    Versions = Join-Path $root 'versions'
  }
}

function Read-DreamSkinRuntimeJson {
  param([Parameter(Mandatory = $true)][string]$Path)
  return (Read-DreamSkinUtf8File -Path $Path) | ConvertFrom-Json -ErrorAction Stop
}

function Assert-DreamSkinProgramRootManaged {
  param([Parameter(Mandatory = $true)]$Layout, [switch]$AllowEmpty)
  $null = Assert-DreamSkinRuntimePathSafe -Path $Layout.Root
  if (-not [System.IO.Directory]::Exists($Layout.Root)) { return }
  $items = @(Get-ChildItem -LiteralPath $Layout.Root -Force -ErrorAction Stop)
  if ($items.Count -eq 0 -and $AllowEmpty) { return }
  if (-not [System.IO.File]::Exists($Layout.Marker)) {
    throw "Refusing to manage a non-empty unmarked program root: $($Layout.Root)"
  }
  $marker = Read-DreamSkinRuntimeJson -Path $Layout.Marker
  if ($marker.schemaVersion -ne 1 -or $marker.product -cne 'CodexDreamSkin') {
    throw 'The Dream Skin program-root marker is invalid.'
  }
}

function Resolve-DreamSkinCurrentRuntime {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$ProgramRoot)
  $layout = Get-DreamSkinRuntimeLayout -ProgramRoot $ProgramRoot
  Assert-DreamSkinProgramRootManaged -Layout $layout
  $current = Read-DreamSkinRuntimeJson -Path $layout.Current
  if ($current.schemaVersion -ne 1 -or $current.runtimeId -notmatch '^[0-9A-Za-z._-]{1,96}$') {
    throw 'The Dream Skin current runtime pointer is invalid.'
  }
  $expectedRelative = "versions/$($current.runtimeId)"
  if ($current.relativeEnginePath -cne $expectedRelative) {
    throw 'The Dream Skin current runtime path does not match its runtime ID.'
  }
  $runtimeRoot = [System.IO.Path]::GetFullPath((Join-Path $layout.Root `
    ($current.relativeEnginePath -replace '/', '\')))
  if (-not (Test-DreamSkinPathWithin -Path $runtimeRoot -Root $layout.Root)) {
    throw 'The Dream Skin runtime pointer escapes its managed program root.'
  }
  $null = Assert-DreamSkinRuntimeTreeSafe -Root $runtimeRoot
  $manifestPath = Join-Path $runtimeRoot '.dream-skin-runtime.json'
  $manifest = Read-DreamSkinRuntimeJson -Path $manifestPath
  if ($manifest.schemaVersion -ne 1 -or $manifest.runtimeId -cne $current.runtimeId -or
    $manifest.version -cne $current.version -or -not $manifest.files) {
    throw 'The Dream Skin runtime manifest does not match current.json.'
  }
  foreach ($record in $manifest.files) {
    if ($record.relativePath -notmatch '^(?:scripts|assets|core)/|^VERSION$') {
      throw "Runtime manifest contains an invalid path: $($record.relativePath)"
    }
    $filePath = [System.IO.Path]::GetFullPath((Join-Path $runtimeRoot `
      ([string]$record.relativePath -replace '/', '\')))
    if (-not (Test-DreamSkinPathWithin -Path $filePath -Root $runtimeRoot) -or
      -not [System.IO.File]::Exists($filePath)) {
      throw "Runtime manifest file is missing or outside the runtime: $($record.relativePath)"
    }
    $file = Get-Item -LiteralPath $filePath -Force
    $hash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ([int64]$record.bytes -ne [int64]$file.Length -or $record.sha256 -cne $hash) {
      throw "Runtime manifest verification failed: $($record.relativePath)"
    }
  }
  $trayScript = Join-Path $runtimeRoot 'scripts\tray-dream-skin.ps1'
  if (-not [System.IO.File]::Exists($trayScript)) { throw 'The installed tray script is missing.' }
  return [pscustomobject]@{
    ProgramRoot = $layout.Root
    RuntimeId = [string]$current.runtimeId
    Version = [string]$current.version
    RuntimeRoot = $runtimeRoot
    ManifestPath = $manifestPath
    TrayScript = $trayScript
    LauncherScript = $layout.Launcher
  }
}

function Install-DreamSkinRuntime {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$SkillRoot,
    [string]$ProgramRoot = (Join-Path $env:LOCALAPPDATA 'Programs\CodexDreamSkin')
  )
  $fullSkillRoot = [System.IO.Path]::GetFullPath($SkillRoot)
  $layout = Get-DreamSkinRuntimeLayout -ProgramRoot $ProgramRoot
  if (-not [System.IO.Directory]::Exists($layout.Root)) {
    [System.IO.Directory]::CreateDirectory($layout.Root) | Out-Null
  }
  Assert-DreamSkinProgramRootManaged -Layout $layout -AllowEmpty
  if (-not [System.IO.File]::Exists($layout.Marker)) {
    Write-DreamSkinUtf8FileAtomically -Path $layout.Marker -Content `
      (([ordered]@{ schemaVersion = 1; product = 'CodexDreamSkin' } | ConvertTo-Json -Compress) + "`r`n")
  }
  [System.IO.Directory]::CreateDirectory($layout.Versions) | Out-Null

  $version = (Read-DreamSkinUtf8File -Path (Join-Path $fullSkillRoot 'VERSION')).Trim()
  if ($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$') {
    throw "Dream Skin VERSION is invalid: $version"
  }
  $records = @(Get-DreamSkinRuntimeFileRecords -SkillRoot $fullSkillRoot)
  $hashBasis = ($records | Select-Object relativePath, bytes, sha256 | ConvertTo-Json -Depth 4 -Compress)
  $runtimeHash = [System.Security.Cryptography.SHA256]::Create()
  try {
    $hashBytes = [System.Text.UTF8Encoding]::new($false).GetBytes($hashBasis)
    $contentHash = ([BitConverter]::ToString($runtimeHash.ComputeHash($hashBytes))).Replace('-', '').ToLowerInvariant()
  } finally {
    $runtimeHash.Dispose()
  }
  $runtimeId = "$version-$($contentHash.Substring(0, 12))"
  $runtimeRoot = Join-Path $layout.Versions $runtimeId
  $staging = Join-Path $layout.Root ('.staging-' + [guid]::NewGuid().ToString('N'))
  [System.IO.Directory]::CreateDirectory($staging) | Out-Null
  try {
    foreach ($record in $records) {
      $destination = Join-Path $staging ($record.relativePath -replace '/', '\')
      $destinationDirectory = [System.IO.Path]::GetDirectoryName($destination)
      [System.IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null
      Copy-Item -LiteralPath $record.sourcePath -Destination $destination
    }
    $manifest = [ordered]@{
      schemaVersion = 1
      product = 'CodexDreamSkin'
      version = $version
      runtimeId = $runtimeId
      createdAt = (Get-Date).ToUniversalTime().ToString('o')
      files = @($records | Select-Object relativePath, bytes, sha256)
    }
    Write-DreamSkinUtf8FileAtomically -Path (Join-Path $staging '.dream-skin-runtime.json') `
      -Content (($manifest | ConvertTo-Json -Depth 6) + "`r`n")
    if ([System.IO.Directory]::Exists($runtimeRoot)) {
      $existingManifest = Read-DreamSkinRuntimeJson -Path (Join-Path $runtimeRoot '.dream-skin-runtime.json')
      if ($existingManifest.runtimeId -cne $runtimeId) {
        throw "Existing immutable runtime has an unexpected manifest: $runtimeRoot"
      }
      Remove-Item -LiteralPath $staging -Recurse -Force
    } else {
      Move-Item -LiteralPath $staging -Destination $runtimeRoot
    }

    $launcherSource = Join-Path $fullSkillRoot 'scripts\launch-dream-skin.ps1'
    Write-DreamSkinBytesAtomically -Path $layout.Launcher `
      -Bytes ([System.IO.File]::ReadAllBytes($launcherSource))
    $current = [ordered]@{
      schemaVersion = 1
      product = 'CodexDreamSkin'
      version = $version
      runtimeId = $runtimeId
      relativeEnginePath = "versions/$runtimeId"
      updatedAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    Write-DreamSkinUtf8FileAtomically -Path $layout.Current `
      -Content (($current | ConvertTo-Json -Depth 4) + "`r`n")
  } finally {
    if ([System.IO.Directory]::Exists($staging)) {
      $null = Assert-DreamSkinRuntimeTreeSafe -Root $staging
      Remove-Item -LiteralPath $staging -Recurse -Force
    }
  }
  $resolved = Resolve-DreamSkinCurrentRuntime -ProgramRoot $layout.Root
  $verifiedLauncherSource = Join-Path $resolved.RuntimeRoot 'scripts\launch-dream-skin.ps1'
  $launcherSourceHash = (Get-FileHash -LiteralPath $verifiedLauncherSource -Algorithm SHA256).Hash
  $stableLauncherHash = (Get-FileHash -LiteralPath $resolved.LauncherScript -Algorithm SHA256).Hash
  if ($launcherSourceHash -cne $stableLauncherHash) {
    throw 'Stable launcher does not match the verified runtime launcher.'
  }
  $managedScripts = @(Get-ChildItem -LiteralPath $resolved.RuntimeRoot `
    -Filter '*.ps1' -Recurse -File -Force -ErrorAction Stop)
  $managedScripts += Get-Item -LiteralPath $resolved.LauncherScript -Force -ErrorAction Stop
  foreach ($managedScript in $managedScripts) {
    Unblock-File -LiteralPath $managedScript.FullName -ErrorAction Stop
  }
  return $resolved
}

function Remove-DreamSkinRuntimeInstallation {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$ProgramRoot)
  $layout = Get-DreamSkinRuntimeLayout -ProgramRoot $ProgramRoot
  if (-not [System.IO.Directory]::Exists($layout.Root)) { return }
  $null = Resolve-DreamSkinCurrentRuntime -ProgramRoot $layout.Root
  $null = Assert-DreamSkinRuntimeTreeSafe -Root $layout.Root
  Remove-Item -LiteralPath $layout.Root -Recurse -Force
}
