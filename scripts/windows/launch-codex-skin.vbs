Option Explicit
' Fast path: control plane open-healthy (user-gesture focus chain).
' Miss path: Chinese feedback via show-feedback.ps1, then full open PS1.
' ASCII-only VBScript. Chinese UI goes through PowerShell helpers.
Dim sh, fso, ps1, fbPs1, focusPs1, cmd, http, controlPort, url, status, ok, body
Dim stateRoot, statusFile, ts, line, portFile, psExe, focusedOk
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
ps1 = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\Programs\CodexDreamSkin\open-codex-dream-skin.ps1")
fbPs1 = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\Programs\CodexDreamSkin\show-feedback.ps1")
focusPs1 = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\Programs\CodexDreamSkin\focus-codex.ps1")
stateRoot = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\CodexDreamSkin")
psExe = "powershell.exe"
If Not fso.FolderExists(stateRoot) Then fso.CreateFolder stateRoot
statusFile = stateRoot & "\open-status.json"

Sub WriteStatus(phase, detail, code, okFlag)
  On Error Resume Next
  Dim t, txt
  Set t = fso.CreateTextFile(statusFile, True, False)
  txt = "{""phase"":""" & phase & """,""detail"":""" & detail & """,""code"":""" & code & """,""ok"":" & okFlag & "}"
  t.WriteLine txt
  t.Close
  Err.Clear
  On Error GoTo 0
End Sub

Sub ShowFeedback(code)
  On Error Resume Next
  If fso.FileExists(fbPs1) Then
    cmd = psExe & " -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & fbPs1 & """ -Code " & code
    sh.Run cmd, 0, False
  End If
  Err.Clear
  On Error GoTo 0
End Sub

Function TryAppActivate()
  On Error Resume Next
  Dim titles, i, hit
  hit = False
  titles = Array("Codex", "ChatGPT", "OpenAI", "OpenAI Codex", "Codex Desktop")
  For i = 0 To UBound(titles)
    If sh.AppActivate(titles(i)) Then hit = True
  Next
  TryAppActivate = hit
  Err.Clear
  On Error GoTo 0
End Function

Function TryFocusScript()
  On Error Resume Next
  Dim rc
  rc = 2
  If fso.FileExists(focusPs1) Then
    rc = sh.Run(psExe & " -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & focusPs1 & """ -TimeoutMs 700", 0, True)
  End If
  TryFocusScript = (rc = 0)
  Err.Clear
  On Error GoTo 0
End Function

controlPort = 9336
On Error Resume Next
portFile = stateRoot & "\control.port"
If fso.FileExists(portFile) Then
  Set ts = fso.OpenTextFile(portFile, 1)
  line = Trim(ts.ReadLine)
  ts.Close
  If IsNumeric(line) Then controlPort = CInt(line)
End If
Err.Clear

ok = False
body = ""
Set http = CreateObject("WinHttp.WinHttpRequest.5.1")
If Err.Number = 0 Then
  url = "http://127.0.0.1:" & controlPort & "/open-healthy"
  http.SetTimeouts 80, 80, 250, 500
  http.Open "POST", url, False
  http.SetRequestHeader "Content-Type", "application/json"
  http.Send "{}"
  If Err.Number = 0 Then
    status = http.Status
    body = http.ResponseText
    If status = 200 Then
      If InStr(1, body, """ok"":true", 1) > 0 Or InStr(1, body, """ok"": true", 1) > 0 Then
        ok = True
      End If
    End If
  End If
End If
Err.Clear
On Error GoTo 0

If ok Then
  WriteStatus "control-hit", "open-healthy", "ok", "true"
  ' User-gesture focus chain: control-plane may already have focused; reinforce here.
  focusedOk = False
  If InStr(1, body, """focused"":true", 1) > 0 Or InStr(1, body, """focused"": true", 1) > 0 Then focusedOk = True
  If TryAppActivate() Then focusedOk = True
  If TryFocusScript() Then focusedOk = True
  If TryAppActivate() Then focusedOk = True
  ShowFeedback "first-run"
  If Not focusedOk Then
    WriteStatus "focus-miss", "control-hit but window not foreground", "focus-miss", "false"
    ShowFeedback "focus-miss"
  End If
  WScript.Quit 0
End If

WriteStatus "slow-path", "control miss; full launcher", "slow-path", "false"
ShowFeedback "slow-path"

cmd = psExe & " -NoLogo -NoProfile -STA -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """ -Port 9335 -NoPrompt"
sh.Run cmd, 0, False
