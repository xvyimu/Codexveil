Option Explicit
Dim sh, ps1, cmd
Set sh = CreateObject("WScript.Shell")
ps1 = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\Programs\CodexDreamSkin\switch-theme-ui.ps1")
' -WindowStyle Hidden + wscript window style 0 = no console
cmd = "powershell.exe -NoLogo -NoProfile -STA -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """"
' 0 = hide window, False = do not wait
sh.Run cmd, 0, False
