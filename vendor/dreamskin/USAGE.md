# Codex Dream Skin · 一页使用说明

> 目标：你只记「点 Codex」。开得了、回得来、坏了能修、对话不丢。

---

## 日常怎么用

| 你想做什么 | 点哪里 |
|-----------|--------|
| 打开带皮肤的 Codex | 任务栏 / 桌面 / 开始菜单 **Codex** |
| 已经打开再点一次 | 同一图标 → **聚焦窗口**，不重启 |
| 皮肤没了 | 再点一次 **Codex** |
| 还不行 | 开始菜单 **Codex 皮肤修复** |
| 高级菜单（暂停/换背景） | **Codex Dream Skin 管理** |

**不要**从微软商店磁贴或其它路径开「裸」Codex（没有调试端口就没有皮肤）。

---

## 开机自启

登录后会自动跑与任务栏相同的启动器：

`open-codex-dream-skin.ps1 -Port 9335 -NoPrompt`

若开机时你先手动开了裸 Codex，可能需再点一次任务栏 Codex（会中文确认是否重启接管）。

---

## 单皮肤锁定

当前只保留 **active-theme**（桥本有菜 / romantic-rose）。

- `themes\themes.locked` + 目录写保护
- 托盘「保存主题」在锁定下不可用
- 需要多皮肤时：

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$env:LOCALAPPDATA\Programs\CodexDreamSkin\lock-themes.ps1" -Unlock
```

用完可再 lock：

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$env:LOCALAPPDATA\Programs\CodexDreamSkin\lock-themes.ps1"
```

F6：仅一个皮肤时提示「当前只保留一个皮肤」，不会乱切。

---

## 对话记录

- 启动器**不**使用独立 `--user-data-dir`
- 会话在默认 profile + `~\.codex\sessions`
- 重启可能丢的只有**未发送草稿**；已完成对话仍在

---

## Codex 商店更新后（C4）

商店更新 Codex 后跑一次回归：

```powershell
# 只检查（Codex 需已由任务栏打开且带皮肤，或至少能解析安装包）
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$env:LOCALAPPDATA\Programs\CodexDreamSkin\post-update-regression.ps1" -Port 9335

# 检查并自动修复（可重启裸 Codex）
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$env:LOCALAPPDATA\Programs\CodexDreamSkin\post-update-regression.ps1" -Port 9335 -Repair
```

报告输出：

- 控制台：`POST_UPDATE_PASS` / `POST_UPDATE_FAIL`
- JSON：`%LOCALAPPDATA%\CodexDreamSkin\post-update-report.json`
- 日志：`%LOCALAPPDATA%\CodexDreamSkin\post-update-regression.log`

日常自检也可用：

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$env:LOCALAPPDATA\Programs\CodexDreamSkin\smoke-dream-skin.ps1"
```

期望：`SMOKE_PASS`。

---

## 故障速查

| 现象 | 处理 |
|------|------|
| 窗口在、没皮肤 | 点 **Codex 皮肤修复** 或再点任务栏 Codex |
| 弹窗问是否重启 | 当前是裸 Codex；选「是」接管（草稿可能丢） |
| 点了没反应 | 开始菜单 **Codex 皮肤修复**；仍失败看 `open-codex-dream-skin.log` |
| 想确认健康 | 跑 `smoke-dream-skin.ps1` |
| 商店刚更新 | 跑 `post-update-regression.ps1 -Repair` |

---

## 关键路径

| 用途 | 路径 |
|------|------|
| 启动器 | `%LOCALAPPDATA%\Programs\CodexDreamSkin\open-codex-dream-skin.ps1` |
| 修复 | `...\check-and-fix.ps1` |
| 冒烟 | `...\smoke-dream-skin.ps1` |
| 更新回归 | `...\post-update-regression.ps1` |
| 主题锁 | `...\lock-themes.ps1` |
| 运行时 | `...\versions\`（由 `current.json` 指向） |
| 数据 | `%LOCALAPPDATA%\CodexDreamSkin\`（active-theme / state / logs） |
| 会话 | `%USERPROFILE%\.codex\sessions` |

---

## 不要做的事

- 不要改 `WindowsApps` 里的 Codex 安装文件
- 不要随便删 `active-theme`
- 不要把 Startup 改回已归档的 `auto-launch-fei-*.ps1`
- 锁定模式下不要强行往 `themes\` 塞目录

---

## 一句话

**点 Codex；坏了点修复；更新后跑 post-update-regression -Repair。**
