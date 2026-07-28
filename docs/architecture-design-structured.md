# Codexveil · 结构化架构设计（v2）

| 项 | 值 |
|----|-----|
| 产品 | Windows Codex Desktop **CDP 换肤**侧车 |
| GitHub | [xvyimu/Codexveil](https://github.com/xvyimu/Codexveil) |
| 路径 | `D:\projects\Codexveil` · 安装态 `%LOCALAPPDATA%\Programs\CodexDreamSkin` |
| 文档版本 | **v2 · 2026-07-29** |
| **栈权威** | **[`PROJECT.md`](./PROJECT.md) §1.5** |
| 许可 | MIT · 独立产品线 ADR-0006 |

> 方法：[arc42](https://docs.arc42.org/home/) · [C4](https://c4model.com/) · 仓内 [`ARCHITECTURE.md`](./ARCHITECTURE.md) 路径级细节  

---

## 0. 五问

| # | 答 |
|---|----|
| 是什么？ | 不改 asar 的 Codex 皮肤注入器 + 主题目录 |
| 为谁？ | 本机 Windows Codex 用户 |
| 不做？ | 改安装包 · macOS 主路径 · 第二产品壳 · 多 injector |
| 验收？ | `npm test` · doctor/smoke · themes-gate（含 official audit） |
| 协作？ | 公有 Issue/PR · 仅 origin |

---

## 1. 背景与目标

官方 Codex Desktop 已是 Electron 宿主；换肤用 **CDP :9335** + **单 watch injector** + 控制面 **:9336 /kick**。

| 质量属性 | 表述 | 验证 |
|----------|------|------|
| 正确性 | 皮肤与 active-theme 一致 | smoke/目视 |
| 性能体感 | kick 热更 &lt;100ms 量级 | 人工/脚本 |
| 单实例 | 仅一条 watch | doctor/state |
| 可回退 | versions GC current+上一版 | publish 纪律 |
| 供应链 | audit 走官方 registry | themes-gate |

---

## 2. 总体架构（C4）

### Context

```text
 [用户] → 开始菜单 Codex / 托盘 / F6 / CLI
              │
              ▼
        Codexveil launcher+injector
              │ CDP
              ▼
        官方 Codex Desktop（只读 asar）
```

### Container

```text
 apps/launcher + native FastLaunch
        │
 packages/core (discover/cdp/state/cli)
 packages/runtime (watch injector + assets)
 packages/themes + themes/<id>
 packages/core-win (pwsh)
        │
 安装态 versions/<id> + current.json + active-theme
```

端口：**CDP 9335** · **control 9336 loopback**（详见 ARCHITECTURE.md）。

---

## 3. 选型理由

| 选 | 因 | 不选 |
|----|----|------|
| CDP 侧车 | 不改 asar | 补丁官方包 |
| Node ESM+pwsh | 贴 Windows 安装态 | macOS 主线 |
| 单 injector | 防双注入 | 多守护 |
| 官方 npm audit | 镜像无 bulk API | 永久 DEFER |
| 独立产品线 | 身份清 | vendor/外仓绑 |

---

## 4. 核心模块与接口

| 模块 | 要点 |
|------|------|
| injector watch | 注入 CSS/JS；单实例 |
| /kick | 热应用主题 |
| themes catalog | F6/托盘/CLI |
| CLI | apply/doctor/verify |
| publish | stamp 包内；git 源占位符 |
| contracts+CI | themes-gate + audit |

---

## 5. 资产复用

DreamSkin/heige 主题、安装态路径、contracts、依赖双平面（ADR-0004）——在边界内演进。

---

## 6. 信任边界与风险

| 边界 | 风险 | 缓解 |
|------|------|------|
| injector→Codex | 注入面过宽 | 最小 CSS/JS；不改 asar |
| control port | 本机恶意 kick | loopback；单实例 |
| publish | 错版覆盖 | current.json+GC |
| registry | 镜像假绿 | 强制 npmjs audit |
| 多开 | 双注入 | 单 watch 守卫 |

---

## 7. 14 天计划

| 日 | 主题 | DoD |
|----|------|-----|
| 1–2 | 文档 | 与 ARCHITECTURE 端口一致 |
| 3–4 | audit CI | gate 观察 |
| 5–7 | injector | doctor 绿 |
| 8–9 | 主题质量 | npm test |
| 10–11 | publish dry | 无 true-publish 除非人 |
| 12–14 | 痛点+收口 | PAIN-POINTS 项 |

---

## 8. 验收命令（L4）

| 命令 | 用途 |
|------|------|
| `npm test` / unit+contracts | 工程门 |
| `npm run audit:deps` | 官方 registry audit |
| doctor / smoke（按改动） | 安装态 |
| themes-gate CI | PR/push |

---

## 9. 相关文档

`PROJECT.md` · `ARCHITECTURE.md` · `PAIN-POINTS.md` · `ops/cv-audit-registry-evidence-2026-07-28.md` · ADR 0003–0006

---

*v2 · 2026-07-29*
