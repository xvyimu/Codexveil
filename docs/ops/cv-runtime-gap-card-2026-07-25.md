# Codexveil · tip vs install runtime gap card · 2026-07-25

**MODE：** `cv-runtime-gap` · **WRITE_POLICY：** `local-commit`（仅本卡 + commit；**禁止 push / asar / publish-runtime**）  
**WT / 支：** `C:\Users\yuanjia\orca\workspaces\Codexveil\cv-runtime-gap` · `xvyimu/cv-runtime-gap`  
**对照时刻：** 2026-07-24（会话日）本地只读探测  
**STACK_SSOT：** [`docs/PROJECT.md`](../PROJECT.md) §1.5 · 版本权威 ADR 0003  
**前序：** [`cv-day-ready-2026-07-24.md`](./cv-day-ready-2026-07-24.md) · [`true-publish-gate-checklist.md`](./true-publish-gate-checklist.md) · [`w3-republish-gate-dossier.md`](./w3-republish-gate-dossier.md)  
**OUT_OF_SCOPE：** asar 重打 · `publish-runtime.ps1` 执行 · glass 默认 ON · catalog 膨胀 · 改 injector/runtime 字节

---

## 一句话

**装机 live 与 tip 关键路径（injector ESM 图 + assets 主题/注入）已对齐；tip 超前部分以 docs / arina-only 文档与脚本示例为主。**  
**默认不 `publish-runtime`。** 仅当「装态缺模块 / 行为必须进用户机」且人 gate + VERSION 时才 publish。

---

## 1. 身份对照（本机实测）

| 面 | 值 | 注 |
|----|-----|----|
| git tip (HEAD / main) | **`7a6d13b`** · `7a6d13bf2deb13e2a1ab209a143ffcbe82c40b34` | `docs: path and theme footnote hygiene (arina-only)` · 2026-07-24 |
| 产品线 semver | **`1.3.25`** | 根 `package.json` `"version"` |
| 装机根 | `%LOCALAPPDATA%\Programs\CodexDreamSkin` | 存在 |
| **`current.json`** | `version=1.3.25` · **`runtimeId=1.3.25-da2adc`** · `relativeEnginePath=versions/1.3.25-da2adc` · `updatedAt=2026-07-22T19:44:02.1894611Z` · `codexSkinRepo=D:\orca\Codexveil` | 指针权威 |
| 装态 runtime 元数据 | `versions/1.3.25-da2adc/.dream-skin-runtime.json` · `publishedAt=2026-07-22T19:44:02Z` · `sourceRepo=D:\orca\Codexveil` | 与 current 一致 |
| 并存旧 runtime | `versions/1.3.25-11b868`（`publishedAt` 约 2 分钟更早） | **非** current；勿当 live |
| **state.json** | `runtimeId=1.3.25-da2adc` · `injectorPath=…\versions\1.3.25-da2adc\scripts\injector.mjs` · control 9336 · CDP 9335 | 与 current **对齐** |
| active theme | `preset-arina-hashimoto`（stateRoot `active-theme\theme.json`） | arina-only 产品线 |
| tip `themes/` | **仅** `preset-arina-hashimoto/` | 仓内 arina-only |
| tip `DEFAULT_THEME_ID` | `preset-arina-hashimoto`（`packages/core/constants.mjs`） | 不进 `versions/` payload |
| `SKIN_VERSION_TOKEN`（tip & 装态 injector） | **`"1.3.25"`**（两边同字面） | 非 `__SKIN_VERSION__` dev 占位 |

**重要：** `runtimeId` 后缀 **`da2adc` 是 `publish-runtime.ps1` 随机 6 hex**，**不是** git short SHA。  
**禁止**用「tip `7a6d13b` ≠ `da2adc`」单独判定需要 re-publish。

### 认 fresh 顺序（复述）

```text
current.json.runtimeId
  → state.json.runtimeId / injectorPath
  → doctor.injectorPathFreshness.fresh === true
  → （可选）SKIN_VERSION / verify-install-matches-repo
```

git tip ** alone ≠** 用户机已升级。

---

## 2. tip vs 装态字节（关键路径）

对照：  
- tip = worktree `…\cv-runtime-gap` @ `7a6d13b`  
- 装态 = `…\CodexDreamSkin\versions\1.3.25-da2adc`

### 2.1 必拷 runtime ESM（`$requiredRuntimeScripts`）

| 文件 | tip vs 装态 | 结论 |
|------|-------------|------|
| `injector.mjs` | **SHA 相同** · 45733 B | 齐 |
| `theme-load.mjs` | **SHA 相同** · 14854 B | 齐 |
| `payload-builder.mjs` | **SHA 相同** · 5166 B | 齐（W2/W3 主缺口已闭合） |
| `control-plane.mjs` | **SHA 相同** · 10270 B | 齐 |
| `fs-io.mjs` | **SHA 相同** · 761 B | 齐 |
| `cdp-url-guard.mjs` | 原始 hash 不同 · **换行归一后 content 相等** | 无逻辑差 |
| `theme-catalog-budget.mjs` | 同上 | 无逻辑差 |
| `image-metadata.mjs` | 同上 | 无逻辑差 |

→ **不会**再出现 W3 卷宗那种「tip injector 已 `import payload-builder`、装态缺文件 → `ERR_MODULE_NOT_FOUND`」。

### 2.2 assets

| 文件 | 结论 |
|------|------|
| `theme.json` | 换行归一后 content 相等 · id **`preset-arina-hashimoto`** · palette 粉系 |
| `dream-skin.css` | 换行归一后 content 相等 |
| `renderer-inject.js` | 换行归一后 content 相等 |
| `dream-reference.jpg` | **SHA 相同** · 688079 B |

### 2.3 core-win / launcher（versions 内）

| 文件 | 结论 |
|------|------|
| `launcher-ui.ps1` | SHA 相同 |
| `common-windows.ps1` / `runtime-windows.ps1` / `theme-windows.ps1` / `config-utf8.ps1` | 换行归一后 content 相等 |
| `tray-dream-skin.ps1` / `restore-dream-skin.ps1` / `launch-dream-skin.ps1`（versions） | 齐或归一后齐 |
| `start-dream-skin.ps1`（**versions/**） | 换行归一后 content 相等 · **含** `--state-root` |

### 2.4 programRoot 残留差（非 current 引擎主路径）

| 路径 | 差 | 是否挡 DAY |
|------|-----|-----------|
| `programRoot\start-dream-skin.ps1` | 相对 tip **缺** injector 参数 `--state-root $StateRoot`（约 1 行参数） | **低** — publish 白名单把 `start-dream-skin.ps1` 写到 **`versions/<id>/scripts/`**，**不**刷 programRoot 这份；live 以 current → versions 为准 |
| `programRoot\launch-dream-skin.ps1` | 换行归一后与 tip 相等 | ok |
| `programRoot\open-codex-dream-skin.ps1` / `check-and-fix` / `switch-theme-ui` | 与 tip SHA 相同 | ok |
| `programRoot\cli\themes\*` | 仍见 **11** 套历史目录名 | **文档债 / 旧 cli 镜像**；**不是** tip `themes/` SSOT；用户 catalog 以 stateRoot + 仓内 arina-only 为准，**勿**据此扩 catalog 或 asar |

### 2.5 tip 上相对「装态行为」的近期提交簇（摘要）

| 簇 | 代表 | 是否强制 publish |
|----|------|------------------|
| docs / OSS 门闩 / day-ready / footnote | `7a6d13b` · `ebaa39c` · `73ba840` · … | **否** |
| arina-only 文档 + `DEFAULT_THEME_ID` + 测试字面 | `435dac7` | **否**（constants 不进 versions） |
| install/publish **示例** 主题 id 纠偏 | `ff42fbe` | **否**（脚本源在 tip；装态已是 arina active） |
| Startup 默认关 + 视觉 chrome | `4e296f1` | 装态 assets 已与 tip 归一相等 → **本机无需为对齐再 publish**；他机若仍旧 chrome 再 gate |
| W2 payload-builder / wave8 required 图 | `8e09b45` · `e9c57b5` · … | **已在 da2adc** |

---

## 3. 何时才需要 `publish-runtime`

**唯一 stamp 命令（ADR 0003）：**

```powershell
pwsh -NoProfile -File scripts/windows/publish-runtime.ps1 -Version <x.y.z>
# 例：仍走 1.3.25 线 → -Version 1.3.25
# 会生成新 runtimeId = 1.3.25-<随机6hex> 并 flip current.json
```

### 需要（人 gate 后）

1. **必拷 ESM 图变更**：`injector` 新增/改 static 或 dynamic import，装态缺对应 `.mjs`（历史 Dual-B `theme-load`、W3 `payload-builder`、wave8 `control-plane`/`fs-io` 类）。  
2. **装态关键字节与 tip 逻辑分叉**：归一换行后 content 仍不等，且用户机要吃到该行为（注入/换肤/控制面/启动器）。  
3. **state 与 current 撕裂** 且修复路径就是整图 re-publish（而非软 reattach / 只改 state）。  
4. **显式发布决策**：VERSION 已定 + 操作者说「现在 publish」。

### 不需要（默认）

| 信号 | 处理 |
|------|------|
| tip SHA ≠ `runtimeId` 后缀 | **忽略**（后缀是随机 hex） |
| 仅 docs / ops 卡 / CHANGELOG / editorconfig | 不 publish |
| 仅 `packages/core/constants.mjs` / contracts / 测试 | contracts **永不**进 `versions/`（ADR 0004） |
| 仅 publish/install 脚本示例字符串 | 不 publish |
| hash 不同但 **CRLF/LF only** | 不 publish |
| 想「同步一下 tip」无行为目标 | **默认不 publish** |
| 想靠 asar / 手拷半份 scripts | **禁止** |

### 默认策略（本卡冻结）

```text
DEFAULT = DO NOT RUN publish-runtime.ps1
Agent / CI 证据上限 = verify-publish-runtime-payload.ps1 + npm test + 本卡对照
真 publish = 人 + VERSION + true-publish-gate-checklist
```

预检（人决定 publish 前，**仍不自动执行 publish**）：

```powershell
pwsh -NoProfile -File scripts/windows/verify-publish-runtime-payload.ps1   # VERIFY OK
# 可选：npm test · npm run doctor · verify-install-matches-repo.ps1（publish 后）
```

---

## 4. arina-only 提醒

| 项 | 要求 |
|----|------|
| 产品决议 | **仓内内置仅 arina**；扩 catalog **须 ADR**，本会话 **不做** |
| tip `themes/` | 仅 `preset-arina-hashimoto/` |
| CLI 默认 | `DEFAULT_THEME_ID = "preset-arina-hashimoto"` |
| 装态 active | 已是 arina（实测） |
| glass | injector `glass()` = DOM helper；**非** MS glass 默认 ON |
| 历史 `cli\themes` 11 套 / 旧文档「11 套」 | **不**当扩 catalog 授权；入口 README / usage / PROJECT 以 arina-only 为准 |
| apply 示例 | `apply` / `apply --theme preset-arina-hashimoto` — **不要**再写已删 preset 名 |

---

## 5. 本会话红线（执行记录）

| 动作 | 状态 |
|------|------|
| 改 injector / runtime 字节 | **未做** |
| `publish-runtime.ps1` | **未跑** |
| asar 重打 | **未做** |
| `git push` | **未做** |
| glass 默认 ON / 扩 catalog | **未做** |
| 本卡 | `docs/ops/cv-runtime-gap-card-2026-07-25.md` |
| commit 信息 | `docs(ops): CV tip vs install runtime gap card` |

---

## 6. 结论 / 状态

| 项 | 值 |
|----|-----|
| tip | `7a6d13b` |
| install runtimeId | **`1.3.25-da2adc`** |
| current ↔ state | **对齐** |
| 关键 ESM + assets | **逻辑齐**（少量 CRLF / programRoot 陈旧 start 副本） |
| **publish 建议** | **默认不 publish** |
| 卡状态 | **DONE** · **in-review** · **停** |

**下一步（仅人）：** 若未来 tip 真改 injector 图或装态行为分叉 → 走 [`true-publish-gate-checklist.md`](./true-publish-gate-checklist.md) → 口述 VERSION +「现在 publish」→ 再跑 `publish-runtime.ps1`。  
**Agent 停步：** 不 publish、不 push、不改 runtime。
