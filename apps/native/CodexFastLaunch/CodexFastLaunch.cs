// CodexFastLaunch.exe — Codex Dream Skin 的原生任务栏快启入口
//
// 目标：从任务栏点 Codex 到窗口置前，冷启 < 60ms 命中控制面时。
// 原方案痛点（见 docs/PAIN-POINTS.md #9 / #16 / #17）：
//   任务栏 lnk → powershell.exe 冷启 ~800ms + launcher-ui.ps1 加载 ~400ms +
//   Add-Type C# 焦点类 ~500ms + Get-DreamSkinVerifiedCdpIdentity ~600ms
//   合计 2-3s，用户体感"点了没反应"。
//
// 本 exe 只做三件事：
//   1) POST http://127.0.0.1:<controlPort>/open-healthy （50ms 超时）
//      controlPort 从 %LOCALAPPDATA%\CodexDreamSkin\control.port 读；缺省 9336
//   2) 若命中：本进程内 P/Invoke SetForegroundWindow 置前 Codex 窗口，exit 0
//   3) 若未命中：Start-Process powershell -File open-codex-dream-skin.ps1（异步），exit 0
//
// 依赖：仅 .NET Framework 4.5（Windows 10+ 内置）。用 csc.exe /target:winexe 编译，单文件 ~20KB。
// 不用 HttpClient 是为了避免 System.Net.Http.dll 的加载开销；HttpWebRequest 走 System.dll 就够。

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace CodexSkin.FastLaunch {
  internal static class Program {
    private const int DEFAULT_CONTROL_PORT = 9336;
    // /health 是本地 loopback，正常 <50ms；给它 400ms 已经绰绰有余，
    // 而且不像 /open-healthy 会在服务端阻塞 1.2s 做 focus。
    private const int HEALTH_TIMEOUT_MS = 400;
    private const int FOCUS_BUDGET_MS = 900;

    // 与 Store 包 OpenAI.Codex_...!App 刻意不同。任务栏若仍按 Store AUMID 分组/启动，
    // 会绕过本 exe 直接 package activation，表现为"点任务栏还是卡死"。
    private const string APP_USER_MODEL_ID = "CodexDreamSkin.FastLaunch";

    [STAThread]
    private static int Main(string[] args) {
      // 必须在任何窗口/壳交互前设置，否则任务栏仍可能按 Store AUMID 归组。
      try { SetCurrentProcessExplicitAppUserModelID(APP_USER_MODEL_ID); } catch {}

      // Diagnostic log lives next to state.json so post-mortem is easy without a console.
      string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
      string stateRoot = Path.Combine(localAppData, "CodexDreamSkin");
      string programRoot = Path.Combine(localAppData, "Programs", "CodexDreamSkin");
      string logPath = Path.Combine(stateRoot, "fast-launch.log");
      Log(logPath, "start argv=" + string.Join(" ", args));

      var sw = Stopwatch.StartNew();
      try {
        int controlPort = ReadControlPort(stateRoot);
        Log(logPath, "controlPort=" + controlPort);

        // Step 1: fast path — control plane /health (cheap) then focus in-process.
        // 故意不走 /open-healthy：那边内部会 spawn PS 做 Focus-CodexSkinWindow，
        // 会阻塞 ~1.2s，把整个"native 快启"的收益吃掉。
        // 这里只确认 control-plane 活着（= injector 在线），焦点由本进程做。
        bool ok, focused;
        TryControlPlane(controlPort, out ok, out focused);
        Log(logPath, string.Format("control-plane ok={0} ms={1}", ok, sw.ElapsedMilliseconds));

        if (ok) {
          // 任务栏点击带来了 SetForegroundWindow 需要的用户手势（AllowSetForegroundWindow）。
          // 本进程直接 P/Invoke，比 spawn PS 再做 focus 快一个数量级。
          bool inProcFocused = TryFocusCodex(FOCUS_BUDGET_MS);
          Log(logPath, "in-proc focus=" + inProcFocused + " ms=" + sw.ElapsedMilliseconds);
          Log(logPath, "exit 0 (fast) total=" + sw.ElapsedMilliseconds + "ms");
          return 0;
        }

        // Step 2: slow path — fork PowerShell open script, don't wait
        SpawnOpenLauncher(programRoot);
        Log(logPath, "exit 0 (slow-spawn) total=" + sw.ElapsedMilliseconds + "ms");
        return 0;
      } catch (Exception ex) {
        Log(logPath, "ERROR: " + ex);
        // Last-resort: still try PowerShell so the user isn't stranded.
        try { SpawnOpenLauncher(programRoot); } catch {}
        return 0;
      }
    }

    // ---- Control plane -------------------------------------------------------

    private static int ReadControlPort(string stateRoot) {
      try {
        string portFile = Path.Combine(stateRoot, "control.port");
        if (File.Exists(portFile)) {
          string txt = File.ReadAllText(portFile).Trim();
          int p;
          if (int.TryParse(txt, out p) && p >= 1024 && p <= 65535) return p;
        }
      } catch {}
      return DEFAULT_CONTROL_PORT;
    }

    /// <summary>GET /health；确认 injector 在线且皮肤已注入 (healthy=true)。</summary>
    // 用 out 而非 ValueTuple —— .NET Framework 4.5 base install 没有 System.ValueTuple.dll，
    // 单文件发布要保持零 nuget 依赖。
    private static void TryControlPlane(int port, out bool ok, out bool focused) {
      ok = false;
      focused = false;
      string url = "http://127.0.0.1:" + port + "/health";
      try {
        var req = (HttpWebRequest)WebRequest.Create(url);
        req.Method = "GET";
        req.Timeout = HEALTH_TIMEOUT_MS;
        req.ReadWriteTimeout = HEALTH_TIMEOUT_MS;
        req.KeepAlive = false;
        req.Proxy = null;                    // 别走系统 proxy，1s 都嫌多
        using (var resp = (HttpWebResponse)req.GetResponse()) {
          if ((int)resp.StatusCode != 200) return;
          using (var rs = resp.GetResponseStream())
          using (var sr = new StreamReader(rs, Encoding.UTF8)) {
            string text = sr.ReadToEnd();
            // 别为一个 bool 就引 System.Web.Extensions —— 手搓 substring 更快
            bool okFlag = text.IndexOf("\"ok\":true", StringComparison.OrdinalIgnoreCase) >= 0;
            bool healthyFlag = text.IndexOf("\"healthy\":true", StringComparison.OrdinalIgnoreCase) >= 0;
            ok = okFlag && healthyFlag;
            focused = false;
          }
        }
      } catch {
        ok = false;
        focused = false;
      }
    }

    // ---- Slow path -----------------------------------------------------------

    private static void SpawnOpenLauncher(string programRoot) {
      string ps1 = Path.Combine(programRoot, "open-codex-dream-skin.ps1");
      if (!File.Exists(ps1)) throw new FileNotFoundException("open-codex-dream-skin.ps1 missing", ps1);
      // 用 Windows PowerShell 5.1（Desktop edition），保持与 dot-source 的 PS 库一致（PS 7 会加载 net5 版模块，见 PROJECT.md）。
      string psExe = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "powershell.exe");
      if (!File.Exists(psExe)) psExe = "powershell.exe";
      var psi = new ProcessStartInfo {
        FileName = psExe,
        Arguments = "-NoLogo -NoProfile -STA -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + ps1 + "\" -Port 9335 -NoPrompt",
        UseShellExecute = false,
        CreateNoWindow = true,
        WorkingDirectory = programRoot,
      };
      // 清 PS 7 污染，防止 Get-AuthenticodeSignature 挂
      psi.EnvironmentVariables["PSModulePath"] = string.Join(";", new[] {
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "WindowsPowerShell", "Modules"),
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "WindowsPowerShell", "Modules"),
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "Modules"),
      });
      Process.Start(psi);
    }

    // ---- In-process focus ----------------------------------------------------

    private static bool TryFocusCodex(int budgetMs) {
      var sw = Stopwatch.StartNew();
      // Codex Store 拆成 8 个 Electron 进程；ChatGPT.exe / Codex.exe 都是候选。
      var pids = new HashSet<uint>();
      foreach (string name in new[] { "ChatGPT", "Codex" }) {
        foreach (var p in Process.GetProcessesByName(name)) {
          try { pids.Add((uint)p.Id); } catch {}
          finally { try { p.Dispose(); } catch {} }
        }
      }
      if (pids.Count == 0) return false;

      // Round 1: 快路径 MainWindowHandle（大多数已经运行的 Codex 走这条）
      foreach (uint pid in pids) {
        if (sw.ElapsedMilliseconds > budgetMs) return false;
        try {
          var p = Process.GetProcessById((int)pid);
          try { p.Refresh(); } catch {}
          IntPtr h = p.MainWindowHandle;
          if (h != IntPtr.Zero && FocusHwnd(h)) return true;
        } catch {}
      }

      // Round 2: EnumWindows 打分挑最像的 Codex 顶层窗口
      while (sw.ElapsedMilliseconds < budgetMs) {
        var hits = EnumScoredWindows(pids);
        foreach (var hit in hits) {
          if (sw.ElapsedMilliseconds > budgetMs) return false;
          if (FocusHwnd(hit.Hwnd)) return true;
        }
        if (sw.ElapsedMilliseconds > budgetMs - 120) break;
        Thread.Sleep(100);
        // Re-collect pids: Electron may spawn workers late.
        foreach (string name in new[] { "ChatGPT", "Codex" }) {
          foreach (var p in Process.GetProcessesByName(name)) {
            try { pids.Add((uint)p.Id); } catch {}
            finally { try { p.Dispose(); } catch {} }
          }
        }
      }
      return false;
    }

    private struct WindowHit {
      public IntPtr Hwnd;
      public uint Pid;
      public string ClassName;
      public string Title;
      public int Score;
    }

    private static List<WindowHit> EnumScoredWindows(HashSet<uint> pids) {
      var hits = new List<WindowHit>();
      EnumWindows((hWnd, l) => {
        uint pid;
        GetWindowThreadProcessId(hWnd, out pid);
        if (!pids.Contains(pid)) return true;
        var cls = new StringBuilder(256);
        GetClassName(hWnd, cls, cls.Capacity);
        string clsStr = cls.ToString() ?? "";
        int titleLen = GetWindowTextLength(hWnd);
        var titleBuf = new StringBuilder(Math.Max(1, titleLen + 1));
        if (titleLen > 0) GetWindowText(hWnd, titleBuf, titleBuf.Capacity);
        string titleStr = titleBuf.ToString() ?? "";
        // 剔除 Electron 常见噪音窗口
        if (clsStr.IndexOf("IME", StringComparison.OrdinalIgnoreCase) >= 0) return true;
        if (clsStr.IndexOf("crashpad", StringComparison.OrdinalIgnoreCase) >= 0) return true;
        if (clsStr.IndexOf("NotifyIcon", StringComparison.OrdinalIgnoreCase) >= 0) return true;
        if (clsStr.IndexOf("StatusTray", StringComparison.OrdinalIgnoreCase) >= 0) return true;
        if (clsStr.IndexOf("PowerMessage", StringComparison.OrdinalIgnoreCase) >= 0) return true;
        bool chrome = clsStr.IndexOf("Chrome_WidgetWin", StringComparison.OrdinalIgnoreCase) >= 0;
        bool electron = clsStr.IndexOf("Electron", StringComparison.OrdinalIgnoreCase) >= 0;
        if (!chrome && !electron && titleLen <= 0) return true;

        int score = 1;
        if (chrome) score += 50;
        if (electron) score += 20;
        if (titleLen > 0) score += 10;
        if (IsWindowVisible(hWnd)) score += 15;
        if (titleStr.IndexOf("Codex", StringComparison.OrdinalIgnoreCase) >= 0) score += 25;
        if (titleStr.IndexOf("ChatGPT", StringComparison.OrdinalIgnoreCase) >= 0) score += 20;
        if (clsStr.IndexOf("Chrome_WidgetWin_1", StringComparison.OrdinalIgnoreCase) >= 0) score += 15;
        hits.Add(new WindowHit { Hwnd = hWnd, Pid = pid, ClassName = clsStr, Title = titleStr, Score = score });
        return true;
      }, IntPtr.Zero);
      hits.Sort((a, b) => b.Score.CompareTo(a.Score));
      return hits;
    }

    private static bool FocusHwnd(IntPtr hWnd) {
      if (hWnd == IntPtr.Zero) return false;
      // 从最小化/cloak 里救回来
      ShowWindow(hWnd, SW_RESTORE);
      ShowWindowAsync(hWnd, SW_SHOW);
      // Electron Chromium 有时把 "Intermediate D3D Window" 子窗标成 disabled。
      // 顶层窗口仍可 SetForeground，但鼠标/键盘进不了页面（整页点不动）。
      // 每次 focus 时把 disabled 子窗重新 Enable。
      EnableDisabledChildren(hWnd);

      uint _pid1 = 0, _pid2 = 0;
      uint targetThread = GetWindowThreadProcessId(hWnd, out _pid1);
      uint cur = GetCurrentThreadId();
      uint fgThread = GetWindowThreadProcessId(GetForegroundWindow(), out _pid2);
      bool a1 = false, a2 = false;
      try {
        AllowSetForegroundWindow(unchecked((int)ASFW_ANY));
        if (fgThread != cur) a1 = AttachThreadInput(cur, fgThread, true);
        if (targetThread != cur && targetThread != fgThread) a2 = AttachThreadInput(cur, targetThread, true);
        BringWindowToTop(hWnd);
        bool focused = SetForegroundWindow(hWnd);
        // 再扫一次：某些 restore 路径会在 foreground 之后才创建/禁用 D3D 子窗
        EnableDisabledChildren(hWnd);
        return focused;
      } finally {
        if (a2) AttachThreadInput(cur, targetThread, false);
        if (a1) AttachThreadInput(cur, fgThread, false);
      }
    }

    private static int EnableDisabledChildren(IntPtr parent) {
      int fixedCount = 0;
      EnumChildWindows(parent, (hWnd, l) => {
        if (!IsWindowEnabled(hWnd)) {
          // 只修可见渲染面；别碰 IME/托盘隐藏窗
          if (IsWindowVisible(hWnd) || ClassLooksLikeRenderSurface(hWnd)) {
            if (EnableWindow(hWnd, true)) fixedCount += 1;
          }
        }
        return true;
      }, IntPtr.Zero);
      return fixedCount;
    }

    private static bool ClassLooksLikeRenderSurface(IntPtr hWnd) {
      var cls = new StringBuilder(256);
      GetClassName(hWnd, cls, cls.Capacity);
      string s = cls.ToString() ?? "";
      return s.IndexOf("Intermediate D3D", StringComparison.OrdinalIgnoreCase) >= 0
          || s.IndexOf("Chrome_RenderWidget", StringComparison.OrdinalIgnoreCase) >= 0
          || s.IndexOf("Chrome_WidgetWin", StringComparison.OrdinalIgnoreCase) >= 0;
    }

    // ---- Log -----------------------------------------------------------------

    private static void Log(string path, string message) {
      try {
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        File.AppendAllText(path, DateTime.UtcNow.ToString("u") + " " + message + Environment.NewLine, Encoding.UTF8);
      } catch {}
    }

    // ---- P/Invoke ------------------------------------------------------------

    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    private const int SW_SHOW = 5;
    private const int SW_RESTORE = 9;
    private const uint ASFW_ANY = 0xFFFFFFFF;

    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr hWnd, EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool IsWindowEnabled(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool EnableWindow(IntPtr hWnd, bool bEnable);
    [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] private static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] private static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
    [DllImport("user32.dll")] private static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] private static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("kernel32.dll")] private static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] private static extern bool AllowSetForegroundWindow(int dwProcessId);
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern int SetCurrentProcessExplicitAppUserModelID(string AppID);
  }
}
