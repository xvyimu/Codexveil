# packages/runtime

生产 watch injector + 皮肤资源。**self-contained**：不依赖 `packages/core`，因为要打进 `versions/<id>/` 独立分发。

## 目录

```
runtime/
├── assets/              # 打进 versions/<id>/assets/
│   ├── dream-skin.css   #   注入的 CSS（first-party；历史对照见 vendor 快照）
│   ├── renderer-inject.js # 注入的 JS 桥（dreamVersion / brand / art / kick 应用）
│   ├── dream-reference.jpg # 默认背景（seed）
│   └── theme.json       # 默认主题 metadata（DreamSkin catalog 格式）
├── scripts/             # 打进 versions/<id>/scripts/
│   ├── injector.mjs     # watch injector 主体（唯一守护路径）
│   ├── control-plane.mjs # 127.0.0.1 loopback（/health /kick /focus /open-healthy）
│   ├── image-metadata.mjs # 薄壳 CLI，动态 import core/image-metadata.mjs
│   ├── thumb.mjs        # 主题缩略图（Pillow → ImageMagick → System.Drawing）
│   └── wait-shell.mjs   # 冷启动 adaptive shell 等待
└── core/                # 打进 versions/<id>/core/
    └── image-metadata.mjs # JPEG/PNG/WebP 尺寸解析真实现
```

## 发布

`scripts/windows/publish-runtime.ps1` 会把整个 `packages/runtime/` copy 到：

```
%LOCALAPPDATA%\Programs\CodexDreamSkin\versions\<version>-<hash>\
├── assets\...
├── scripts\...
└── core\...
```

`current.json` 指针翻页后立即生效；旧版本 GC，只留 current + 上一版。

产品 zip 路径见 `Build-ProductPackage.ps1`：**只 stamp payload**，不写回 git tree（ADR 0003）。

## SKIN_VERSION（ADR 0003）

源文件顶部：

```js
const SKIN_VERSION_TOKEN = "__SKIN_VERSION__"; // 或 publish 后的 "x.y.z"
const SKIN_VERSION = SKIN_VERSION_TOKEN === "__" + "SKIN_VERSION__" ? "dev" : SKIN_VERSION_TOKEN;
```

| 动作 | 谁 stamp | 写 git tree？ |
|------|----------|:-------------:|
| `publish-runtime.ps1 -Version` | 源文件 + `versions/<id>/` 副本 | **是**（唯一权威写回） |
| `Build-ProductPackage.ps1` | 仅 zip payload | 否 |
| `Install-Product.ps1` | 仅安装树 | 否 |

- 所有使用点引用 `SKIN_VERSION`（injector verify · renderer `dataset.dreamVersion` · `window[STATE_KEY].version`）。
- 未 publish 的全新 clone：token 仍是占位符 → `SKIN_VERSION = "dev"`。
- **禁止**在 Install/Build 硬编码默认版本号。

当前仓内 token 可能显示上次 publish 的 `1.3.25`（有意 trade-off：git 可见性 > dev 纯净性）。

## 控制面与 kick

`control-plane.mjs` 监听 loopback（默认写入 `9336` 到 `state.controlPort` + `control.port`）。

主路径：

```text
CLI apply / 托盘 / kick-theme-now
  → POST http://127.0.0.1:<controlPort>/kick
  → watch 进程内重 apply（~45–80ms）
```

**降级（非第二产品线）**：控制面不可达时，`kick-inject` / `kick-theme-now` 可 spawn 同 runtime 的 `injector.mjs --once` 做**单次** apply。这不是 heige 旁路，也不常驻第二条守护。用户 CLI 不再暴露 `--once` / `--force-dual-open`。

日常注入唯一守护路径：**watch injector**。

## 为什么 `scripts/image-metadata.mjs` 是薄壳

历史布局：heige 把 metadata 放在 `scripts/`，DreamSkin 抽到 `core/`。publish 后两种路径都能找到；薄壳先试 `../core/` 再试 `../../core/`。

## 相关

- `docs/adr/0003-single-version-source.md`
- `docs/ARCHITECTURE.md`
- `docs/dual-open-policy.md`（入口纪律 + kick 降级）
- `docs/AUDIT-2026-07-20.md`
