# 心跳机制详解

## 概述

心跳机制通过 cron 定时触发 `scripts/cron-heartbeat.sh`，检测新 Issue 并启动 Pipeline。

## 流程

```
cron (*/30 * * * *)
    ↓
cron-heartbeat.sh
    ↓
scan-issues.sh（扫描 openclaw-new Issue）
    ↓
发现新 Issue → pipeline-runner.sh
```

## Pipeline 状态

Pipeline 使用 `.pipeline-state/<issue>_stage` 文件记录进度：

- `0` = 未开始
- `1` = Architect 完成
- `2` = Developer 完成
- `3` = Tester 完成
- `4` = Pipeline 完成

## 崩溃恢复

任何阶段崩溃后，下一次 cron 触发时会自动从断点继续。

```bash
# 从断点继续
pipeline-runner.sh <issue_number> --continue

# 清理状态（重新开始）
rm .pipeline-state/<issue>_stage
pipeline-runner.sh <issue_number>
```
