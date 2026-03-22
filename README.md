# OpenClaw Auto Dev - 全自动开发示例项目

🤖 **AI 驱动的 GitHub Issue → PR 自动化工作流**

---

## 📋 项目概述

本项目使用 **openclaw-pipeline skill** 实现**状态驱动的**多 Agent 开发流水线：

```
Issue 创建 → 四角色 Agent 协作 → PR 合并 → 状态更新
        ↓
  Architect（需求分析）→ Developer（代码实现）
  → Tester（测试验证）→ Reviewer（合并决策）
```

---

## 🔄 四 Agent 工作流程

```
openclaw-new
    │
    ▼
Architect ──→ SPEC.md（需求规格说明书）
    │           需求分析 + 功能拆解 + 验收标准
    │           ⚠️ 不写代码，只出文档
    ▼
Developer ──→ 代码实现
    │           读取 SPEC.md，实现全部功能点
    ▼
Tester ────→ TEST_REPORT.md（测试验证报告）
    │           逐条验证，生成报告
    ▼
Reviewer ──→ PR 合并 / 打回迭代
    │           通过 → 合并；失败 → 标记错误
    ▼
PR 合并 ──→ openclaw-completed
```

---

## 🏷️ Issue 状态标签

| 标签 | 含义 |
|------|------|
| `openclaw-new` | 新 Issue，等待处理 |
| `openclaw-architecting` | Stage 1 进行中 |
| `openclaw-developing` | Stage 2 进行中 |
| `openclaw-testing` | Stage 3 进行中 |
| `openclaw-reviewing` | Stage 4 进行中 |
| `openclaw-completed` | 已合并 |
| `openclaw-error` | 失败 |

---

## 🛠️ 技术栈

| 组件 | 技术选型 |
|------|----------|
| **Pipeline** | openclaw-pipeline skill |
| **GitHub 集成** | GitHub CLI (gh) |
| **定时任务** | OpenClaw heartbeat |
| **状态管理** | 状态文件 (.pipeline-state/) |

---

## 📁 项目结构

```
openclaw-auto-dev/
├── scripts/
│   ├── heartbeat-check.sh    # 心跳扫描
│   └── scan-issues.sh       # Issue 扫描
├── openclaw/                # 各 Issue 的 SPEC/TEST_REPORT
│   └── <num>_<slug>/
│       ├── SPEC.md
│       └── TEST_REPORT.md
├── .pipeline-state/         # Pipeline 状态文件
├── src/                    # 源代码
└── OPENCLAW.md            # 项目配置
```

---

## 🚀 快速开始

### 触发 Pipeline

```bash
pipeline-runner.sh <issue_number>
```

### 创建新 Issue

创建 Issue 并添加标签 `openclaw-new`，心跳自动检测并触发 Pipeline

---

## 📊 监控

```bash
# 查看各状态 Issue
gh issue list --label "openclaw-new"
gh issue list --label "openclaw-completed"

# 查看 Pipeline 状态
ls -la .pipeline-state/

# 查看日志
tail -f logs/pipeline-$(date '+%Y-%m-%d').log
```

---

## ⚙️ Pipeline Skill

Pipeline 逻辑在 `~/.openclaw/workspace/skills/openclaw-pipeline/`

- `pipeline-runner.sh` — 主脚本，状态驱动
- `SKILL.md` — Skill 文档
