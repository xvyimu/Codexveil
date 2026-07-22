# Codexveil · W4 装态对齐证明 · 2026-07

> **只读本机 Programs** · **不** 跑 `publish-runtime.ps1` · **不** 写 `current.json`  
> 对照 tip：`4914631` · worktree：`C:\Users\yuanjia\orca\workspaces\Codexveil\w4-cv-claude`

---

## 1. 身份

| 字段 | 值 |
|------|-----|
| **Install root** | `%LOCALAPPDATA%\Programs\CodexDreamSkin` |
| **`current.json.version`** | `1.3.25` |
| **`current.json.runtimeId`** | **`1.3.25-d403fa`** |
| **`relativeEnginePath`** | `versions/1.3.25-d403fa` |
| **`updatedAt`** | `2026-07-22T18:37:50.9913767Z`（装态记录） |
| **探针日** | 2026-07-23（本 wt W4） |
| **旧装态残留** | `versions/1.3.25-eee7c8` 仍在盘（GC 保留 previous）· **current 已指 d403fa** |

### `current.json` 摘录（字段）

```json
{
  "schemaVersion": 1,
  "product": "CodexDreamSkin",
  "version": "1.3.25",
  "runtimeId": "1.3.25-d403fa",
  "relativeEnginePath": "versions/1.3.25-d403fa",
  "updatedAt": "2026-07-22T18:37:50.9913767Z",
  "codexSkinRepo": "D:\\orca\\Codexveil"
}
```

---

## 2. 关键 ESM · Test-Path + SHA256（装态 vs tip 源树）

路径约定：

- **install**：`…\versions\1.3.25-d403fa\scripts\<file>`
- **repo**：`packages/runtime/scripts/<file>`（本 worktree tip）

| 文件 | install Test-Path | size (B) | install SHA256 | repo SHA256 | 结论 |
|------|-------------------|----------|----------------|-------------|------|
| **payload-builder.mjs** | **True** | 5166 | `76EA61C30B1E628C…BBDD95CB` | 同左 | **MATCH** |
| **theme-load.mjs** | **True** | 14854 | `A6DB17012D5CB2C1…FBB2CE0F` | 同左 | **MATCH** |
| **control-plane.mjs** | **True** | 10270 | `F4D18AD7B3809359…AEC8B8ED` | 同左 | **MATCH** |
| **fs-io.mjs** | **True** | 761 | `FC5CF89C9A63AF36…E8C45DF5` | 同左 | **MATCH** |
| **injector.mjs** | **True** | 45733 | `E97628E0D24C41B0…05BD0C0D` | 同左 | **MATCH** |
| cdp-url-guard.mjs | True | 1103 / 1132 | `C229772E7A45…` | `404844D4421C…` | **DIFF**（外围） |
| theme-catalog-budget.mjs | True | 2093 / 2160 | `DEF42E076EAC…` | `143A25EBEAEF…` | **DIFF**（外围） |
| image-metadata.mjs | True | 1646 / 1684 | `FF1991688EDB…` | `35B6E048211B…` | **DIFF**（外围） |

### 对比旧装态 eee7c8（历史缺口）

| 文件 | eee7c8 | d403fa |
|------|--------|--------|
| `payload-builder.mjs` | **False**（W3 主缺口） | **True** |
| `theme-load` / `control-plane` / `fs-io` / `injector` | True | True |

---

## 3. 模块图行为结论

| 检查 | 结论 |
|------|------|
| tip `injector.mjs` 静态 `import … from "./payload-builder.mjs"` | 与装态 injector **字节一致** → 装态图完整 |
| tip 装入无 builder 会 `ERR_MODULE_NOT_FOUND` | **对 eee7c8 成立**；**对 d403fa 不成立**（文件在） |
| 默认 assets theme | 装态 `preset-arina-hashimoto` |
| doctor `injectorPathFreshness.fresh` | **true** · expected/actual runtimeId = `1.3.25-d403fa` |

**总判：** 装态 **`1.3.25-d403fa`** 与 tip 关键 runtime ESM（含 **payload-builder S3**）**已对齐**。  
外围三脚本 DIFF 不阻塞 W2 模块图闭合；下一刀 tip 变更后由人 gate 再 publish 整图对齐即可。

---

## 4. 本波不动作

| 动作 | 状态 |
|------|------|
| `publish-runtime.ps1` | **NOT EXECUTED**（装态已新 · 题单禁止再 stamp） |
| 写 `current.json` / 删 versions | **未做** |
| push | **未做** |

---

## 5. 复现探针（只读）

```powershell
$root = "$env:LOCALAPPDATA\Programs\CodexDreamSkin"
$cur  = Get-Content "$root\current.json" -Raw | ConvertFrom-Json
$ver  = Join-Path $root $cur.relativeEnginePath
"runtimeId=$($cur.runtimeId)"
@(
  "payload-builder.mjs",
  "theme-load.mjs",
  "control-plane.mjs",
  "fs-io.mjs",
  "injector.mjs"
) | ForEach-Object {
  $p = Join-Path $ver "scripts\$_"
  "$_ : $(Test-Path $p) sha12=$((Get-FileHash $p -Algorithm SHA256).Hash.Substring(0,12))"
}
```
