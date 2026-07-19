# 双开策略（过渡期）

## 规则

1. **日常入口唯一**：CodexDreamSkin 启动器（任务栏 Codex）
2. **injector 唯一**：DreamSkin-style watch 进程
3. **heige apply**：检测到 DreamSkin active-theme / 存活 injector 时默认拒绝
4. **强制调试**：仅 `--force-dual-open`（会互盖，不推荐）

## 检测

heige / 统一 CLI 的 `doctor` 输出：

- `dreamSkin.summary`
- `dualOpenRisk`
- `dailyEntry`

## 解除调试拦截

1. 暂停 DreamSkin（托盘暂停或写 `paused` 文件）  
2. 或 `--force-dual-open`  
3. 调试完恢复 DreamSkin 入口
