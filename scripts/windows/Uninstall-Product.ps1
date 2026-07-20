#Requires -Version 5.1
<#
.SYNOPSIS
  Uninstall Codex Dream Skin (program root + optional state).

.DESCRIPTION
  Removes %LOCALAPPDATA%\Programs\CodexDreamSkin by default.
  With -RemoveState also removes themes/active-theme/state under
  %LOCALAPPDATA%\CodexDreamSkin (user catalog is wiped).
  Does not uninstall OpenAI Codex.
#>
[CmdletBinding()]
param(
  [switch]$RemoveState,
  [switch]$KeepShortcuts
)

$ErrorActionPreference = "Stop"
try {
  & chcp.com 65001 | Out-Null
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  try { [Console]::OutputEncoding = $utf8 } catch {}
  $OutputEncoding = $utf8
} catch {}

$programRoot = Join-Path $env:LOCALAPPDATA "Programs\CodexDreamSkin"
$stateRoot = Join-Path $env:LOCALAPPDATA "CodexDreamSkin"

Write-Host "Uninstall Codex Dream Skin"
Write-Host "  program: $programRoot"
Write-Host "  state  : $stateRoot (remove=$RemoveState)"

# Stop watch injectors best-effort
try {
  Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'CodexDreamSkin\\versions\\.*injector\.mjs' } |
    ForEach-Object {
      Write-Host "Stopping injector PID $($_.ProcessId)"
      Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
} catch {}

# Stop tray scripts that live under program root
try {
  Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'CodexDreamSkin\\.*(tray-dream-skin|open-codex-dream-skin|launcher-ui)' } |
    ForEach-Object {
      # Do not kill the current uninstall shell
      if ($_.ProcessId -ne $PID) {
        Write-Host "Stopping PS PID $($_.ProcessId)"
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
      }
    }
} catch {}

if (-not $KeepShortcuts) {
  $targets = @(
    (Join-Path ([Environment]::GetFolderPath("Desktop")) "Codex.lnk"),
    (Join-Path ([Environment]::GetFolderPath("Desktop")) "Codex 换肤.lnk"),
    (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Codex.lnk"),
    (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Codex 换肤.lnk")
  )
  foreach ($t in $targets) {
    if (Test-Path -LiteralPath $t) {
      Remove-Item -LiteralPath $t -Force -ErrorAction SilentlyContinue
      Write-Host "Removed shortcut $t"
    }
  }
  $adv = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Codex Skin 高级"
  if (Test-Path -LiteralPath $adv) {
    Remove-Item -LiteralPath $adv -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Removed $adv"
  }
}

if (Test-Path -LiteralPath $programRoot) {
  Remove-Item -LiteralPath $programRoot -Recurse -Force
  Write-Host "Removed program root"
} else {
  Write-Host "Program root already absent"
}

if ($RemoveState -and (Test-Path -LiteralPath $stateRoot)) {
  Remove-Item -LiteralPath $stateRoot -Recurse -Force
  Write-Host "Removed state root (themes + active-theme + logs)"
} elseif (-not $RemoveState) {
  Write-Host "State root kept (themes/active-theme). Use -RemoveState to wipe."
}

Write-Host "Uninstall done. OpenAI Codex itself was not removed."
