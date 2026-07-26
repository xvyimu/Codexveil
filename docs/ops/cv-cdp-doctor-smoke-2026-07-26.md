# Codexveil · CDP doctor 暴露面检查 + smoke · 2026-07-26

**MODE：** `M-CV-cdp-doctor` · **WRITE_POLICY：** `local-commit`（**禁止 push main / asar / publish-runtime**）
**WT / 支：** `…\orca\workspaces\Codexveil\cv-opt-cdp-doctor` · `xvyimu/cv-opt-cdp-doctor`（base `main` tip `ebc3568`）
**触发：** code-review [`CV-CR-001`]（`D:\orca\.planning\portfolio-stack-policy-2026-07-24\code-review\codexveil-findings.md` §2 P1）
**STACK_SSOT：** [`docs/PROJECT.md`](../PROJECT.md) §1.5 · CDP 默认端口 **9335** · 控制面 **9336**
**前序 / 交叉：** [`cv-runtime-gap-card-2026-07-25.md`](./cv-runtime-gap-card-2026-07-25.md)（tip vs install runtime 差距 · 默认不 publish）· [`docs/SECURITY.md`](../SECURITY.md)
**OUT_OF_SCOPE：** asar 补丁 · `publish-runtime.ps1` · 第二 injector · catalog 重整

---

## 一句话

**doctor 现在检查 CDP 端口（默认 9335）监听地址是否 loopback-only，并把「勿暴露到局域网」的安全提示写进 doctor JSON（`cdpExposure`）与 `diagnosis`；纯函数判定有单测（`test:cdp-exposure`），已并入 `npm test`。**

---

## 1. 威胁模型摘要（CV-CR-001）

| 项 | 结论 |
|----|------|
| 信任边界 | **本机**。CDP `Runtime.evaluate` 无认证；任何能连上 `127.0.0.1:9335` 的本机进程与本产品同权，可影响 Codex 渲染进程 |
| 在范围 | 端口被暴露到局域网（防火墙放行 / `netsh portproxy` / 端口转发）→ 远端主机获得同等注入能力 |
| 不在范围 | 本机恶意软件（已同权，见 SECURITY.md 威胁表）；Codex 官方是否开 CDP 的决策 |
| 既有防线 | CDP / 控制面只连 `127.0.0.1`（`cdp-url-guard.mjs` · `control-plane.mjs` bind loopback · `/kick` 带 token）|
| 本卡新增 | doctor **观测面**：实测端口监听地址，非 loopback 显式告警；固定安全提示随 JSON 输出 |

## 2. 改了什么

| 文件 | 内容 |
|------|------|
| `packages/core/cdp/cdp-exposure.mjs` | 新增。`parseNetstatListeners` / `isLoopbackListenAddress` / `evaluateCdpExposure`（纯函数）+ `inspectCdpExposure`（win32 `netstat -ano`，无需管理员；失败降级 `not-checked`）+ `CDP_LOCAL_TRUST_ADVICE` 固定提示 + `formatCdpExposureNote` |
| `packages/core/cdp/cdp-exposure.test.mjs` | 新增。10 组纯函数/注入 exec 单测（loopback 分类、netstat 解析、通配告警、未监听、netstat 失败、非 win32、非法端口） |
| `packages/core/cli.mjs` | doctor 输出新增顶层 `cdpExposure`；`diagnosis` 末尾追加暴露面一句结论；`inspectCdpExposure` 可注入（测试用） |
| `packages/core/index.mjs` | 导出 `inspectCdpExposure` / `evaluateCdpExposure` / `formatCdpExposureNote` / `CDP_LOCAL_TRUST_ADVICE` |
| `package.json` | 新增 `test:cdp-exposure`，并入 `test:unit`（→ `npm test`） |

**边界遵守：** 只动 `packages/core`（doctor 观测面），不改 runtime/injector 字节 → **不触发 publish**（见 gap 卡 §3「不需要」表：仅 core 逻辑 + doctor 输出，`packages/core` 不进 `versions/`）。

## 3. 怎么跑（可重复 smoke）

```powershell
cd <repo>

# 1) 纯函数门闩（无网络 / 无 netstat，CI 可跑）
npm run test:cdp-exposure          # 期望：cdp-exposure tests: all passed · exit 0

# 2) 全量单测
npm test                           # 期望：exit 0

# 3) 真机 doctor（本机 · 无需 Codex 运行）
npm run doctor                     # = node packages/core/cli.mjs doctor
```

### 期望输出（关键字段）

| 场景 | `cdpExposure` 关键值 | `diagnosis` 尾句 |
|------|----------------------|------------------|
| Codex 未运行 | `checked:true · listening:false · loopbackOnly:null` | `CDP 端口未在监听（Codex 未运行或未带调试参数）` |
| Codex 运行（正常） | `listening:true · loopbackOnly:true · exposedAddresses:[]` | `CDP 仅监听 loopback，符合本机信任边界` |
| 端口被暴露（异常） | `loopbackOnly:false · exposedAddresses:["0.0.0.0" 等]` | `警告：CDP 端口 9335 监听非 loopback 地址（…）；调试端口不应暴露到局域网，请移除端口转发 / 防火墙放行规则` |
| netstat 不可用 | `checked:false · reason:"netstat-failed"` | `CDP 暴露面未检查（netstat-failed）` |

每种场景 `advice` 恒为 `CDP_LOCAL_TRUST_ADVICE`（本机信任边界 + 勿放行到局域网/公网）。

## 4. 本机实测记录（2026-07-26）

| 命令 | 结果 | exit |
|------|------|------|
| `node packages/core/cdp/cdp-exposure.test.mjs` | 38 断言全过，`all passed` | 0 |
| `npm test` | unit（含新 `test:cdp-exposure`）+ contracts 全过 | 0 |
| `node packages/core/cli.mjs doctor` | `cdpExposure.checked=true · listening=false`（Codex 未运行）· `injectorPathFreshness.fresh=true`（`1.3.25-da2adc`，与 gap 卡一致）· diagnosis 含暴露面尾句 | 0 |

与 [`cv-runtime-gap-card-2026-07-25.md`](./cv-runtime-gap-card-2026-07-25.md) 交叉：本卡实测 `current ↔ state` 仍对齐（`runtimeId=1.3.25-da2adc`）；本改动**不**产生 publish 需求（`packages/core` 不在 `versions/` payload 内）。

## 5. 用户/运维提示（doctor 之外）

- **不要**为 9335/9336 建防火墙入站放行规则或 `netsh interface portproxy`；两端口只应本机可达。
- 远程调试需求（如另一台机器看 DevTools）→ 用 SSH 本地转发到操作者自己机器，**不**把端口绑到 `0.0.0.0`。
- 发现 `loopbackOnly:false` → 先 `netstat -ano | findstr :9335` 找 PID，确认是谁在通配监听（Codex 自身默认 loopback，通配多半是 portproxy 或第三方代理）。

## 6. 红线执行记录

| 动作 | 状态 |
|------|------|
| 改 injector / runtime 字节 | **未做** |
| `publish-runtime.ps1` / asar | **未跑 / 未做** |
| `git push main` | **未做**（仅 wt 分支本地 commit） |
| 第二 injector / catalog 重整 | **未做** |

## 7. 状态

**DONE** · 验收：doctor 可感知改进（`cdpExposure` + diagnosis 告警）+ 单测门闩 + 本卡命令可重复。
