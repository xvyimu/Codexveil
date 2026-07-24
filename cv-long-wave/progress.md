# Codexveil · cv-long-wave progress

**总控：** `cv-coord` · `xvyimu/cv-coord`  
**红线：** 单 injector · 禁 asar · 禁 vendor · 禁 publish · 禁 push **main** · feature push OK  

SSOT：[`WEEK-BACKLOG.md`](./WEEK-BACKLOG.md) · [`INTEGRATE.md`](./INTEGRATE.md) **READY_FOR_HUMAN_GATE**

---

## 0. 状态（7m · W1–12 齐 · 整理 INTEGRATE）

| 层 | 状态 |
|----|------|
| W1–W12 | **全部 ACCEPT**（W3 SKIP）· origin tips 见 INTEGRATE §0 |
| W13 | **READY_FOR_HUMAN_GATE** · 可复制 merge 序 · **不**自动合 main |
| live 实现 child | **0** |
| coord dirty | 本巡检整理后 commit |
| findings fix wt | **无** |

### 门闩

| 命令 | exit |
|------|------|
| `npm test` | **0**（W12） |
| doctor idle | **0** · fresh · `1.3.25-da2adc` |
| deps / cdp / catalog / themes | **0** |

### 总控姿态（勿停）

- **不**再默认开 W* 实现 wt（队列实现项已尽）  
- **保持** 7m 巡检：list/ps · dirty commit · 等人 gate  
- 人授权后才：integrate 支 / PR / publish  

---

## 1. orca 名表

| name | status |
|------|--------|
| main | `D:/orca/Codexveil` @ `ebc3568` ≡ origin/main |
| cv-coord | 总控 · in-review 等人 |

**磁盘残渣（非 orca/git wt）：** `cv-long-verify` / `cv-scout-health` / `cv-themes-contracts` 碎片目录 · `ship-d1-cv` 空 · 见 INTEGRATE §4 · 可选人清  

---

## 2. 本巡检

1. list：无 DONE child 可 rm  
2. 确认 W1–12 origin tips  
3. 整理 INTEGRATE → 人 gate 就绪（文件清单 + merge 脚本 + 冲突面）  
4. 更新 backlog 状态板  
5. **未** push main · **未** publish/asar  

---

## 3. 等人

1. 按 INTEGRATE §2 合入 docs → main  
2. publish **另授**  
3. 可选 live smoke / #25  
