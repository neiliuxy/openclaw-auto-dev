# AGENTS.md - OpenClaw Auto Dev

## 概述

本项目使用 **openclaw-pipeline skill** 实现状态驱动的多 Agent 开发流水线。

## Pipeline 架构

```
Issue → Architect → Developer → Tester → Reviewer → PR Merge
         (状态文件 .pipeline-state/ 记录进度)
```

## 核心机制

1. **状态驱动** — 每个阶段完成后写状态文件，崩溃可恢复
2. **crash-safe** — 任何阶段崩溃，下次 cron 触发时从断点继续
3. **跨项目复用** — Pipeline 逻辑在 `openclaw-pipeline` skill 中
4. **独立通知** — 每阶段完成后立即通知

## Pipeline Runner

主脚本：`~/.openclaw/workspace/skills/openclaw-pipeline/pipeline-runner.sh`

```bash
# 手动触发
pipeline-runner.sh <issue_number>

# 从断点继续
pipeline-runner.sh <issue_number> --continue
```

## 状态文件

```
.pipeline-state/<issue>_stage
```

内容为单个数字：
- `0` = 未开始
- `1` = Architect 完成
- `2` = Developer 完成
- `3` = Tester 完成
- `4` = Reviewer 完成

## Issue 标签

| 标签 | 含义 |
|------|------|
| `openclaw-new` | 新 Issue |
| `openclaw-architecting` | Stage 1 |
| `openclaw-developing` | Stage 2 |
| `openclaw-testing` | Stage 3 |
| `openclaw-reviewing` | Stage 4 |
| `openclaw-completed` | 已合并 |
| `openclaw-error` | 失败 |
