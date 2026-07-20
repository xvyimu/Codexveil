## 改动摘要

<!-- 一句话说明 why -->

## 模块依赖 7 问（[`docs/CONTRIBUTING.md`](../docs/CONTRIBUTING.md) §C-1）

- [ ] 1. 改了哪个包？
- [ ] 2. 新增静态 import？
- [ ] 3. core↔runtime 互引？（否）
- [ ] 4. 新增注入旁路？（否）
- [ ] 5. 路径走 `resolveStudioPaths` / `Get-CodexSkin*`？
- [ ] 6. 改 active-theme 写入？
- [ ] 7. 改版本源？（否，仅 `publish-runtime.ps1 -Version`）

## 验收对照（勾选适用项）

- [ ] §C-2 主题 PR（`npm run test:themes` + `list` + `apply`）
- [ ] §C-3 runtime/CSS PR（`doctor` + `apply` 手测）
- [ ] §C-4 publish/产品包 PR（`-Version` + 安装态）
- [ ] §C-5 命名（新增函数 `Verb-CodexSkinNoun`）
- [ ] §C-6 小步提交（imperative message）
- [ ] §C-8 禁止事项速查表（15 条全否）

## 验证命令

```powershell
node packages/core/cli.mjs doctor
npm test
```

## 关联

- ADR：
- PAIN-POINTS：
- 任务卡 ID：
