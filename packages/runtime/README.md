# packages/runtime

生产 watch injector + 皮肤资源。**self-contained**：不依赖 `packages/core`，因为要打进 `versions/<id>/` 独立分发。

## 目录

```
runtime/
├── assets/              # 打进 versions/<id>/assets/
│   ├── dream-skin.css   #   注入的 CSS（vendor 上游 + 少量本地覆盖）
│   ├── renderer-inject.js # 注入的 JS 桥（负责 dreamVersion / kick 应用）
│   ├── dream-reference.jpg # 默认背景（seed）
│   └── theme.json       # 默认主题 metadata
├── scripts/             # 打进 versions/<id>/scripts/
│   ├── injector.mjs     # watch injector 主体 (1434 行)
│   ├── control-plane.mjs # 127.0.0.1 loopback control plane (/health /kick /focus)
│   ├── image-metadata.mjs # 薄壳 CLI，动态 import core/image-metadata.mjs
│   ├── thumb.mjs        # 主题缩略图生成 (Pillow → ImageMagick → System.Drawing)
│   └── wait-shell.mjs   # 冷启动 adaptive shell 等待
└── core/                # 打进 versions/<id>/core/
    └── image-metadata.mjs # JPEG/PNG/WebP 尺寸解析真实现（scripts/ 的薄壳导入这个）
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

## 为什么 `scripts/image-metadata.mjs` 是薄壳

历史原因：早期 heige 把图像 metadata 逻辑放在 `scripts/`，DreamSkin 把它抽到 `core/`；publish 时需要同时保留两种发布布局（`versions/<id>/core/` 和 `versions/<id>/scripts/` 都能找到）。薄壳会先试 `../core/image-metadata.mjs` 再试 `../../core/image-metadata.mjs`。

## SKIN_VERSION

`scripts/injector.mjs` 顶端有 `const SKIN_VERSION = "1.3.13"`。**publish 时** `publish-runtime.ps1 -Version` 参数决定 `versions/<id>/` 目录名；`SKIN_VERSION` 需要跟 install version 手动对齐（1.3.11 里已加了校验；发布前检查一遍）。

## 控制面

`control-plane.mjs` 监听 loopback 端口（自动挑一个空闲，写入 `stateRoot\control.port` 和 `state.controlPort`）。任何外部工具 POST `/kick` 即可让 watch 立刻重新 apply active-theme。

路径：`launcher / kick-theme-now / switch-theme-ui / CLI apply` → HTTP POST `/kick` → 命中就 45ms 完事；命中不到再 spawn 独立 `injector --once`。
