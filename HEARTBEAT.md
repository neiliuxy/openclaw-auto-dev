# OpenClaw Auto Dev 心跳配置

> **⚠️ 已升级为状态驱动的 Pipeline（openclaw-pipeline skill）**

## 任务说明

- **频率**: 每 30 分钟检查一次
- **并发**: 同时只处理一个 Issue
- **流程**: 状态驱动的四阶段 Pipeline

## Pipeline 流程

```
Issue → Architect → Developer → Tester → Reviewer
         (状态文件记录进度，crash-safe)
```

## 执行方式

Pipeline 由 `pipeline-runner.sh` 驱动：

```bash
# 触发 pipeline 处理 Issue
pipeline-runner.sh <issue_number>
```

**注意**：Pipeline 由 heartbeat 通过 sessions_spawn 触发，不在本仓库维护。

## Issue 状态标签

| 状态标签 | 含义 | 触发时机 |
|----------|------|----------|
| `openclaw-new` | 新 Issue，等待处理 | 用户创建 |
| `openclaw-architecting` | Architect 正在分析 | Stage 1 启动 |
| `openclaw-developing` | Developer 正在开发 | Stage 2 启动 |
| `openclaw-testing` | Tester 正在验证 | Stage 3 启动 |
| `openclaw-reviewing` | Reviewer 决策中 | Stage 4 启动 |
| `openclaw-pr-created` | PR 已创建 | Reviewer 创建 PR |
| `openclaw-completed` | 已完成合并 | PR 合并 |
| `openclaw-error` | 异常/超迭代上限 | 失败 |

## 产物文件

```
openclaw-auto-dev/
├── SPEC.md              # Architect → Developer 共享
├── TEST_REPORT.md       # Tester → Reviewer 共享
├── .pipeline-state/      # Pipeline 状态文件
│   └── <issue>_stage    # 当前阶段 (1-4)
└── openclaw/
    └── <num>_<slug>/
        ├── SPEC.md
        └── TEST_REPORT.md
```
