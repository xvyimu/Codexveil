# Codex Dream Skin — 痛点合集

> 由 `docs/e2e-pain-points-2026-07-19.md`（1.3.2 首轮 E2E）与
> `docs/ux-deep-pain-1.3.9.md`（1.3.9 深度走查）合并。
> 表格中"版本"= 首次记录该项的 runtime。"状态"= 迁到 1.3.13 时的实况。

---

## P0 · 用户会直接感到"慢/怪/卡"

| # | 痛点 | 版本 | 状态（1.3.13） |
|---|---|---|---|
| 1 | 换肤体感 2–3 秒（面板 200ms debounce + PS → node → CDP） | 1.3.2 | 已修 · `kick` 45ms |
| 2 | 注入 payload 逼近 4MB 预算（84%），再加图会失败 | 1.3.2 | 已修 · catalog 只嵌缩略图 |
| 3 | 焦点 C# `out _` 在 PS 5.1 编译失败，EnumWindows 整条链废 | 1.3.9 | 已修 · 命名 out 变量 |
| 4 | `Focus-CodexSkinWindow` / VBS 后 focused=false | 1.3.9 | 已修 · 预算内 bounded retry（MainWindow→EnumWindows→sleep 120ms 重试，`$TimeoutMs=1200`）+ `proc.Refresh()` 击穿缓存 |

## P1 · 可忍受但持续磨人

| # | 痛点 | 版本 | 状态（1.3.13） |
|---|---|---|---|
| 5 | 已运行时 open 慢 ~6s（PS 冷启动 + tray ensure + focus） | 1.3.2 | 已修 · 任务栏走 CodexFastLaunch.exe ~100ms；`/open-healthy` 异步 focus |
| 6 | `check-and-fix` 健康态仍 ~6s，未快出 | 1.3.2 | 已修 · fix ~3–4s |
| 7 | `state.controlPort` 空，仅有 `control.port` 文件 | 1.3.9 | 已修 · state.controlPort=9336 |
| 8 | CDP 探测偶发 false → 触发不必要 full open | 1.3.9 | 已修 · 短重试 + 硬超时 |
| 9 | `versions/` 堆积（1.2 → 1.3.2 共 6 套 5.5MB） | 1.3.2 | 已修 · publish GC 保留 current + 上一版 |
| 10 | SKIN_VERSION / renderer version 与 install version 脱节 | 1.3.2 | 已修 · SKIN_VERSION 与 install 同步 |
| 11 | post-update 报告陈旧（还停在旧 runtime） | 1.3.9 | 已修 · pwsh→powershell.exe 子进程继承 PS7 PSModulePath 令 PS5.1 加载 Microsoft.PowerShell.Security 失败；publish 后脚本首行重置 PSModulePath + `Import-Module`；**Quiet 任一 check 失败常见 exit=2**，publish 以 soft reattach 收口不算发版失败（G5-C 正式降级） |
| 12 | 会话页玻璃未在真实会话验证；probe 只到 home | 1.3.2 / 1.3.9 | 已修 · 真会话 probe pass + conversationPass；气泡去描边 |
| 13 | 发布后 reattach 杀旧 injector 失败 → 短暂双 injector | 1.3.2 | 已修 · `Stop-DreamSkinWatchInjectors` 全局清扫 + open/check 启动前硬门闩（身份不匹配不再 throw 挡清扫） |
| 14 | `cli list` 主题重复：repo + user store 都算 | 1.3.2 | 已修 · `listThemes({ dedupe:true })` + user root 后写覆盖 |
| 15 | 冷启动 shell ready 可 10s+（崩溃/半加载页） | 1.3.2 | 已改善 · wait-shell 复用 CDP 连接 + 自适应 120–500ms 退避；默认 45s 上限；就绪会话 ~76ms |

## P2 · 边角

| # | 痛点 | 版本 | 状态 |
|---|---|---|---|
| 16 | 控制面 `/focus` ~1s（spawn PS） | 1.3.9 | 已绕过 · 任务栏/托盘 native 进程内 focus；`/open-healthy` 异步 |
| 17 | VBS 快路径 ~2.5s（WinHttp + focus PS 冷启动） | 1.3.9 | 已废弃 · 任务栏改 CodexFastLaunch.exe |
| 18 | 修复/回归工具链偏工程师向，普通用户误点 | 1.3.2 | 已修 · `install-ux` 唯一源；产品包带 VBS + 使用说明；Uninstall 清 Codex 工具/ChatGPT/Startup |
| 19 | ChatGPT 8 Electron 进程，MainWindow 难找 | 1.3.9 | 已修 · 进程评分修好后生效 |
| 20 | heige studio 目录残留（无进程） | 1.3.2 | 仓内已清（vendor/heige · legacy-inject 删）；ux 扫删 heige/Studio lnk；**Programs 下独立 heige 目录仍须用户手卸**（非通用自动） |
| 21 | 商店磁贴/AUMID/Codex-X 仍可能裸启 | 1.3.2 | 已知硬限 · 文档化；FastLaunch 独立 AUMID；日常钉任务栏 Codex（见 usage / dual-open-policy） |
| 22 | 控制台中文乱码（GBK 工具链） | 1.3.2 | 已修 · `Initialize-CodexSkinConsoleUtf8` + 入口 chcp 65001 / UTF-8 OutputEncoding |
| 23 | verify 对 chat bubble 选择器 `data-user-message-bubble` not found | 1.3.2 | 已修 · 多 fallback + conversationOk；真会话 verify 通过 |
| 24 | 首次运行 SmartScreen 拦截未签名入口 / FastLaunch | 1.3.25 | **已知** · 未 OV 签名；用户点「更多信息 → 仍要运行」；签名属 P3 长期规划（见 usage）；决策见 [`plans/codesign-decision-2026-07-21.md`](./plans/codesign-decision-2026-07-21.md)（2026-07-21 · 近期 No-Go 购证 / 维持 A） |
| 25 | 窗内 **F6** 循环换肤 / toast 不可用 | 1.3.25 | **已知 · 文档已对齐**（2026-07-21）· CDP 探针：`__CODEX_DREAM_SKIN_STATE__` 无 `cycleTheme`/`setTheme`/`catalog`；换肤请用托盘 / Codex 换肤 / CLI `apply`。恢复 F6 = 另卡（inject catalog+hotkey+toast，服从 catalog 预算，**必 publish**）；探针：`scripts/windows/probe-white-flash.mjs` 亦报 F6 缺 |

---

## 用户旅程摘要

| 旅程 | 顺畅度 | 主要摩擦 |
|---|---|---|
| 再点任务栏 Codex | 高 | bounded retry 后 focus 稳定 |
| 换肤 / kick | 高 | ~45ms；U3 气泡可关 |
| 开项目视觉 | 高 | 2026-07-21 修：palette 全量透传 + dark 判定；探针 pass |
| F6 | **低（预期）** | #25 无 cycleTheme；用托盘/面板/CLI |
| 商店更新后 | 高 | post-update 报告随 publish 自动刷新 |
| 修复 | 中 | 健康态偶发长等待 |
| 会话审美 | 高 | 1.3.19 probe pass=true, conversationPass=true 实锤 |

---

## 安全审计摘记

| ID | 日期 | 结论 |
|----|------|------|
| **SEC-02** | 2026-07-21 | 已审计：`Write-CodexSkinLog` / control-plane `console.error` / kick-inject 路径**未**把 `control.token` 明文写入日志；token 仅作 header/内存比较。health 仅回传 `tokenPresent` 布尔。 |
| **SECURITY.md** | 2026-07-21 | 威胁模型 + 报告渠道：[`SECURITY.md`](./SECURITY.md) |

## 相关文档

- 修复时间线：见 `CHANGELOG.md`（release-1.3.1 ~ 1.3.13 合集）
- E2E 复测脚本：`scripts/windows/e2e-pain-test.ps1`
- 原始 JSON 报告落点：`%LOCALAPPDATA%\CodexDreamSkin\e2e-pain-report.json`
- 贡献规范：`docs/CONTRIBUTING.md` · 任务卡：`docs/plans/task-cards-2026-07-21.md`
