#Requires -Version 5.1
<#
.SYNOPSIS
  把所有可写的 Codex/ChatGPT 快捷方式改成带皮肤启动
#>
$ErrorActionPreference = "Stop"
$prog = Join-Path $env:LOCALAPPDATA "Programs\CodexDreamSkin"
$openPs1 = Join-Path $prog "open-codex-dream-skin.ps1"
$vbs = Join-Path $prog "launch-codex-skin.vbs"
if (-not (Test-Path -LiteralPath $openPs1)) { throw "missing $openPs1" }
if (-not (Test-Path -LiteralPath $vbs)) { throw "missing $vbs" }

$wscript = Join-Path $env:SystemRoot "System32\wscript.exe"
$psExe = (Get-Command powershell.exe).Source
$shell = New-Object -ComObject WScript.Shell
$ico = Join-Path $prog "codex-icon.ico"

function Set-SkinShortcut {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$Description = "Open Codex with skin",
    [switch]$UsePowerShell
  )
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $sc = $shell.CreateShortcut($Path)
  if ($UsePowerShell) {
    $sc.TargetPath = $psExe
    $sc.Arguments = "-NoLogo -NoProfile -STA -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$openPs1`" -Port 9335 -NoPrompt"
  } else {
    $sc.TargetPath = $wscript
    $sc.Arguments = "//B //Nologo `"$vbs`""
  }
  $sc.WorkingDirectory = $prog
  $sc.WindowStyle = 7
  $sc.Description = $Description
  if (Test-Path -LiteralPath $ico) { $sc.IconLocation = "$ico,0" }
  $sc.Save()
  Write-Host "SKIN  $Path"
}

function Test-BareCodexTarget([string]$Target, [string]$Args) {
  if (-not $Target) { return $false }
  $t = $Target.ToLowerInvariant()
  $a = if ($Args) { $Args.ToLowerInvariant() } else { "" }
  if ($a -match "open-codex-dream-skin|launch-codex-skin|codexdreamskin") { return $false }
  if ($t -match "chatgpt\.exe$") { return $true }
  if ($t -match "openai\.codex_.*\\app\\(chatgpt|codex)\.exe$") { return $true }
  if ($t -match "\\programs\\codex\\codex\.exe$" -and $t -notmatch "resources") { return $true }
  if ($t -match "windowsapps" -and $t -match "openai\.codex" -and $t -match "\.exe$") { return $true }
  return $false
}

$roots = @(
  (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"),
  (Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"),
  (Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch"),
  ([Environment]::GetFolderPath("Desktop")),
  (Join-Path $env:PUBLIC "Desktop")
)

$changed = 0
foreach ($root in $roots) {
  if (-not (Test-Path -LiteralPath $root)) { continue }
  Get-ChildItem -LiteralPath $root -Recurse -Filter "*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
      $sc = $shell.CreateShortcut($_.FullName)
      $name = $_.BaseName
      $isNameHit = $name -match "^(ChatGPT|Codex)$" -or $name -match "ChatGPT|OpenAI Codex|Codex Desktop"
      $isBare = Test-BareCodexTarget -Target $sc.TargetPath -Args $sc.Arguments
      if ($isBare -or ($isNameHit -and $sc.TargetPath -match "ChatGPT\.exe|Codex\.exe")) {
        # Keep skin-related utility shortcuts alone
        if ($name -match "换肤|修复|回归|管理|说明|Skin|Dream Skin") { return }
        Set-SkinShortcut -Path $_.FullName -Description "Open Codex with skin"
        $script:changed++
      }
    } catch {
      Write-Host ("SKIP  " + $_.FullName + " :: " + $_.Exception.Message)
    }
  }
}

# Ensure canonical skin entries exist
Set-SkinShortcut -Path (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Codex.lnk")
Set-SkinShortcut -Path (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\ChatGPT.lnk")
Set-SkinShortcut -Path (Join-Path ([Environment]::GetFolderPath("Desktop")) "Codex.lnk")
Set-SkinShortcut -Path (Join-Path ([Environment]::GetFolderPath("Desktop")) "ChatGPT.lnk")
# Taskbar pins if present
$taskbar = Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
if (Test-Path -LiteralPath $taskbar) {
  Set-SkinShortcut -Path (Join-Path $taskbar "Codex.lnk")
  Set-SkinShortcut -Path (Join-Path $taskbar "ChatGPT.lnk")
}
# Startup
$startup = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
Set-SkinShortcut -Path (Join-Path $startup "Codex Dream Skin - Auto Launch.lnk") -Description "Auto launch Codex with skin"

Write-Host ("DONE changed_or_ensured entries. re-pin Start/taskbar if an old store tile still opens bare Codex.")
