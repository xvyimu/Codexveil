# Codex Skin · 一页使用说明

> 目标：你只记「点 Codex」。开得了、回得来、坏了能修、能换多套皮肤。

开发仓：`D:\orca\Codexveil`（入口 `D:\projects\Codexveil`）  
安装态：`%LOCALAPPDATA%\Programs\CodexDreamSkin`（runtime 1.3.25+）

---

## 日常怎么用

| 你想做什么 | 点哪里 |
|-----------|--------|
| 打开带皮肤的 Codex | 桌面 / 任务栏 / 开始菜单 **Codex** 或 **ChatGPT**（→ `CodexFastLaunch.exe`） |
| 已经打开再点一次 | 同一图标 → **聚焦窗口**（~40–100ms），并确保托盘在 |
| 换一套皮肤（推荐） | 桌面 / 开始菜单 **Codex 换肤**（图形列表） |
| 窗口内快速切换 | **托盘「切换皮肤」** / **Codex 换肤** / CLI `apply`（见下；F6 见说明） |
| 托盘管理 / 暂停 | 系统托盘 **Codex Dream Skin** 图标右键 |
| 皮肤没了 | 开始菜单 **Codex 工具 → 皮肤修复**，或再点 **Codex** |
| 商店更新后 | **Codex 工具 → 商店更新后修复** |
| 命令行 / 脚本 | 见下方 CLI |

### 快捷方式分层（PAIN #18）

| 层级 | 有什么 | 没有什么 |
|------|--------|----------|
| 日常（桌面 / 任务栏 / 开始菜单顶层） | **Codex** · **ChatGPT** · **Codex 换肤** | 修复 / 回归 / 说明 |
| 工具（开始菜单 **Codex 工具** 文件夹） | 皮肤修复 · 商店更新后修复 · 使用说明 | 不放桌面，降低误点 |

重复的「Codex Skin」入口、旧「Codex Skin 高级」文件夹、散落的「管理 / 更新回归」会在 `install-ux-shortcuts.ps1` 里清掉。

### 首次运行若遇 SmartScreen（PAIN #24）

本产品入口 / `CodexFastLaunch.exe` **未做 OV 代码签名**。Windows 可能弹出「Windows 保护了你的电脑」：

1. 点 **更多信息**  
2. 再点 **仍要运行**  

这是预期摩擦，不是安装失败。长期若评估 OV 证书签名，见 [`PAIN-POINTS.md`](./PAIN-POINTS.md) #24（P3，非本版交付）。

### 不要用微软商店磁贴开 Codex（PAIN #21 · 不是 bug）

商店磁贴 / 包 AUMID（`OpenAI.Codex_...!App`）走 **package activation**，**无法**被本产品改写成带 CDP 的入口——这是 **Windows OS 硬限**。  
本产品**不会**、也**不能**劫持商店包身份。若你点了商店磁贴出现「无皮肤」，请改用任务栏钉，不要重装皮肤。

| 场景 | 结果 | 正确做法 |
|------|------|----------|
| 任务栏钉着 **Codex**（我们的 lnk → FastLaunch） | 有皮肤 | **只认这个** |
| 开始菜单 / 桌面 **Codex** | 有皮肤 | 继续用 |
| **微软商店** 磁贴 /「最近添加的应用」里的 Codex | **裸启、无皮肤** | 忽略该磁贴；用任务栏钉 |
| 开机自启 | **默认关闭**（2026-07-23：不再写 Startup；publish 也不会重建） | 需要自启时自行在「启动」里添加 FastLaunch |

若已经裸启：再点一次任务栏 **Codex**（会安静 reattach / 必要时带 CDP 重启），或 **Codex 工具 → 皮肤修复**。

打开 Codex 时会自动（**默认不弹窗**）：
1. 启用 CDP 调试端口 9335  
2. 拉起 / 复用 watch 注入  
3. 确保托盘在跑  
4. 若已是「裸 Codex」，安静自动重启接管（不弹确认框）

需要气泡提示时，可手动：

```powershell
powershell -File "$env:LOCALAPPDATA\Programs\CodexDreamSkin\open-codex-dream-skin.ps1" -ShowReady
```

---

## 换肤（主题）

**产品默认（2026-07）：** 仓内内置 **arina-only** — `themes/preset-arina-hashimoto`（装机 active / runtime 模板同 id）。  
扩 catalog / 多 IP 主题须 **维护者 ADR**，勿把历史「11 套」叙述当现行产品。

用户侧仍可用 **自建/导入** 主题写入 `%LOCALAPPDATA%\CodexDreamSkin\themes\`（schema data-only）；F6 / 托盘循环的是**本机 catalog**，不是仓内 11 套。

### 托盘

系统托盘图标 → **切换皮肤（N）** → 点名称（当前项带 ✓；N = 本机 catalog 数）

### 窗口内 F6（代码已恢复 · 需 publish 对齐装态）

仓内 `renderer-inject` 支持 **F6** / **Shift+F6** 循环 **本机 catalog**，并 toast `名称（i/N）`；STATE 暴露 `catalog` / `setTheme` / `cycleTheme`。  
装态 payload 以 `current.json.runtimeId` 为准。若窗内 F6 无感而仓内已有修复：维护者跑 `publish-runtime.ps1 -Version <线>` 刷新 `versions/<id>/`；开发可用 repo 树 injector `--watch` 验证。

| 方式 | 操作 |
|------|------|
| 窗内（publish 后 / dev watch） | **F6** 下一主题 · **Shift+F6** 上一主题（catalog≥2 时有感） |
| 图形 | 开始菜单 / 桌面 **Codex 换肤** |
| 托盘 | 系统托盘 → **切换皮肤（N）** |
| CLI | `node packages/core/cli.mjs apply --theme <id>`（省略 `--theme` → `DEFAULT_THEME_ID` = `preset-arina-hashimoto`） |

F6 为注入态瞬切，**不**写 active-theme；持久换肤仍用托盘 / 面板 / CLI。见 [`PAIN-POINTS.md`](./PAIN-POINTS.md) **#25**。开机自启默认关闭见上表「日常怎么用」。

### 消息气泡样式（对比）

提问 / 回答气泡支持两种样式（**不改功能，只改描边与块面**）：

| 样式 | 观感 | 如何选 |
|------|------|--------|
| **无边框**（默认） | heige 原味：无描边、轻阴影、圆角 | 默认；托盘显示「消息气泡：无边框」 |
| **圆角卡片** | 细描边 + 更清晰卡片块面 | 托盘点「消息气泡：无边框（点切圆角卡片）」 |

配置：`%LOCALAPPDATA%\CodexDreamSkin\ui-prefs.json` → `"bubbleStyle": "borderless" | "card"`。  
切换后托盘会 **kick** 热应用；也可 CLI 后手动 kick。

### CLI（推荐脚本/自动化）

```powershell
node D:\orca\Codexveil\packages\core\cli.mjs list
node D:\orca\Codexveil\packages\core\cli.mjs apply --theme preset-arina-hashimoto
node D:\orca\Codexveil\packages\core\cli.mjs doctor
```

> 路径以本机克隆为准（统一入口 `D:\projects\Codexveil` 亦可）。`<id>` 须已在本机 catalog / 仓内 `themes/`；默认装机主题为 **`preset-arina-hashimoto`**。

`apply` 只写 `active-theme`，由 watch injector 热更新，**不会**再起第二套注入器。  
成功后默认弹一次轻反馈气泡（U3）；失败时气泡会带简短 note。

### 换肤成功气泡（可关 · U3）

| 路径 | 说明 |
|------|------|
| 托盘右键 | **换肤气泡：开（点此关闭）** / **关（点此开启）** |
| 配置文件 | `%LOCALAPPDATA%\CodexDreamSkin\ui-prefs.json` → `"applyBalloonEnabled": false` |

关闭后：托盘菜单 ✓ / 换肤面板文案仍更新；**错误类**提示（裸启、CDP 关闭等）与**首次入口**提示不受此开关影响。

### 首次入口提示（U4）

第一次用任务栏 **Codex** 打开时，会一次性气泡说明：

1. 日常用任务栏「Codex」  
2. **不要用微软商店磁贴**（无皮肤是 OS 硬限 #21，不是故障）  
3. 换肤入口与异常修复  

标记文件：`%LOCALAPPDATA%\CodexDreamSkin\first-run-shown.flag`（存在即不再显示）。  
**不会**劫持商店 AUMID。要再看一次：删掉该 flag 后重新 open。

### 重新导入内置主题

```powershell
powershell -File D:\orca\Codexveil\scripts\windows\import-themes.ps1 -KeepUnlocked
# 或
node D:\orca\Codexveil\packages\core\cli.mjs import-themes
```

---

## 单皮肤锁定（可选）

若只想保留一套、禁止误切换：

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$env:LOCALAPPDATA\Programs\CodexDreamSkin\lock-themes.ps1"
```

解锁：

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$env:LOCALAPPDATA\Programs\CodexDreamSkin\lock-themes.ps1" -Unlock
```

锁定时：托盘切换菜单不可用；F6 只有 1 套可切。

---

## 开机自启

登录后跑与任务栏相同的启动器（`CodexFastLaunch.exe` · 端口 **9335**）。

若开机时先开了裸 Codex（例如商店自启），再点一次任务栏 Codex 接管。

---

## Codex 商店更新后

开始菜单 **Codex 工具 → 商店更新后修复**，或：

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$env:LOCALAPPDATA\Programs\CodexDreamSkin\post-update-regression.ps1" -Port 9335 -Repair
```

冒烟：

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$env:LOCALAPPDATA\Programs\CodexDreamSkin\smoke-dream-skin.ps1"
```

期望：`SMOKE_PASS` / `POST_UPDATE_PASS`。

---

## 故障速查

| 现象 | 处理 |
|------|------|
| 窗口在、没皮肤 | **Codex 工具 → 皮肤修复**，或再点任务栏 Codex |
| 从商店磁贴打开无皮肤 | 正常（#21）；改用任务栏钉着的 Codex |
| F6 无反应 / 不换肤 | 安装态未 publish 新 runtime（#25）；或 catalog 仅 1 条；可用托盘 / Codex 换肤 / CLI apply |
| F6 提示只有 1 套 | catalog 空或锁定；`import-themes` / unlock 后重开会话 |
| 托盘菜单还是旧文案 | 退出托盘后重新点 Codex 拉起 |
| CLI apply 没变化 | 先确认任务栏 Codex 已开且 `doctor` 显示 injectorAlive |
| apply 无气泡 | 托盘「换肤气泡」已关，或看 `ui-prefs.json`；面板/托盘 ✓ 仍会变 |
| 想再看首次入口提示 | 删 `%LOCALAPPDATA%\CodexDreamSkin\first-run-shown.flag` 后点任务栏 Codex |
| 旧 heige / Codex Studio 入口 | **已废弃**；删残留快捷方式后只用本产品 Codex |

---

## 关键路径

| 用途 | 路径 |
|------|------|
| 原生快启 | `%LOCALAPPDATA%\Programs\CodexDreamSkin\CodexFastLaunch.exe` |
| 启动器 | `...\open-codex-dream-skin.ps1` |
| 修复 | `...\check-and-fix.ps1` |
| 冒烟 | `...\smoke-dream-skin.ps1` |
| 主题库 | `%LOCALAPPDATA%\CodexDreamSkin\themes` |
| 当前皮肤 | `%LOCALAPPDATA%\CodexDreamSkin\active-theme` |
| 开发仓 | `D:\orca\Codexveil` |
| 会话 | `%USERPROFILE%\.codex\sessions` |

---

## 不要做的事

- 不要改 `WindowsApps` 里的 Codex 安装文件  
- 不要并行跑旧 heige 一次性注入 / 旧 studio 入口  
- 不要用微软商店磁贴当日常入口（无 CDP = 无皮肤）  
- 不要把窗内 **F6** 当持久换肤（不写 active-theme；安装态需先 publish 新 runtime）  
- 不要在锁定模式下指望托盘多切  
