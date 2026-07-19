# ADR 0001 — 合并 DreamSkin 与 heige 为一条产品线

## 状态

Accepted — 2026-07-19

## 背景

本机存在两套 Codex 换肤实现，均向同一 renderer 注入 CSS，造成端口/快捷方式/样式互盖。

## 决策

1. 源码仓：`D:\orca\codex-skin`
2. 安装布局与品牌入口：继续 CodexDreamSkin / 任务栏 Codex
3. 守护与修复：以 DreamSkin watch/launcher 为准
4. 多主题：以 heige theme store + 应用内菜单为准
5. 默认 CDP：9335
6. 过渡期禁止双开 injector

## 后果

- 开发只在本仓进行
- 发布仍写入 `%LOCALAPPDATA%\Programs\CodexDreamSkin\versions\*`
- heige 独立 `apply` 仅调试，且默认拦截
