# 发版证据清单（维护者）

产品线版本：`package.json` / publish `-Version` 对齐（当前 **1.3.25**）。不抬版本号 unless intentional。

## 每次发版前

- [ ] `npm test`（themes + deps + freshness）
- [ ] 若改 `packages/runtime/**`：`pwsh scripts/windows/publish-runtime.ps1 -Version <line>`
- [ ] `pwsh scripts/windows/verify-install-matches-repo.ps1 -RepoRoot <repo>` → exit 0
- [ ] `node packages/core/cli.mjs doctor` → `injectorPathFreshness.fresh=true`
- [ ] 可选：PROJECT §9.4 probe 表（home + conversation；**不进 CI**）
- [ ] 若改 control-plane token：`npm run test:control`（本机 loopback）

## 说明

- Quiet post-update exit=2 + soft reattach OK = 正式降级，**不算**发版失败（见 publish 日志 `soft reattach OK` + 失败 check 摘要）
- 链：PROJECT §6 · CONTRIBUTING §C-3/C-4 · §9.4
