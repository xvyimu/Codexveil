# ADR 0003 — 单一版本源（Single Version Source）

- **状态**：Accepted（已实施于 runtime 1.3.16）
- **日期**：2026-07-20
- **相关**：0002（上游同步）

## 背景

runtime 的版本号曾在 5 处硬编码：`injector.mjs` 的 `SKIN_VERSION` 常量，以及
`renderer-inject.js` 的 `dataset.dreamVersion`（×2）、`window[STATE_KEY].version`、
`return { version }`。每次发版都要手动同步这 5 处，漏改会让 `verify` 的
`version === expectedVersion` 失败——1.3.13→1.3.14→1.3.15 期间就因此反复手改。

## 决策

**publish 时的 `-Version` 参数是唯一权威。**

- runtime 源文件顶部各声明一次：
  ```js
  const SKIN_VERSION_TOKEN = "__SKIN_VERSION__";
  const SKIN_VERSION = SKIN_VERSION_TOKEN === "__" + "SKIN_VERSION__" ? "dev" : SKIN_VERSION_TOKEN;
  ```
  （`"__" + "SKIN_VERSION__"` 拼接防止字符串替换误伤自检式本身）
- 所有版本使用点改为引用 `SKIN_VERSION`，不再有裸字面量。
- `publish-runtime.ps1` 用正则把 `const SKIN_VERSION_TOKEN = "..."` 的字面量
  替换成 `-Version` 值，**只写入刚拷贝的 `versions/<id>/` 副本**（install/payload 面）。
  **repo 源文件（`packages/runtime/{scripts/injector.mjs,assets/renderer-inject.js}`）
  始终保持占位符 `__SKIN_VERSION__`，publish 不再回写 git tree。**
- 直接 `node` 跑 repo 源 → token 仍是占位符 → `SKIN_VERSION = "dev"`（dev-mode 契约恒成立）。

## 结果

- 发版只改一个地方（`-Version` 参数）；5 处使用点自动一致。
- `verify` 的 `version === expectedVersion` 永远成立（同一替换值）。
- git 能看到当前版本（repo 源文件被 stamp），符合"版本对源码可见"的要求。

## 权衡 / 已知代价

- **修订（2026-07-27 · debt#1）**：早期实现选择"publish 一并写回 repo 源文件"，
  导致发版后 repo 里被 stamp 成上次版本号（如 `"1.3.25"`），dev-mode 契约在已发布过
  的 checkout 上失效（本地 `node` 跑假报 published 而非 `"dev"`）。现已回退：
  **publish 只 stamp `versions/<id>/` 副本，repo 源恒为占位符**。代价是 git 里看不到
  "当前发布版本号"——但版本可见性由 `versions/<id>/`、`current.json`、`VERSION` 文件、
  `.dream-skin-runtime.json`、CHANGELOG 提供，无需污染源占位符。dev 纯净性 > git 源可见性。
- 依赖字面量格式 `const SKIN_VERSION_TOKEN = "..."` 稳定；若重命名该常量需同步改
  publish 的正则。

## 产品包路径（补充 · 2026-07-20）

终端分发 zip（`Build-ProductPackage.ps1` / `Install-Product.ps1`）**不是**第二权威：

| 动作 | 是否 stamp git tree | 版本从哪来 |
|------|---------------------|------------|
| `publish-runtime.ps1 -Version` | **是**（唯一写回） | 参数 `-Version` |
| `Build-ProductPackage.ps1` | **否**（只 stamp payload） | `-Version` 或已 stamp 的 runtime token；缺则 **throw** |
| `Install-Product.ps1` | **否**（只 stamp install-tree） | `-Version` → package-meta → payload `VERSION` → stamped token；缺则 **throw** |

禁止在 Install/Build 里硬编码 `"1.3.25"` 之类默认值。

## 实施状态

已实施。首个使用该机制的发布：`1.3.16-6257d5`。
