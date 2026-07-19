# Codex Skin · 一页使用说明

> 目标：你只记「点 Codex」。开得了、回得来、坏了能修、能换多套皮肤。

开发仓：`D:\orca\codex-skin`  
安装态：`%LOCALAPPDATA%\Programs\CodexDreamSkin`（runtime 1.3.0+）

---

## 日常怎么用

| 你想做什么 | 点哪里 |
|-----------|--------|
| 打开带皮肤的 Codex | 桌面 / 任务栏 / 开始菜单 **Codex** 或 **ChatGPT**（均已改为带皮肤启动） |
| 已经打开再点一次 | 同一图标 → **聚焦窗口**，并确保托盘在 |
| 换一套皮肤（推荐） | 桌面 **Codex 换肤**（图形列表，双击即换） |
| 窗口内快速切换 | **F6** |
| 托盘管理 / 暂停 | **Codex Skin 管理**（或托盘图标右键） |
| 皮肤没了 | **Codex 皮肤修复** 或再点 **Codex** |
| 命令行 / 脚本 | 见下方 CLI |

**不要**从微软商店磁贴开「裸」Codex（没有调试端口就没有皮肤）。

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

当前默认 **多主题已解锁**（catalog 约 10+ 套：原神 / 火影 / 鸣潮 / Miku 等）。

### 托盘

**Codex Dream Skin 管理** → **切换皮肤（N）** → 点名称（当前项带 ✓）

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

登录后跑与任务栏相同的启动器（端口 **9335**）。

若开机时先开了裸 Codex，再点一次任务栏 Codex 接管。

---

## Codex 商店更新后

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$env:LOCALAPPDATA\Programs\CodexDreamSkin\post-update-regression.ps1" -Port 9335
# 需要自动修：
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
| 窗口在、没皮肤 | **Codex 皮肤修复** 或再点任务栏 Codex |
| F6 提示只有 1 套 | catalog 空或锁定；`import-themes` / unlock |
| 托盘菜单还是旧文案 | 退出托盘后重新打开「管理」 |
| CLI apply 没变化 | 先确认任务栏 Codex 已开且 `doctor` 显示 injectorAlive |
| 旧 heige apply | **已归档**，请用 `D:\orca\codex-skin` CLI |

---

## 关键路径

| 用途 | 路径 |
|------|------|
| 启动器 | `%LOCALAPPDATA%\Programs\CodexDreamSkin\open-codex-dream-skin.ps1` |
| 修复 | `...\check-and-fix.ps1` |
| 冒烟 | `...\smoke-dream-skin.ps1` |
| 主题库 | `%LOCALAPPDATA%\CodexDreamSkin\themes` |
| 当前皮肤 | `%LOCALAPPDATA%\CodexDreamSkin\active-theme` |
| 开发仓 | `D:\orca\codex-skin` |
| 会话 | `%USERPROFILE%\.codex\sessions` |

---

## 不要做的事

- 不要改 `WindowsApps` 里的 Codex 安装文件  
- 不要并行跑旧 heige 一次性注入  
- 不要在锁定模式下指望 F6/托盘多切  
