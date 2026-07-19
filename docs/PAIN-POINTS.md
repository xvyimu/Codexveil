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
| 4 | `Focus-CodexSkinWindow` / VBS 后 focused=false | 1.3.9 | 半好 · EnumWindows 有时成功，有时仍 no-window |

## P1 · 可忍受但持续磨人

| # | 痛点 | 版本 | 状态（1.3.13） |
|---|---|---|---|
| 5 | 已运行时 open 慢 ~6s（PS 冷启动 + tray ensure + focus） | 1.3.2 | 部分改善 · control-plane `/open-healthy` 命中时 <1s |
| 6 | `check-and-fix` 健康态仍 ~6s，未快出 | 1.3.2 | 已修 · fix ~3–4s |
| 7 | `state.controlPort` 空，仅有 `control.port` 文件 | 1.3.9 | 已修 · state.controlPort=9336 |
| 8 | CDP 探测偶发 false → 触发不必要 full open | 1.3.9 | 已修 · 短重试 + 硬超时 |
| 9 | `versions/` 堆积（1.2 → 1.3.2 共 6 套 5.5MB） | 1.3.2 | 已修 · publish GC 保留 current + 上一版 |
| 10 | SKIN_VERSION / renderer version 与 install version 脱节 | 1.3.2 | 已修 · SKIN_VERSION 与 install 同步 |
| 11 | post-update 报告陈旧（还停在旧 runtime） | 1.3.9 | 未修 · publish 后未自动刷新 |
| 12 | 会话页玻璃未在真实会话验证；probe 只到 home | 1.3.2 / 1.3.9 | 未修 · 需要人工进对话后再 probe |
| 13 | 发布后 reattach 杀旧 injector 失败 → 短暂双 injector | 1.3.2 | 半好 · 偶发多 injector |
| 14 | `cli list` 主题重复：repo + user store 都算 | 1.3.2 | 未修 · list/doctor 未去重 |
| 15 | 冷启动 shell ready 可 10s+（崩溃/半加载页） | 1.3.2 | 未修 · adaptive wait 极限 |

## P2 · 边角

| # | 痛点 | 版本 | 状态 |
|---|---|---|---|
| 16 | 控制面 `/focus` ~1s（spawn PS） | 1.3.9 | 仍在 · 需原生 focus |
| 17 | VBS 快路径 ~2.5s（WinHttp + focus PS 冷启动） | 1.3.9 | 仍在 |
| 18 | 修复/回归工具链偏工程师向，普通用户误点 | 1.3.2 | 未整合 · 快捷方式仍散 |
| 19 | ChatGPT 8 Electron 进程，MainWindow 难找 | 1.3.9 | 已修 · 进程评分修好后生效 |
| 20 | heige studio 目录残留（无进程） | 1.3.2 | 未清 · 双开诱惑 |
| 21 | 商店磁贴/AUMID/Codex-X 仍可能裸启 | 1.3.2 | 已知限制 · 无法拦 |
| 22 | 控制台中文乱码（GBK 工具链） | 1.3.2 | 未修 · 快捷方式本体 Unicode 正常 |
| 23 | verify 对 chat bubble 选择器 `data-user-message-bubble` not found | 1.3.2 | 半好 · 首页 OK，会话页需再验 |

---

## 用户旅程摘要

| 旅程 | 顺畅度 | 主要摩擦 |
|---|---|---|
| 再点任务栏 Codex | 中 | 焦点 EnumWindows 偶发 no-window |
| 换肤 / kick | 高 | ~45ms |
| F6 | 高 | 缩略图全覆盖 |
| 商店更新后 | 中 | post-update 报告旧 · 裸启需托盘发现 |
| 修复 | 中 | 健康态偶发长等待 |
| 会话审美 | 未实锤 | 需进对话再 probe |

---

## 相关文档

- 修复时间线：见 `CHANGELOG.md`（release-1.3.1 ~ 1.3.13 合集）
- E2E 复测脚本：`scripts/windows/e2e-pain-test.ps1`
- 原始 JSON 报告落点：`%LOCALAPPDATA%\CodexDreamSkin\e2e-pain-report.json`
