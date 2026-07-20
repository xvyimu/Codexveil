# Evidence SAMPLE（虚构，无真实用户 DOM）

以下 JSON **片段**仅说明字段形态。禁止把本机真实 title / url / 用户消息 dataAttrs 贴进仓库。

## 1. home pass（`status=ran`）

```json
{
  "schemaVersion": 1,
  "kind": "release-probe-session",
  "status": "ran",
  "reason": null,
  "generatedAt": "2026-07-21T12:00:00Z",
  "port": 9335,
  "probeScript": "scripts/windows/probe-session-dom.mjs",
  "probeExitCode": 0,
  "cdpReachable": true,
  "command": "node scripts/windows/probe-session-dom.mjs 9335",
  "summary": {
    "ok": true,
    "dreamStyle": true,
    "pass": true,
    "conversationPass": false,
    "onHome": true,
    "inConversation": false
  },
  "probe": {
    "ok": true,
    "dreamStyle": true,
    "pass": true,
    "conversationPass": false,
    "onHome": true,
    "inConversation": false
  }
}
```

勾 **home**：看 `summary.ok` / `dreamStyle` / `pass` 均为 true。  
`conversationPass=false` + `inConversation=false` 时 **不要**勾 conversation；开对话后重跑。

## 2. conversation pass（`status=ran`）

```json
{
  "schemaVersion": 1,
  "kind": "release-probe-session",
  "status": "ran",
  "reason": null,
  "generatedAt": "2026-07-21T12:05:00Z",
  "port": 9335,
  "probeExitCode": 0,
  "cdpReachable": true,
  "summary": {
    "ok": true,
    "dreamStyle": true,
    "pass": true,
    "conversationPass": true,
    "onHome": false,
    "inConversation": true
  },
  "probe": {
    "ok": true,
    "dreamStyle": true,
    "pass": true,
    "conversationPass": true,
    "onHome": false,
    "inConversation": true
  }
}
```

勾 **conversation**：`status=ran` 且 `summary.conversationPass=true`（建议 `inConversation=true`）。

## 3. skipped / no-cdp（**不算**发版完成）

```json
{
  "schemaVersion": 1,
  "kind": "release-probe-session",
  "status": "skipped",
  "reason": "no-cdp",
  "generatedAt": "2026-07-21T12:10:00Z",
  "port": 9335,
  "probeExitCode": null,
  "cdpReachable": false,
  "command": "node scripts/windows/probe-session-dom.mjs 9335",
  "summary": {
    "ok": null,
    "dreamStyle": null,
    "pass": null,
    "conversationPass": null,
    "onHome": null,
    "inConversation": null
  },
  "probe": null
}
```

注意：skip 时 **不得**写 `"pass": true`。脚本默认 exit 0 只表示脚手架/skip 留痕成功，**未跑真机不算发版完成**。

## Host 摘要行（便于 grep）

```
summary: status=ran exit=0 ok=true dreamStyle=true pass=true conversationPass=true
summary: status=skipped exit=0 ok=null dreamStyle=null pass=null conversationPass=null
```
