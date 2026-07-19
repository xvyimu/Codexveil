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
  替换成 `-Version` 值，**同时写入**：
  1. repo 源文件（`packages/runtime/{scripts/injector.mjs,assets/renderer-inject.js}`）
  2. 刚拷贝的 `versions/<id>/` 副本
- 未 publish 直接 `node` 跑 → token 仍是占位符 → `SKIN_VERSION = "dev"`。

## 结果

- 发版只改一个地方（`-Version` 参数）；5 处使用点自动一致。
- `verify` 的 `version === expectedVersion` 永远成立（同一替换值）。
- git 能看到当前版本（repo 源文件被 stamp），符合"版本对源码可见"的要求。

## 权衡 / 已知代价

- 选择"publish 一并写回 repo 源文件"（而非只改 versions/ 拷贝），因此**发版后
  repo 里不再是纯占位符**，而是上次发布的版本号。代价：从已发布过的
  checkout 直接 `node` 跑会显示上次版本而非 `"dev"`；只有全新 clone 显示 `"dev"`。
  这是有意接受的 trade-off（git 可见性 > dev 纯净性）。
- 依赖字面量格式 `const SKIN_VERSION_TOKEN = "..."` 稳定；若重命名该常量需同步改
  publish 的正则。

## 实施状态

已实施。首个使用该机制的发布：`1.3.16-6257d5`。
