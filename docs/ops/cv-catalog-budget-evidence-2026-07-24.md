# Codexveil · catalog budget / quality evidence · 2026-07-24

**MODE：** `M-CV-catalog-budget` · WEEK W6 · **WRITE_POLICY：** `local-commit`（仅本卡 + commit；**禁止 push / asar / publish-runtime / catalog 膨胀 / 第二 injector**）  
**WT / 支：** `C:\Users\yuanjia\orca\workspaces\Codexveil\cv-catalog-budget` · `xvyimu/cv-catalog-budget`  
**对照时刻：** 2026-07-24 本机重跑  
**STACK_SSOT：** [`docs/PROJECT.md`](../PROJECT.md) §1.5 · 主题仅经 `packages/themes` + `themes/<id>/` · arina-only  
**结论：** **All green → NO-CODE**（未改 runtime / themes 实现字节）

---

## 一句话

`npm run test:catalog-budget` 与 `npm run test:catalog-quality` 本机均 **exit 0**；仓内 bundled 主题仍为 **1**（`preset-arina-hashimoto`）；预算常量仍 pin：`MAX_THEME_CATALOG_ENTRIES=8` · `MAX_CATALOG_MEMBER_BYTES=96KiB` · `MAX_THEME_CATALOG_BYTES=1.6MiB`。

---

## 1. 身份

| 面 | 值 |
|----|-----|
| git tip (本 WT HEAD) | **`ebc3568`** · `docs(ops): CV tip vs install runtime gap card` |
| 产品线 semver | **`1.3.25`**（根 `package.json`） |
| 分支 | `xvyimu/cv-catalog-budget` |
| tip `themes/` | **仅** `preset-arina-hashimoto/`（arina-only） |

---

## 2. 验证命令 + exit code

在 worktree 根执行（`pwsh` · 会话日 2026-07-24）：

| 命令 | exit | 摘要 |
|------|------|------|
| `npm run test:catalog-budget` | **0** | `theme-catalog-budget.test: pass` · 常量 + `evaluateCatalogMemberBudget` 边界（requireFull / member-too-large / max-entries / catalog-bytes）全绿 |
| `npm run test:catalog-quality` | **0** | budget 源文本 pin 对齐 · renderer catalog/setTheme 路径 · **bundled themes present (found 1)** · arina schema+surface+text+hero art on disk |

未跑（本卡 **OUT_OF_SCOPE**）：

- `publish-runtime.ps1` / 改 asar / catalog 扩容 / 第二 injector
- 全量 `npm test`（非本切片门闩；unit 链已含上述两 script）

### 复现

```powershell
cd C:\Users\yuanjia\orca\workspaces\Codexveil\cv-catalog-budget
npm run test:catalog-budget
# expect: theme-catalog-budget.test: pass  + exit 0
npm run test:catalog-quality
# expect: theme catalog quality tests passed  + exit 0
```

---

## 3. 门闩对照（纪律）

| 约束 | 状态 |
|------|------|
| arina-only（仓内 1 主题） | **pass** · quality `found 1` · id `preset-arina-hashimoto` |
| F6 catalog cap = 8 | **pass** · budget + quality 双 pin |
| 单成员 96 KiB · 总仓 1.6 MiB | **pass** |
| 无 catalog 膨胀 | **pass** · NO-CODE |
| 无 asar / 无第二 injector / 无 publish | **pass** · 本卡未触 |

---

## 4. 变更清单

| 路径 | 动作 |
|------|------|
| `docs/ops/cv-catalog-budget-evidence-2026-07-24.md` | **新增**（本文件） |
| 其它 | **无**（All green = NO-CODE） |

---

## 5. DONE

- [x] 重跑 `test:catalog-budget` · exit **0**
- [x] 重跑 `test:catalog-quality` · exit **0**
- [x] 证据卡落盘（本文件）
- [x] **in-review** · 仅 `docs(ops)` commit · **不** push
