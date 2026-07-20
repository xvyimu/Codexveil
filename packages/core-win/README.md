# packages/core-win

PowerShell 5.1 共享库。`apps/launcher/*.ps1` 通过 `.` (dot-source) 加载。

## 加载顺序

启动器一般只 dot-source `launcher-ui.ps1`；它内部按需读入其他四份（或由 publish 时复制到 `programRoot\lib\`）。

## 文件职责

| 文件 | LOC（约） | 关键函数前缀 | 说明 |
|---|---|---|---|
| `launcher-ui.ps1` | 1059+ | `Get-CodexSkinProgramRoot`, `Get-CodexSkinControlToken`, `Invoke-CodexSkinControl`, `Show-CodexSkinBalloon`, `Ensure-CodexSkinTray`, `Focus-CodexSkinWindow` | 启动器公共 UI：日志/气泡/托盘/焦点/runtime 解析 · control-plane token |
| `common-windows.ps1` | 658 | `Get-DreamSkinCdp*`, `Get-DreamSkinCodex*`, `Read/Write-DreamSkinState`, `Stop-DreamSkin*` | Codex 发现 · 端口/CDP · state.json · 进程 |
| `config-utf8.ps1` | 528 | `ConvertFrom-DreamSkinUtf8Bytes`, `Assert-DreamSkinFileUnchanged` | UTF-8 (含 BOM) 解析、JSON 校验 |
| `theme-windows.ps1` | 419 | `Read/Write-DreamSkinTheme`, `Set-DreamSkinActiveTheme`, `Save-DreamSkinCurrentTheme` | 主题 IO 与图像校验 |
| `runtime-windows.ps1` | 278 | `Get-DreamSkinNodeRuntime`, `Resolve-DreamSkinRuntimePayload` | 从 `current.json` 解析 versions/<id>/ · node runtime |

## 命名规约

- 老代码用 `DreamSkin-` 前缀（M0/M1 从 DreamSkin 仓迁入）
- 新代码用 `CodexSkin-` 前缀（M2+ 加入的启动器路径）
- 迁移中，二者混用，不做批量改名以免破坏安装态 dot-source

## 发布

`scripts/windows/publish-runtime.ps1` 会：
1. `launcher-ui.ps1` → `programRoot\lib\launcher-ui.ps1` **和** `versions\<id>\scripts\launcher-ui.ps1`
2. 其余四份 → `versions\<id>\scripts\`
3. 入口脚本（open/check/switch/smoke/kick-theme-now）从这里 dot-source

## 未来（不阻塞当前发布）

若 `launcher-ui.ps1`（现 ~1059 行）确实成为维护负担，考虑按 `Get-* / Show-* / Focus-* / Ensure-*` 前缀切分。
先不动，因为：
1. PS 5.1 dot-source 顺序敏感，切开容易漏
2. 现有安装态部署已经稳定
3. 只在真正阻塞开发时才动
