# ❤️ 心跳机制 - OpenClaw Auto Dev

## 概述

本系统采用**双心跳源**驱动多 Agent 四角色流程。

---

## 心跳架构

```
┌──────────────────────────────────────┐
│  触发源 1: OpenClaw HEARTBEAT       │
│  → scripts/heartbeat-check.sh        │
└──────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────┐
│  触发源 2: crontab                   │
│  → scripts/cron-heartbeat.sh          │
└──────────────────────────────────────┘
                    ↓
         ┌──────────────────────┐
         │  multi-agent-run.sh    │
         │  四 Agent 协作流程     │
         └──────────────────────┘
                    ↓
         ┌──────────────────────┐
         │  GitHub (PR 合并)     │
         │  → pr-merge.yml (GHA)│
         └──────────────────────┘
                    ↓
         ┌──────────────────────┐
         │  Issue 标签更新       │
         │  → openclaw-completed│
         └──────────────────────┘
```

---

## 文件结构

```
openclaw-auto-dev/
├── HEARTBEAT.md                    # OpenClaw 心跳配置
├── scripts/
│   ├── heartbeat-check.sh          # OpenClaw HEARTBEAT 入口
│   ├── cron-heartbeat.sh           # crontab 入口
│   ├── multi-agent-run.sh          # 四 Agent 核心流程
│   └── scan-issues.sh              # Issue 扫描
├── logs/
│   ├── cron-heartbeat.log          # cron 心跳日志
│   └── multi-agent-YYYY-MM-DD.log # 多 Agent 流程日志
├── scan-result.json                 # 最新扫描结果
└── .github/workflows/
    ├── issue-check.yml             # GHA 定时扫描（辅助）
    └── pr-merge.yml               # PR 合并后自动更新标签
```

---

## 触发流程

### OpenClaw HEARTBEAT
```
OpenClaw 读取 HEARTBEAT.md
  → heartbeat-check.sh
  → scan-issues.sh
  → 发现新 Issue → multi-agent-run.sh
```

### crontab
```
*/30 * * * *
  → cron-heartbeat.sh
  → scan-issues.sh
  → 发现新 Issue → multi-agent-run.sh
```

---

## Issue 状态流转

```
openclaw-new
    ↓
openclaw-architecting
    ↓
openclaw-planning
    ↓
openclaw-developing
    ↓
openclaw-testing
    ↓
openclaw-reviewing
    ↓
PR 合并 (通过 pr-merge.yml)
    ↓
openclaw-completed
```

---

## pr-merge.yml 自动更新

PR 合并后 GHA 自动执行：
```bash
issue_number=$(echo "$branch_name" | grep -oE '[0-9]+' | head -1)
gh issue edit "$ISSUE_NUMBER" --remove-label "openclaw-processing" || true
gh issue edit "$ISSUE_NUMBER" --remove-label "openclaw-pr-created" || true
gh issue edit "$ISSUE_NUMBER" --add-label "openclaw-completed"
```

**注意**：使用 `${{ github.token }}`（GHA 内置），不使用 `GH_TOKEN` secret。

---

## 日志查看

```bash
# 多 Agent 流程日志
tail -f logs/multi-agent-$(date '+%Y-%m-%d').log

# cron 心跳日志
tail -f logs/cron-heartbeat.log

# GitHub Actions
gh run list --limit 5
```

---

## 故障排查

| 问题 | 检查 |
|------|------|
| 心跳未触发 | `crontab -l` 确认 cron 条目 |
| Issue 扫描失败 | `tail logs/cron-heartbeat.log` |
| pr-merge 标签更新失败 | 查看 GHA run 日志 |
| multi-agent 失败 | `tail logs/multi-agent-*.log` |

---

**最后更新**: 2026-03-21
