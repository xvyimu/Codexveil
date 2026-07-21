# Agent 续作提示词 · codex-skin 五层收口 + U1 themes 接线

> 复制整份给新会话 / 新 agent。路径：`D:\orca\codex-skin`  
> 生成：2026-07-21 · 前会话中断点：PR#8 CONFLICTING + themes 接线未提交  

---

## 角色

你是 **codex-skin** 资深推进 Agent。仓库可读写与跑命令。  
**Shell：pwsh / 仓库脚本；git 操作用 bash 或 pwsh 均可，但路径用本机实际。**

## 仓库与远程

| 项 | 值 |
|----|-----|
| 路径 | `D:\orca\codex-skin` |
| origin | https://github.com/xvyimu/Codex-Dream-Skin |
| upstream | https://github.com/Fei-Away/Codex-Dream-Skin（只读对照，禁止 merge 上游） |
| 产品 | Windows-only Codex Desktop CDP 换肤 · 1.3.25 · 装机 runtime 常见 `1.3.25-2ae34a` |

## 必读（按序）

1. `CLAUDE.md`  
2. `docs/PROJECT.md`（§3 包边界 · 依赖双平面 ADR 0004）  
3. `docs/ARCHITECTURE.md`（跨层 palette 契约）  
4. `docs/adr/0004-engineering-modernization-u1.md`（**Accepted**）  
5. `docs/adr/0005-thin-product-shell-u3.md`（Proposed，勿抢做完整 Tauri）  
6. `docs/plans/u1-u3-two-week-plan-2026-07-21.md`  
7. `docs/reports/2026-07-21-five-layer-internal-opt-report.md`（或同目录 five-layer 报告）  
8. 记忆：`~/.claude/projects/D--orca/memory/codex-skin-handoff-2026-07-21.md`

## 硬边界（不可推翻 unless 用户表单改写）

1. **不改 main 直接提交**；功能在 feature 分支  
2. core ↔ runtime **禁止静态互引**（`npm run test:deps`）  
3. 安装态 `versions/<id>/` **默认零第三方 npm**；dev 平面可有 zod/ts  
4. **单 watch injector**；kick 降级 `--once` 不是第二产品线  
5. 不改 asar / 不镜像 2GB 安装树 / 不劫持 AUMID / macOS 非目标  
6. 主题 data-only（禁 scripts/hooks/eval 顶层）  
7. **push / merge / publish / 外发** 须用户明确授权（用户若说 push+squash 则执行）  
8. 不新增无必要依赖；五层阶段 **禁止** 为便利而跨包共享 IO  

## 当前真值（接手后立刻复证）

跑：

```bash
cd D:/orca/codex-skin
git fetch origin
git status -sb
git rev-parse --short HEAD origin/main
git branch --show-current
gh pr list --repo xvyimu/Codex-Dream-Skin --state open
git diff --stat origin/main..origin/feature/five-layer-internal-opt-2026-07-21
```

**预期（2026-07-21 深夜快照，以你跑的为准）：**

- `origin/main` ≈ **`2ae1ad3`**（含 contracts）  
- feature tip ≈ **`287aadb`**  
- **PR #8** OPEN base=**main** · 可能 **CONFLICTING**  
- **PR #7** 应已 close（错误 base `feat/u1-workspace`）  

## 诊断：为什么 PR#8 冲突 / 为何禁止硬 rebase

1. feature 历史上 **重复包含** 已 squash 进 main 的 U1 commits（`f578291` 等）  
2. `git rebase origin/main` 会对 `packages/contracts/**`、`pnpm-lock.yaml`、`themes-gate.yml` 产生 **add/add** 冲突  
3. **正确策略：内容拣选重建**，不是解 7 个 commit 的 rebase 战争  

## 任务 A · 五层干净合入 main（优先）

### A0. 确认五层文件清单（来自 tip）

相对 main 应类似（以 `git diff --stat origin/main..287aadb` 为准）：

- `packages/core/state/state-io.mjs` + `state-io.test.mjs`  
- `packages/core/state/{dreamskin-guard,kick-inject,state-freshness}.mjs`  
- `packages/core/cdp/{cdp-helpers,cdp-port}.mjs`  
- `packages/core/{constants,index,discover/process-win}.mjs`  
- `packages/runtime/scripts/{fs-io,fs-io.test,control-plane,thumb}.mjs`  
- `package.json`（`test:state-io` / `test:fs-io` 进 unit）  
- `docs/reports/*five-layer*`  
- 可选：`themes-gate.yml` 仅当有 **必要** 触发修正（main 已 Node22+pnpm；勿无故改坏）  

### A1. 重建干净分支

```bash
git fetch origin
git checkout origin/main
git checkout -b feature/five-layer-on-main-$(date +%Y%m%d)   # 或固定名 feature/five-layer-on-main

# 从已知好 tip 拣文件（不要 cherry-pick 整串 U1 历史）
git checkout 287aadb -- \
  packages/core/state/state-io.mjs \
  packages/core/state/state-io.test.mjs \
  packages/core/state/dreamskin-guard.mjs \
  packages/core/state/kick-inject.mjs \
  packages/core/state/state-freshness.mjs \
  packages/core/cdp/cdp-helpers.mjs \
  packages/core/cdp/cdp-port.mjs \
  packages/core/constants.mjs \
  packages/core/index.mjs \
  packages/core/discover/process-win.mjs \
  packages/runtime/scripts/fs-io.mjs \
  packages/runtime/scripts/fs-io.test.mjs \
  packages/runtime/scripts/control-plane.mjs \
  packages/runtime/scripts/thumb.mjs \
  package.json \
  docs/reports/

# 若 themes-gate 在 tip 有「仅增加合理 trigger」且不破坏 main CI，再 checkout 该文件并 diff 人工确认
git add -A
git status
# 单测
npm run test:unit
npm run test:deps
```

**kick 行为验收（折中逻辑，已在 287aadb）：**

- `resolveControlPort` 返回 `{ port, source: "state"|"file"|"default" }`  
- source 为 state/file → 端口列表 = `[port, DEFAULT_CONTROL_PORT]` 去重  
- source 为 default → 扫 `9336..9346`（与 control-plane `PORT_SCAN=11` 对齐）  
- **禁止**无脑恢复「每次 apply 都扫 9337–9340 且无 default 分支」的旧风暴  

### A2. 提交 / 推送 / PR

```text
commit message 建议：
refactor(core,runtime): five-layer internal opt on main (clean replay)

- state-io + runtime fs-io; isValidPort; DEFAULT_CONTROL_PORT
- hybrid kick port scan; unit tests state-io/fs-io
- report under docs/reports/
```

- push 新分支（用户已授权续作时可 push）  
- **新开 PR → base main**（或关闭 #8 后用新 PR；或 force-with-lease 更新 #8 的 head——**仅当**你理解 force 风险且用户允许）  
- 等 **themes-gate SUCCESS**  
- 用户曾授权 squash 时：`gh pr merge --squash`  
- 本地：`git checkout main && git pull --ff-only`（若分叉因 squash：`reset --hard origin/main`）  

### A3. 合入后可选

- **不**强制 publish；五层多为 core 调度，装机 runtime 未改 inject 热路径则 doctor 仍可能 fresh  
- 若改了 `packages/runtime/**` 且用户要装机一致：`pwsh -NoProfile -File scripts/windows/publish-runtime.ps1 -Version 1.3.25` + verify  

## 任务 B · U1：themes 接 contracts（五层合 main 后）

**前置**：main 已含五层 + contracts；分支 `feat/u1-themes-contracts` 从 **最新 main** 开。

### B1. 接线目标

- `packages/themes/theme-schema.mjs` 的 `normalizeColors` 在 hex 规范化后调用：  
  `import { parsePaletteWithSurface } from "../contracts/dist/index.js"`  
- **先** `pnpm run build:contracts`（或 unit 脚本前置 build）  
- `package.json` 的 `test:unit` **必须以** `build:contracts` 开头，避免 CI 无 dist  

### B2. 注意

- themes 的 `HEX_COLOR` 仍是 **#RRGGBB** 门；contracts 的 CSS 色更宽——当前路径先 hex 再 contracts，行为与现网一致  
- **不要**为了 import 方便让 runtime 依赖 contracts（runtime 发布自包含）  
- `test:deps` 仍须绿  

### B3. 验证

```bash
pnpm run build:contracts
npm run test:themes
npm run test:adapter
npm run test:store
npm run test:unit
npm run test:deps
```

### B4. PR

独立小 PR：`feat(themes): validate palette via @codex-skin/contracts`  
squash 合 main。

## 任务 C · 排期后续（勿在同一 PR 塞爆）

仅当 A+B 完成且用户要继续：

1. probe-kit 抽公共 CDP（迁 project-hd）  
2. stamp 纯函数 + 可选 shadow log（**先不改 inject 决策**）  
3. U3 尖兵：Node 客户端调 list/doctor/kick（**禁止第二 injector**）  
4. 勿默认做：F6 恢复、OV 签名、macOS、`.codexskin` 换格式、Tauri 完整壳  

## 网络 / 工具坑（本会话踩过）

| 坑 | 处理 |
|----|------|
| HTTPS push `127.0.0.1:443` / connection reset | `git push git@github.com:xvyimu/Codex-Dream-Skin.git HEAD:<branch>` 或清 proxy |
| pnpm 11 + Node 20 CI | themes-gate 用 **Node 22**；`packageManager` 字段勿与 action version 双写冲突 |
| vitest/esbuild ignored builds | contracts 测试用 **tsc + node:test**（main 已如此） |
| PR base 选错 | 产品 PR 一律 **base=main**；不要指到已删/过时 feat 分支 |
| 工作树脏 | 切换分支前 stash 或 commit；`git status` 先于一切 |

## 验证总清单

```bash
npm run test:unit
npm run test:deps
# 有 Codex + CDP 时：
node packages/core/cli.mjs doctor
node scripts/windows/probe-white-flash.mjs
node scripts/windows/probe-project-hd.mjs
```

## 完成时交付用户

1. 分支名 / HEAD / PR URL / CI 结论  
2. 是否已合 main  
3. 五层 + themes 接线各自状态  
4. 残留风险（kick default 扫描、未 publish 等）  
5. 硬边界遵守声明  

## 禁止

- 维护「PR 一定能硬 rebase」的面子  
- 未授权 force push main  
- 把五层 + 完整 U1 + Tauri 塞一个 PR  
- 静默引入生产依赖进 runtime  

---

**一句话任务**：用 **拣文件重建** 把 `287aadb` 的五层内容干净合进 main；再开分支让 `theme-schema.normalizeColors` 走 `@codex-skin/contracts`；每步可测、可 squash、可回滚。
