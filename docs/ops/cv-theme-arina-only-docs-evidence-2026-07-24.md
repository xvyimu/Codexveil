# Codexveil · arina-only docs alignment evidence · 2026-07-24

**MODE：** `M-CV-theme-arina-only-docs` · WEEK W9 · **WRITE_POLICY：** `local-commit`（仅本卡 + 可选最小 docs 纠偏 + commit；**禁止 push / asar / publish-runtime / 新增主题 / 第二 injector**）  
**WT / 支：** `C:\Users\yuanjia\orca\workspaces\Codexveil\cv-theme-arina-only-docs` · `xvyimu/cv-theme-arina-only-docs`  
**对照时刻：** 2026-07-24 本机重跑  
**STACK_SSOT：** [`docs/PROJECT.md`](../PROJECT.md) §1.5 · 主题仅经 `packages/themes` + `themes/<id>/` · **arina-only**  
**前序：** [`cv-day-ready-2026-07-24.md`](./cv-day-ready-2026-07-24.md) · [`cv-oss-gap-2026-07-23.md`](./cv-oss-gap-2026-07-23.md) · catalog-budget 支 `xvyimu/cv-catalog-budget`  
**结论：** 入口文档 **已对齐** arina-only → **无冲突 docs 改**；门闩绿 → 仅落本证据卡

---

## 一句话

仓内内置主题 **仅** `preset-arina-hashimoto`；`DEFAULT_THEME_ID` / runtime 模板 / 入口 README · usage · PROJECT 附录均钉 arina-only；`npm run test:catalog-quality` 与 `npm run test:themes` 本机均 **exit 0**。用户 catalog 可自建，F6 循环的是**本机 catalog**，不是仓内多套。

---

## 1. 身份

| 面 | 值 |
|----|-----|
| git tip (本 WT HEAD，写卡前) | **`ebc3568`** · `docs(ops): CV tip vs install runtime gap card` |
| 产品线 semver | **`1.3.25`**（根 `package.json`） |
| 分支 | `xvyimu/cv-theme-arina-only-docs` |
| tip `themes/` | **仅** `preset-arina-hashimoto/`（`theme.json` + `hero.jpg`） |

---

## 2. arina-only 钉点（代码 + 资源）

| 项 | 权威 | 实测 |
|----|------|------|
| 产品决议 | PROJECT / PRODUCT-LAYERS / day-ready | **arina-only**；扩仓内 catalog 须 ADR |
| 仓内 `themes/` | 目录枚举 | **1** 子目录：`preset-arina-hashimoto` |
| CLI 默认 | `packages/core/constants.mjs` | `DEFAULT_THEME_ID = "preset-arina-hashimoto"` |
| runtime 模板 | `packages/runtime/assets/theme.json` | `id=preset-arina-hashimoto` · palette rose/surface 与源主题一致 |
| schema 源 | `themes/preset-arina-hashimoto/theme.json` | id 同 · accent `#E8A0BF` · surface `#1A1218` · text `#FFF0F5` · secondary `#C9A0DC` · hero `hero.jpg` |
| 用户 catalog | `%LOCALAPPDATA%\CodexDreamSkin\themes\` | **可**自建 schema 主题；**不**自动扩仓内 `themes/` |
| F6 / 托盘循环 | usage · PAIN #25 语义 | 循环 **本机 catalog**，非仓内历史 11 套 |

---

## 3. 入口文档对齐扫（冲突？）

| 文档 | arina-only / sole id | 「11 套 / 多套内置」冲突 | 本卡动作 |
|------|----------------------|-------------------------|----------|
| `README.md` | **OK** · 状态段写 arina-only + `themes/preset-arina-hashimoto` | 无（「多主题热切换」= 能力面 F6/托盘，非仓内 11 套） | **不改** |
| `docs/usage.md` | **OK** · 产品默认 arina-only；显式纠偏历史「11 套」；`DEFAULT_THEME_ID` 钉 id | 无 | **不改** |
| `docs/PROJECT.md` | **OK** · 树图/附录 A/B 钉 arina-only · `DEFAULT_THEME_ID` | 无（「多主题 catalog」= 用户侧 + F6 能力；附录 B 已写历史 11 套仅存 git） | **不改** |
| `docs/PRODUCT-LAYERS.md` | **OK** · 明确不做「多主题目录膨胀（arina-only）」 | 无 | **不改** |
| `docs/ARCHITECTURE.md` | **OK** · 主线 arina-only · `themes/*` 现行 sole | 无（装态 path 表「多主题 catalog」= 用户目录） | **不改** |
| 长文 AUDIT / 旧 ops / CHANGELOG 历史段 | 可能仍写 11 套 | **不阻塞**（非入口 SSOT；oss-gap 已记） | **不改** |

**纠偏结论：** 入口三件套（README / usage / PROJECT）与 arina-only **无冲突** → 本卡 **0** 业务/入口 docs 补丁；仅 evidence。

---

## 4. 验证命令 + exit code

在 worktree 根执行（`pwsh` · 会话日 2026-07-24）：

| 命令 | exit | 摘要 |
|------|------|------|
| `npm run test:catalog-quality` | **0** | budget 常量 pin · renderer catalog 路径 · **bundled themes present (found 1)** · arina schema+surface+text+hero on disk |
| `npm run test:themes` | **0** | schema 双格式 + 危险键拒绝 + contrast · **`bundled theme count === 1 (arina-only)`** · sole id `preset-arina-hashimoto` · loadTheme 全绿 |

未跑（本卡 **OUT_OF_SCOPE**）：

- `publish-runtime.ps1` / asar / 第二 injector / catalog 膨胀 / push main
- 全量 `npm test`（非本切片硬门；unit 链已含上述 script）

### 复现

```powershell
cd C:\Users\yuanjia\orca\workspaces\Codexveil\cv-theme-arina-only-docs
npm run test:catalog-quality
# expect: theme catalog quality tests passed  + exit 0
npm run test:themes
# expect: theme-schema.test: all passed  + exit 0
# optional pin:
#   Get-ChildItem themes -Directory | Select-Object -ExpandProperty Name
#   → preset-arina-hashimoto
```

---

## 5. 纪律门闩

| 约束 | 状态 |
|------|------|
| 仓内仅 `preset-arina-hashimoto` | **pass** · 目录 + quality/themes 双 assert |
| `DEFAULT_THEME_ID` 对齐 sole bundled | **pass** |
| 入口 docs 不宣称现行 11 套内置 | **pass** · 扫 README/usage/PROJECT |
| 用户 catalog 可自建；F6 = 本机 catalog | **pass** · usage 已写 |
| 无新主题资源 / 无 asar / 无第二 injector / 无 publish | **pass** · 本卡未触 |

---

## 6. 变更清单

| 路径 | 动作 |
|------|------|
| `docs/ops/cv-theme-arina-only-docs-evidence-2026-07-24.md` | **新增**（本文件） |
| `README.md` / `docs/usage.md` / `docs/PROJECT.md` | **无改**（已对齐，无冲突） |
| `themes/` · injector · runtime 字节 | **无** |

---

## 7. DONE

- [x] 先读 brief + PROJECT §1.5 意图 + themes/ + DEFAULT_THEME_ID
- [x] 入口文档冲突扫 → **无**最小纠偏需要
- [x] `test:catalog-quality` · exit **0**
- [x] `test:themes` · exit **0**
- [x] 证据卡落盘（本文件）
- [x] **in-review** · 仅 `docs(ops)` commit · **不** push
