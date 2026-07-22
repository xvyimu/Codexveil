#Requires -Version 5.1
<#
.SYNOPSIS
  把所有可写的 Codex/ChatGPT 快捷方式改成带皮肤启动

  优先入口：CodexFastLaunch.exe（原生冷启 ~100ms）。
  回退：powershell.exe -File open-codex-dream-skin.ps1。
  彻底去掉 VBS 层（旧版 WaitOnReturn 会卡死任务栏）。
#>
$ErrorActionPreference = "Stop"
# UTF-8 console bootstrap (PAIN-POINTS #22). Full helper also runs when launcher-ui is dotted.
try {
  & chcp.com 65001 | Out-Null
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  try { [Console]::OutputEncoding = $utf8 } catch {}
  try { [Console]::InputEncoding = $utf8 } catch {}
  $OutputEncoding = $utf8
} catch {}
$prog = Join-Path $env:LOCALAPPDATA "Programs\CodexDreamSkin"
$openPs1 = Join-Path $prog "open-codex-dream-skin.ps1"
$fastExe = Join-Path $prog "CodexFastLaunch.exe"
if (-not (Test-Path -LiteralPath $openPs1) -and -not (Test-Path -LiteralPath $fastExe)) {
  throw "missing open-codex-dream-skin.ps1 and CodexFastLaunch.exe under $prog"
}

$psExe = (Get-Command powershell.exe).Source
$shell = New-Object -ComObject WScript.Shell
$ico = Join-Path $prog "codex-icon.ico"
$useNative = Test-Path -LiteralPath $fastExe

function Set-SkinShortcut {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$Description = "Open Codex with skin"
  )
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $sc = $shell.CreateShortcut($Path)
  if ($useNative) {
    $sc.TargetPath = $fastExe
    $sc.Arguments = ""
    $sc.Description = "$Description (native)"
  } else {
    $sc.TargetPath = $psExe
    $sc.Arguments = "-NoLogo -NoProfile -STA -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$openPs1`" -Port 9335 -NoPrompt"
    $sc.Description = $Description
  }
  $sc.WorkingDirectory = $prog
  $sc.WindowStyle = 7
  if (Test-Path -LiteralPath $ico) { $sc.IconLocation = "$ico,0" }
  $sc.Save()
  Write-Host "SKIN  $Path"
}

function Test-BareCodexTarget([string]$Target, [string]$Args) {
  if (-not $Target) { return $false }
  $t = $Target.ToLowerInvariant()
  $a = if ($Args) { $Args.ToLowerInvariant() } else { "" }
  # 旧版 VBS 皮肤入口：本次改造视为需要重写（去 VBS 层）
  if ($t -match "wscript\.exe$" -and $a -match "launch-codex-skin\.vbs") { return $true }
  # 旧版 PS 直连皮肤入口：若已有 native exe，也要重写为 exe
  if ($useNative -and $a -match "open-codex-dream-skin") { return $true }
  # 已经是 native 入口就放过
  if ($t -match "codexfastlaunch\.exe$") { return $false }
  # 已经是 PS 直连且没有 native，放过
  if (-not $useNative -and $a -match "open-codex-dream-skin|codexdreamskin") { return $false }
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
# Startup: do NOT auto-create. User may opt in manually; publish must not re-add.
$startup = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
$startupLnk = Join-Path $startup "Codex Dream Skin - Auto Launch.lnk"
if (Test-Path -LiteralPath $startupLnk) {
  Remove-Item -LiteralPath $startupLnk -Force -ErrorAction SilentlyContinue
  Write-Host ("RM   Startup auto-launch (disabled by policy 2026-07-23): " + $startupLnk)
}

Write-Host ("DONE changed_or_ensured entries. re-pin Start/taskbar if an old store tile still opens bare Codex.")
