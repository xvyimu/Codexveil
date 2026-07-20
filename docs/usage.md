# Codex Skin · 一页使用说明

> 目标：你只记「点 Codex」。开得了、回得来、坏了能修、能换多套皮肤。

开发仓：`D:\orca\codex-skin`  
安装态：`%LOCALAPPDATA%\Programs\CodexDreamSkin`（runtime 1.3.25+）

---

## 日常怎么用

| 你想做什么 | 点哪里 |
|-----------|--------|
| 打开带皮肤的 Codex | 桌面 / 任务栏 / 开始菜单 **Codex** 或 **ChatGPT**（→ `CodexFastLaunch.exe`） |
| 已经打开再点一次 | 同一图标 → **聚焦窗口**（~40–100ms），并确保托盘在 |
| 换一套皮肤（推荐） | 桌面 / 开始菜单 **Codex 换肤**（图形列表） |
| 窗口内快速切换 | **F6** |
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

### 不要用微软商店磁贴开 Codex（PAIN #21）

商店磁贴 / 包 AUMID（`OpenAI.Codex_...!App`）走 **package activation**，**无法**被本产品改写成带 CDP 的入口——这是 Windows 硬限，不是 bug。

| 场景 | 结果 | 正确做法 |
|------|------|----------|
| 任务栏钉着 **Codex**（我们的 lnk → FastLaunch） | 有皮肤 | 继续用 |
| 开始菜单 / 桌面 **Codex** | 有皮肤 | 继续用 |
| **微软商店** 磁贴 /「最近添加的应用」里的 Codex | **裸启、无皮肤** | 忽略该磁贴；用任务栏钉 |
| 开机自启 | 有皮肤（Startup 已指向 FastLaunch） | 保持 |

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

## 换肤（多主题）

当前默认 **多主题已解锁**（catalog 11 套：preset 默认 + 原神 / 火影 / 鸣潮 / 恋与深空 / Miku 等）。

### 托盘

系统托盘图标 → **切换皮肤（N）** → 点名称（当前项带 ✓）

### 窗口内

按 **F6** 循环切换；toast 显示 `名称（i/N）`。

### CLI（推荐脚本/自动化）

```powershell
node D:\orca\codex-skin\packages\core\cli.mjs list
node D:\orca\codex-skin\packages\core\cli.mjs apply --theme genshin-night
node D:\orca\codex-skin\packages\core\cli.mjs apply --theme miku-488137
node D:\orca\codex-skin\packages\core\cli.mjs doctor
```

`apply` 只写 `active-theme`，由 watch injector 热更新，**不会**再起第二套注入器。

### 重新导入内置主题

```powershell
powershell -File D:\orca\codex-skin\scripts\windows\import-themes.ps1 -KeepUnlocked
# 或
node D:\orca\codex-skin\packages\core\cli.mjs import-themes
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
| F6 提示只有 1 套 | catalog 空或锁定；`import-themes` / unlock |
| 托盘菜单还是旧文案 | 退出托盘后重新点 Codex 拉起 |
| CLI apply 没变化 | 先确认任务栏 Codex 已开且 `doctor` 显示 injectorAlive |
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
| 开发仓 | `D:\orca\codex-skin` |
| 会话 | `%USERPROFILE%\.codex\sessions` |

---

## 不要做的事

- 不要改 `WindowsApps` 里的 Codex 安装文件  
- 不要并行跑旧 heige 一次性注入 / 旧 studio 入口  
- 不要用微软商店磁贴当日常入口（无 CDP = 无皮肤）  
- 不要在锁定模式下指望 F6/托盘多切  
