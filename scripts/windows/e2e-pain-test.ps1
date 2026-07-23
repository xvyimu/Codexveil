# Timed modular E2E + pain capture. ASCII only for PS 5.1 parser safety.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$programRoot = Join-Path $env:LOCALAPPDATA 'Programs\CodexDreamSkin'
$stateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
$repo = if (Test-Path -LiteralPath 'D:\orca\Codexveil') { 'D:\orca\Codexveil' } else { [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')) }
$report = [ordered]@{ startedAt = (Get-Date).ToUniversalTime().ToString('o'); cases = @() }

function Add-Case($name, $pass, $ms, $detail, $notes = @(), $severity = 'info') {
  $script:report.cases += [ordered]@{
    name = $name; pass = [bool]$pass; ms = [int]$ms; detail = [string]$detail
    notes = @($notes); severity = $severity
  }
  $tag = if ($pass) { 'PASS' } else { 'FAIL' }
  Write-Host ("[{0}] {1} ({2}ms) {3}" -f $tag, $name, $ms, $detail)
}

function Invoke-Timed {
  param([string]$FilePath, [string[]]$ArgumentList, [int]$TimeoutSec = 45)
  
$ErrorActionPreference = 'Stop'
# UTF-8 console bootstrap (PAIN-POINTS #22)
try {
  & chcp.com 65001 | Out-Null
  $utf8 = [System.Text.UTF8Encoding]::new($false)
  try { [Console]::OutputEncoding = $utf8 } catch {}
  try { [Console]::InputEncoding = $utf8 } catch {}
  $OutputEncoding = $utf8
} catch {}
$out = Join-Path $env:TEMP ("e2e-out-" + [guid]::NewGuid().ToString('n') + '.txt')
  $err = Join-Path $env:TEMP ("e2e-err-" + [guid]::NewGuid().ToString('n') + '.txt')
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $p = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -PassThru -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err
  $ok = $p.WaitForExit($TimeoutSec * 1000)
  if (-not $ok) {
    try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch {}
    Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $p.Id } | ForEach-Object {
      try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
    }
    $sw.Stop()
    return [pscustomobject]@{ ExitCode = -999; TimedOut = $true; Ms = $sw.ElapsedMilliseconds; Out = ''; Err = 'timeout' }
  }
  $sw.Stop()
  try { $p.Refresh() } catch {}
  # Start-Process ExitCode can be $null until HasExited is observed; coerce safely.
  $code = 0
  try {
    if ($null -ne $p.ExitCode) { $code = [int]$p.ExitCode }
    elseif ($p.HasExited) { $code = 0 }
  } catch { $code = 0 }
  $o = if (Test-Path $out) { Get-Content $out -Raw -ErrorAction SilentlyContinue } else { '' }
  $e = if (Test-Path $err) { Get-Content $err -Raw -ErrorAction SilentlyContinue } else { '' }
  # Semantic success for tools that print pass markers even when native exit is quirky.
  return [pscustomobject]@{ ExitCode = $code; TimedOut = $false; Ms = $sw.ElapsedMilliseconds; Out = $o; Err = $e }
}

# ---------- 1 runtime files ----------
$sw = [Diagnostics.Stopwatch]::StartNew()
try {
  $cur = Get-Content (Join-Path $programRoot 'current.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $rr = Join-Path $programRoot ($cur.relativeEnginePath -replace '/', '\')
  $need = @(
    (Join-Path $rr 'scripts\injector.mjs'),
    (Join-Path $rr 'scripts\common-windows.ps1'),
    (Join-Path $rr 'scripts\wait-shell.mjs'),
    (Join-Path $programRoot 'open-codex-dream-skin.ps1'),
    (Join-Path $programRoot 'switch-theme-ui.ps1'),
    (Join-Path $programRoot 'kick-theme-now.ps1'),
    (Join-Path $programRoot 'check-and-fix.ps1'),
    (Join-Path $programRoot 'launch-codex-skin.vbs'),
    (Join-Path $programRoot 'launch-switch-theme.vbs'),
    (Join-Path $stateRoot 'wait-shell.mjs'),
    (Join-Path $stateRoot 'active-theme\theme.json')
  )
  $missing = @($need | Where-Object { -not (Test-Path -LiteralPath $_) })
  Add-Case 'runtime-files' ($missing.Count -eq 0) $sw.ElapsedMilliseconds ("runtime=$($cur.runtimeId) missing=$($missing.Count)") $missing $(if ($missing.Count){'high'}else{'info'})
} catch { Add-Case 'runtime-files' $false $sw.ElapsedMilliseconds $_.Exception.Message @() 'high' }

# ---------- 2 package + cdp ----------
$sw = [Diagnostics.Stopwatch]::StartNew()
try {
  $cur = Get-Content (Join-Path $programRoot 'current.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $rr = Join-Path $programRoot ($cur.relativeEnginePath -replace '/', '\')
  . (Join-Path $rr 'scripts\common-windows.ps1')
  $codex = Get-DreamSkinCodexInstall
  $cdp = Get-DreamSkinVerifiedCdpIdentity -Port 9335 -Codex $codex
  $targets = Get-DreamSkinCdpTargets -Port 9335
  Add-Case 'package-cdp' (($null -ne $cdp) -and (Test-Path $codex.Executable)) $sw.ElapsedMilliseconds ("ver=$($codex.Version) browser=$($cdp.BrowserId) targets=$($targets.Count)") @() $(if ($null -eq $cdp){'high'}else{'info'})
} catch { Add-Case 'package-cdp' $false $sw.ElapsedMilliseconds $_.Exception.Message @() 'high' }

# ---------- 3 live skin markers ----------
$sw = [Diagnostics.Stopwatch]::StartNew()
$probe = @'
const port=9335;
const list=await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
const pages=(list||[]).filter(t=>t.type==="page"&&String(t.url||"").startsWith("app://")&&t.webSocketDebuggerUrl);
if(!pages.length){console.log(JSON.stringify({pass:false,reason:"no-page"}));process.exit(2)}
async function evalPage(page){
  const ws=new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((res,rej)=>{const t=setTimeout(()=>rej(new Error("ws")),4000);ws.addEventListener("open",()=>{clearTimeout(t);res()},{once:true});ws.addEventListener("error",()=>{clearTimeout(t);rej(new Error("wserr"))},{once:true});});
  let id=1;const send=(m,p={})=>new Promise((resolve,reject)=>{const mid=id++;const timer=setTimeout(()=>reject(new Error("to "+m)),5000);const on=ev=>{const msg=JSON.parse(String(ev.data));if(msg.id!==mid)return;clearTimeout(timer);ws.removeEventListener("message",on);if(msg.error)reject(new Error(msg.error.message));else resolve(msg.result);};ws.addEventListener("message",on);ws.send(JSON.stringify({id:mid,method:m,params:p}));});
  await send("Runtime.enable");
  const r=await send("Runtime.evaluate",{expression:`(()=>{
    const allStyles=[...document.querySelectorAll("style")].map(s=>({id:s.id,len:(s.textContent||"").length,data:Object.keys(s.dataset||{})}));
    const style=document.getElementById("codex-dream-skin-style")
      || document.getElementById("dream-skin-style")
      || document.querySelector("style[data-codex-dream-skin],style[data-dream-skin],style[data-codex-skin]");
    const big = allStyles.filter(s=>s.len>500).slice(0,8);
    const bodyClass=[...document.documentElement.classList,...document.body.classList].join(" ");
    const markers={
      shell:!!document.querySelector('main.main-surface, main[class*="main-surface"], main'),
      sidebar:!!document.querySelector('aside.app-shell-left-panel, aside[class*="left-panel"], aside[class*="sidebar"]'),
      composer:!!document.querySelector('.composer-surface-chrome, [class*="composer-surface"]'),
      skinStyle:!!style,
      styleId: style?style.id:"",
      styleLen: style?(style.textContent||"").length:0,
      bigStyles: big,
      bodyClass: bodyClass.slice(0,160),
      hasDreamText: !!document.body && /dream|codex-skin|skin-hero/i.test(document.documentElement.outerHTML.slice(0,200000)),
    };
    const pass = markers.shell && (markers.skinStyle || markers.styleLen>100 || markers.hasDreamText || big.some(s=>s.id.includes("dream")||s.id.includes("skin")));
    return {pass, markers, url:location.href, title:document.title};
  })()`,returnByValue:true,awaitPromise:true});
  try{ws.close()}catch{}
  return r.result.value;
}
let best=null;
for (const page of pages){
  try { const v=await evalPage(page); if(!best || (v.pass && !best.pass)) best=v; if(v.pass) break; } catch(e){ best=best||{pass:false,error:String(e)} }
}
console.log(JSON.stringify(best));
process.exit(best?.pass?0:3);
'@
$probePath = Join-Path $env:TEMP 'codex-skin-probe.mjs'
[System.IO.File]::WriteAllText($probePath, $probe, [Text.UTF8Encoding]::new($false))
$pr = Invoke-Timed -FilePath 'node' -ArgumentList @($probePath) -TimeoutSec 20
Add-Case 'live-skin-markers' ((-not $pr.TimedOut) -and $pr.ExitCode -eq 0) $pr.Ms ($pr.Out.Trim()) @($pr.Err) $(if ($pr.ExitCode -ne 0){'high'}else{'info'})

# ---------- 4 kick latency ----------
$kr = Invoke-Timed -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $programRoot 'kick-theme-now.ps1')) -TimeoutSec 40
Add-Case 'kick-latency' ((-not $kr.TimedOut) -and ($kr.ExitCode -in 0,2)) $kr.Ms ("exit=$($kr.ExitCode) out=$($kr.Out.Trim())") @($kr.Err) $(if ($kr.Ms -gt 8000 -or $kr.ExitCode -notin 0,2){'medium'}else{'info'})

# ---------- 5 apply A->B ----------
$sw = [Diagnostics.Stopwatch]::StartNew()
try {
  $cli = Join-Path $repo 'packages\core\cli.mjs'
  $ids = @(Get-ChildItem (Join-Path $stateRoot 'themes') -Directory | Select-Object -ExpandProperty Name)
  $a = if ($ids -contains 'preset-arina-hashimoto') { 'preset-arina-hashimoto' } elseif ($ids.Count -ge 1) { $ids[0] } else { throw 'no themes in catalog' }
  $b = if ($ids.Count -ge 2) { $ids[1] } else { $a }
  $r1 = Invoke-Timed -FilePath 'node' -ArgumentList @($cli,'apply','--theme',$a) -TimeoutSec 30
  Start-Sleep -Milliseconds 500
  $r2 = Invoke-Timed -FilePath 'node' -ArgumentList @($cli,'apply','--theme',$b) -TimeoutSec 30
  $active = Get-Content (Join-Path $stateRoot 'active-theme\theme.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $activeId = if ($active.id){$active.id} elseif ($active.slug){$active.slug} elseif ($active.name){$active.name} else {'?'}
  $pass = (-not $r1.TimedOut -and -not $r2.TimedOut -and $r1.ExitCode -eq 0 -and $r2.ExitCode -eq 0)
  Add-Case 'cli-apply-A-B' $pass $sw.ElapsedMilliseconds ("A=$a/$($r1.Ms)ms B=$b/$($r2.Ms)ms active=$activeId") @($r1.Out.Trim(), $r2.Out.Trim()) $(if(-not $pass){'high'}else{'info'})
} catch { Add-Case 'cli-apply-A-B' $false $sw.ElapsedMilliseconds $_.Exception.Message @() 'high' }

# ---------- 6 injector verify only (smoke hang suspect) ----------
$sw = [Diagnostics.Stopwatch]::StartNew()
try {
  $cur = Get-Content (Join-Path $programRoot 'current.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $rr = Join-Path $programRoot ($cur.relativeEnginePath -replace '/', '\')
  $inj = Join-Path $rr 'scripts\injector.mjs'
  $state = Get-Content (Join-Path $stateRoot 'state.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $vr = Invoke-Timed -FilePath 'node' -ArgumentList @($inj,'--verify','--port','9335','--browser-id',"$($state.browserId)",'--timeout-ms','12000') -TimeoutSec 25
  Add-Case 'injector-verify' ((-not $vr.TimedOut) -and $vr.ExitCode -eq 0) $vr.Ms ("exit=$($vr.ExitCode) $($vr.Out.Trim())") @($vr.Err) $(if ($vr.TimedOut){'high'}elseif($vr.ExitCode -ne 0){'medium'}else{'info'})
} catch { Add-Case 'injector-verify' $false $sw.ElapsedMilliseconds $_.Exception.Message @() 'high' }

# ---------- 7 smoke with hard timeout ----------
$sm = Invoke-Timed -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $programRoot 'smoke-dream-skin.ps1')) -TimeoutSec 50
$smokePass = (-not $sm.TimedOut) -and ($sm.ExitCode -eq 0) -and ($sm.Out -match 'SMOKE_PASS')
Add-Case 'smoke' $smokePass $sm.Ms ("exit=$($sm.ExitCode) timeout=$($sm.TimedOut)") @(($sm.Out.Trim() -split "`n" | Select-Object -Last 8) -join ' | ') $(if(-not $smokePass){'high'}else{'info'})

# ---------- 8 post-update quiet ----------
$pu = Invoke-Timed -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $programRoot 'post-update-regression.ps1'),'-Quiet') -TimeoutSec 90
$repOk = $false
try {
  $rep = Get-Content (Join-Path $stateRoot 'post-update-report.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $repOk = [bool]$rep.pass
} catch {}
Add-Case 'post-update' ((-not $pu.TimedOut) -and $pu.ExitCode -eq 0 -and $repOk) $pu.Ms ("exit=$($pu.ExitCode) reportPass=$repOk") @() $(if ($pu.TimedOut){'high'}else{'info'})

# ---------- 9 shortcuts ----------
$sw = [Diagnostics.Stopwatch]::StartNew()
$paths = @(
  "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Codex.lnk",
  "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\ChatGPT.lnk",
  "$env:USERPROFILE\Desktop\Codex.lnk",
  "$env:USERPROFILE\Desktop\ChatGPT.lnk",
  "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Codex.lnk",
  "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\ChatGPT.lnk",
  "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Codex Dream Skin - Auto Launch.lnk"
)
$wsh = New-Object -ComObject WScript.Shell
$bad=@(); $ok=@()
foreach ($p in $paths) {
  if (-not (Test-Path -LiteralPath $p)) { $bad += "missing:$p"; continue }
  $sc = $wsh.CreateShortcut($p)
  $target = "$($sc.TargetPath) $($sc.Arguments)"
  if ($target -match 'launch-codex-skin\.vbs|open-codex-dream-skin|wscript') { $ok += (Split-Path $p -Leaf) }
  else { $bad += ("bare:" + (Split-Path $p -Leaf) + " => " + $target) }
}
Add-Case 'shortcuts-skinned' ($bad.Count -eq 0) $sw.ElapsedMilliseconds ("ok=$($ok.Count) bad=$($bad.Count)") $bad $(if($bad.Count){'high'}else{'info'})

# ---------- 10 theme switcher discoverability ----------
$sw = [Diagnostics.Stopwatch]::StartNew()
$found=@()
foreach ($dir in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs", "$env:USERPROFILE\Desktop")) {
  if (-not (Test-Path $dir)) { continue }
  Get-ChildItem $dir -Filter '*.lnk' -ErrorAction SilentlyContinue | ForEach-Object {
    try {
      $s = $wsh.CreateShortcut($_.FullName)
      $t = "$($s.TargetPath) $($s.Arguments)"
      if ($t -match 'switch-theme|launch-switch-theme') { $found += $_.FullName }
    } catch {}
  }
}
Add-Case 'theme-switcher-entry' ($found.Count -gt 0) $sw.ElapsedMilliseconds ("entries=$($found.Count)") $found $(if($found.Count -eq 0){'high'}else{'medium'})

# ---------- 11 single injector ----------
$sw = [Diagnostics.Stopwatch]::StartNew()
$nodes = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'node' -and $_.CommandLine -and $_.CommandLine -match 'injector\.mjs' })
$detail = ($nodes | ForEach-Object { "pid=$($_.ProcessId)" }) -join ','
Add-Case 'single-injector' ($nodes.Count -eq 1) $sw.ElapsedMilliseconds ("count=$($nodes.Count) $detail") @() $(if($nodes.Count -ne 1){'high'}else{'info'})

# ---------- 12 picker single instance ----------
$sw = [Diagnostics.Stopwatch]::StartNew()
$vbs = Join-Path $programRoot 'launch-switch-theme.vbs'
Start-Process -FilePath 'wscript.exe' -ArgumentList @('//B', $vbs) | Out-Null
Start-Sleep -Milliseconds 1500
Start-Process -FilePath 'wscript.exe' -ArgumentList @('//B', $vbs) | Out-Null
Start-Sleep -Milliseconds 1800
$uis = @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -match 'switch-theme-ui\.ps1' })
Add-Case 'picker-single-instance' ($uis.Count -le 1) $sw.ElapsedMilliseconds ("uiProcs=$($uis.Count)") @() $(if($uis.Count -gt 1){'medium'}else{'info'})

# ---------- 13 check-and-fix healthy timing ----------
$fx = Invoke-Timed -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-STA','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',(Join-Path $programRoot 'check-and-fix.ps1'),'-Quiet') -TimeoutSec 60
Add-Case 'check-and-fix-healthy' ((-not $fx.TimedOut) -and $fx.ExitCode -eq 0) $fx.Ms ("exit=$($fx.ExitCode)") @() $(if ($fx.Ms -gt 15000){'medium'}elseif($fx.TimedOut){'high'}else{'info'})

# ---------- 14 open already running ----------
$op = Invoke-Timed -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-STA','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',(Join-Path $programRoot 'open-codex-dream-skin.ps1'),'-NoPrompt','-Port','9335') -TimeoutSec 60
Add-Case 'open-already-running' ((-not $op.TimedOut) -and $op.ExitCode -eq 0) $op.Ms ("exit=$($op.ExitCode)") @(($op.Out.Trim() -split "`n" | Select-Object -Last 5) -join ' | ') $(if ($op.Ms -gt 20000 -or $op.TimedOut){'high'}else{'info'})

# ---------- 15 doctor ----------
$dr = Invoke-Timed -FilePath 'node' -ArgumentList @((Join-Path $repo 'packages\core\cli.mjs'),'doctor') -TimeoutSec 25
$dok = (-not $dr.TimedOut) -and ($dr.Out -match '"appFound":\s*true') -and ($dr.Out -match '"portOpen":\s*true') -and ($dr.Out -match '"fresh":\s*true')
Add-Case 'doctor' $dok $dr.Ms ("matched=$dok") @() $(if(-not $dok){'high'}else{'info'})

# ---------- 16 versions clutter ----------
$sw = [Diagnostics.Stopwatch]::StartNew()
$vers = @(Get-ChildItem (Join-Path $programRoot 'versions') -Directory)
$curId = (Get-Content (Join-Path $programRoot 'current.json') -Raw | ConvertFrom-Json).runtimeId
$stale = @($vers | Where-Object { $_.Name -ne $curId } | Select-Object -ExpandProperty Name)
Add-Case 'versions-clutter' $true $sw.ElapsedMilliseconds ("total=$($vers.Count) stale=$($stale.Count)") $stale $(if($stale.Count -gt 3){'medium'}else{'low'})

# ---------- 17 list CLI ----------
$lr = Invoke-Timed -FilePath 'node' -ArgumentList @((Join-Path $repo 'packages\core\cli.mjs'),'list') -TimeoutSec 20
Add-Case 'cli-list' ((-not $lr.TimedOut) -and $lr.ExitCode -eq 0 -and $lr.Out.Length -gt 20) $lr.Ms ("len=$($lr.Out.Length)") @($lr.Out.Substring(0, [Math]::Min(300, $lr.Out.Length))) 'info'

# ---------- 18 active theme schema ----------
$sw = [Diagnostics.Stopwatch]::StartNew()
$t = Get-Content (Join-Path $stateRoot 'active-theme\theme.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$keys = @($t.PSObject.Properties.Name)
$files = @(Get-ChildItem (Join-Path $stateRoot 'active-theme') -File | Select-Object -ExpandProperty Name)
Add-Case 'active-theme-schema' ($keys.Count -gt 0) $sw.ElapsedMilliseconds ("keys=$($keys -join ',') files=$($files -join ',')") $files 'info'

# ---------- 19 dual product leftovers (heige) ----------
$sw = [Diagnostics.Stopwatch]::StartNew()
$heige = Join-Path $env:USERPROFILE '.codex\heige-codex-skin-studio'
$heigeExists = Test-Path $heige
$heigeProcs = @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -match 'heige-codex-skin' })
Add-Case 'heige-residue' ($heigeProcs.Count -eq 0) $sw.ElapsedMilliseconds ("dirExists=$heigeExists procs=$($heigeProcs.Count)") @($heige) $(if($heigeExists){'low'}else{'info'})

# ---------- 20 black console risk: launchers should use wscript ----------
$sw = [Diagnostics.Stopwatch]::StartNew()
$codexLnk = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Codex.lnk"
$sc = $wsh.CreateShortcut($codexLnk)
$tgt = "$($sc.TargetPath)".ToLowerInvariant()
$args = "$($sc.Arguments)"
$silent = ($tgt -match 'wscript') -or ($args -match 'wscript|//b') -or ($tgt -match 'launch-codex-skin\.vbs')
Add-Case 'silent-launch' $silent $sw.ElapsedMilliseconds ("target=$($sc.TargetPath) args=$args") @() $(if(-not $silent){'high'}else{'info'})

# summarize
$report.finishedAt = (Get-Date).ToUniversalTime().ToString('o')
$failed = @($report.cases | Where-Object { -not $_.pass })
$report.passCount = @($report.cases | Where-Object { $_.pass }).Count
$report.failCount = $failed.Count
$report.pass = ($failed.Count -eq 0)

# derive pain points from timings/failures
$pains = @()
foreach ($c in $report.cases) {
  if (-not $c.pass) {
    $pains += [ordered]@{ id=$c.name; severity=$(if($c.severity){$c.severity}else{'high'}); title="FAIL: $($c.name)"; detail=$c.detail; ms=$c.ms }
  } elseif ($c.name -eq 'kick-latency' -and $c.ms -gt 5000) {
    $pains += [ordered]@{ id='kick-slow'; severity='medium'; title='Kick theme slow'; detail=$c.detail; ms=$c.ms }
  } elseif ($c.name -eq 'check-and-fix-healthy' -and $c.ms -gt 12000) {
    $pains += [ordered]@{ id='fix-slow'; severity='medium'; title='check-and-fix slow on healthy path'; detail=$c.detail; ms=$c.ms }
  } elseif ($c.name -eq 'open-already-running' -and $c.ms -gt 15000) {
    $pains += [ordered]@{ id='open-slow'; severity='high'; title='open slow when Codex already running'; detail=$c.detail; ms=$c.ms }
  } elseif ($c.name -eq 'theme-switcher-entry' -and -not $c.pass) {
    $pains += [ordered]@{ id='picker-hard-to-find'; severity='high'; title='No desktop/start-menu theme picker entry'; detail=$c.detail; ms=$c.ms }
  } elseif ($c.name -eq 'versions-clutter' -and $c.notes.Count -gt 3) {
    $pains += [ordered]@{ id='version-clutter'; severity='medium'; title='Old runtime versions accumulate'; detail=$c.detail; ms=$c.ms }
  } elseif ($c.name -eq 'smoke' -and -not $c.pass) {
    $pains += [ordered]@{ id='smoke-hang'; severity='high'; title='smoke can hang/fail'; detail=$c.detail; ms=$c.ms }
  }
}
if (-not (@($pains | Where-Object { $_.id -eq 'theme-switcher-entry' -or $_.id -eq 'picker-hard-to-find' })) -and -not (@($report.cases | Where-Object { $_.name -eq 'theme-switcher-entry' -and $_.pass }))) {
  $pains += [ordered]@{ id='picker-hard-to-find'; severity='high'; title='Theme picker not discoverable'; detail='no start/desktop shortcut'; ms=0 }
}
$report.painPoints = $pains

$path = Join-Path $stateRoot 'e2e-pain-report.json'
[System.IO.File]::WriteAllText($path, ($report | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
Write-Host ("REPORT -> " + $path)
Write-Host ("SUMMARY pass=$($report.passCount) fail=$($report.failCount) pains=$($pains.Count)")
foreach ($p in $pains) { Write-Host ("PAIN [$($p.severity)] $($p.title) :: $($p.detail)") }
foreach ($f in $failed) { Write-Host ("FAIL $($f.name) :: $($f.detail)") }
