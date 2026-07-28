# Codexveil · pnpm audit / registry 路径证据 · 2026-07-28

**TASK：** `M-CV-audit-reg` · WAVE-DEBT-LONG  
**WT：** `C:\Users\yuanjia\orca\workspaces\Codexveil\cv-audit-registry-2026-07-28`  
**支：** `cv-audit-registry-2026-07-28`  
**基线 tip：** `bc09150`（`governance-cleanup-2026-07-28`）  
**WRITE_POLICY：** local-commit · **禁止** push / asar / publish-runtime / 把 registry token 写入仓库  
**STACK_SSOT：** [`docs/PROJECT.md`](../PROJECT.md) §1.5  
**前序 DEFER：** [`cv-oss-gap-2026-07-23.md`](./cv-oss-gap-2026-07-23.md) L2「CI audit 因 npmmirror 无 endpoint」

---

## 一句话

**DEFER 解开。** 默认/镜像 registry 上 `pnpm audit` 因 **无 bulk advisories endpoint** 失败；**强制 `https://registry.npmjs.org`** 后 exit 0、**No known vulnerabilities found**。落地路径：**CI hard gate + 本地 `npm run audit:deps`**（不改全局用户配置、不写 token）。

---

## 根因（本机 2026-07-28）

| 项 | 值 |
|----|-----|
| pnpm | **11.5.0**（`packageManager`） |
| Node | **v24.16.0**（本机探测；CI 用 22） |
| 用户 `~/.npmrc` | `registry=https://registry.npmjs.org` |
| **实际 pnpm registry** | `https://registry.npmmirror.com` |
| 镜像来源 | `%LOCALAPPDATA%\pnpm\config\auth.ini` → `registry=https://registry.npmmirror.com`（本机历史配置；**未**写入本仓） |
| 仓内 `.npmrc` | **无**（本会话不新增全局镜像/token） |

`pnpm audit` 请求：

```text
{registry}/-/npm/v1/security/advisories/bulk
```

npmmirror **不实现**该 endpoint → `ERR_PNPM_AUDIT_ENDPOINT_NOT_EXISTS` · exit **1**。  
这不是「树有 CVE」，是 **advisory 通道缺失**。

生产 npm 依赖数：**0**（ADR 0004 双平面；dev/contracts 仅 TypeScript 等）。Dependabot 仍覆盖周更。

---

## 实测矩阵（只读 · 本 WT · 2026-07-28）

| 命令 | 有效 registry | 结果 | exit |
|------|---------------|------|------|
| `pnpm audit`（默认） | npmmirror（auth.ini） | `ERR_PNPM_AUDIT_ENDPOINT_NOT_EXISTS` · bulk URL 指向 npmmirror | **1** |
| `pnpm audit --registry=https://registry.npmmirror.com` | npmmirror 显式 | 同上 | **1** |
| `pnpm audit --registry=https://registry.npmjs.org` | **官方** | `No known vulnerabilities found` | **0** |
| `node scripts/audit-local.mjs`（落地后） | 强制官方 | 同官方 | **0**（验收时再跑） |

**结论：** audit 信号 = **官方 registry 的 advisories bulk API**。镜像机必须显式 `--registry=https://registry.npmjs.org`（或跑 `audit:deps`）。

---

## 方案择一与落地（A + 薄 B）

| 选项 | 内容 | 本会话 |
|------|------|--------|
| **A** | CI 在 `themes-gate` 加 official-registry audit step；策略写清 | **已落** · **hard-fail**（无 `continue-on-error`；基线 0 vuln） |
| **B** | `scripts/audit-local.mjs` + `npm run audit:deps` 人/Agent 门 | **已落**（进程内强制官方；不改用户全局） |
| C | 仍 DEFER + 复检条件 | **否** — 已可跑 |

### CI（`.github/workflows/themes-gate.yml`）

```yaml
- name: Dependency audit (official registry)
  run: pnpm audit --registry=https://registry.npmjs.org --audit-level=high
```

- **何时跑：** 每个 `themes-gate` job（push/PR 到已配置 base），与 typecheck/test 同 job。  
- **为何不单独 job：** 仓小、依赖面仅 dev；同 job 减少重复 install。  
- **continue-on-error：** **false**。若 npm advisory 服务偶发 5xx，维护者可临时 `continue-on-error: true` + **日期注释** + 复检；默认不放行。  
- **audit-level=high：** moderate 以下不红（与桌面壳选修强度一致；Dependabot 仍报）。

### 本地

```powershell
# 推荐（不碰全局）
npm run audit:deps
# 等价
pnpm audit --registry=https://registry.npmjs.org
# 可选更严
node scripts/audit-local.mjs --audit-level=moderate
```

**不要：** 为 audit 把 registry token 写进 git；不要为 CI 提交指向私有 registry 的仓级 `.npmrc`。

---

## 对 oss-gap DEFER 的状态更新

| 原（2026-07-23） | 现（2026-07-28） |
|------------------|------------------|
| CI **无** `pnpm audit`；本机 npmmirror 失败 → **DEFER** / 人 gate 换官方 | **路径已通**：CI 强制官方 + `audit:deps`；本机官方 exit 0 |
| Dependabot 兜底 | **保留**（周更 npm + actions） |

复检条件（若再 DEFER）：官方 bulk endpoint 长期不可达 **且** Dependabot 也不能开 PR 时，再写日期 DEFER；镜像 alone **不再**作为永久 DEFER 理由。

---

## 验证命令（本会话）

```powershell
git rev-parse --short HEAD   # 基线 bc09150；补丁后 ahead
pnpm audit --registry=https://registry.npmjs.org   # expect exit 0
npm run audit:deps                                   # expect exit 0
npm run test:contracts                               # 已知 contracts 基线绿
# 可选全量
npm test
```

**未做：** true-publish · 重打安装包 · asar · `git push` · 改用户 `auth.ini` / 全局 mirror。

---

## 相关文件

| 路径 | 角色 |
|------|------|
| `scripts/audit-local.mjs` | 本地强制官方 audit |
| `package.json` → `audit:deps` | npm script 入口 |
| `.github/workflows/themes-gate.yml` | CI audit step |
| `docs/ops/cv-oss-gap-2026-07-23.md` | 原 DEFER 记录（历史保留；见上表） |
| `docs/SECURITY.md` | 运维控制行（指针） |
