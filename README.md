# OpenClaw Auto Dev - 全自动开发示例项目

🤖 **AI 驱动的 GitHub Issue → PR 自动化工作流**

---

## 📋 项目概述

本项目演示如何使用 OpenClaw 实现**多 Agent 协作**的全自动软件开发流程：

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
    │           通过 → 合并；失败 → 打回 Developer
    ▼
PR 合并 ──→ openclaw-completed
```

### 详细流程

| 步骤 | 动作 | 标签 | 执行者 |
|------|------|------|--------|
| 1 | 扫描新 Issue | — | cron 心跳 |
| 2 | Architect 分析需求，输出 SPEC.md | `openclaw-architecting` → `openclaw-planning` | multi-agent-run.sh |
| 3 | Developer 读取 SPEC.md，实现代码 | `openclaw-planning` → `openclaw-developing` | multi-agent-run.sh |
| 4 | Tester 验证实现，输出 TEST_REPORT.md | `openclaw-developing` → `openclaw-testing` | multi-agent-run.sh |
| 5 | Reviewer 决策：合并或打回 | `openclaw-testing` → `openclaw-reviewing` | multi-agent-run.sh |
| 6 | PR 合并，状态更新 | `openclaw-completed` | pr-merge.yml (GHA) |

---

## 🏷️ Issue 状态标签

| 标签 | 含义 | 触发时机 |
|------|------|----------|
| `openclaw-new` | 新 Issue，等待处理 | 用户创建 |
| `openclaw-architecting` | Architect 正在分析 | Architect 启动 |
| `openclaw-planning` | 方案设计中 | Architect 产出 SPEC |
| `openclaw-developing` | Developer 正在开发 | Developer 启动 |
| `openclaw-testing` | Tester 正在验证 | Tester 启动 |
| `openclaw-reviewing` | Reviewer 决策中 | Reviewer 启动 |
| `openclaw-pr-created` | PR 已创建 | Reviewer 通过 |
| `openclaw-completed` | 已完成合并 | PR 合并后（pr-merge.yml） |
| `openclaw-error` | 异常/超迭代上限 | Reviewer 决策 |

---

## 🛠️ 技术栈

| 组件 | 技术选型 |
|------|----------|
| **自动化框架** | OpenClaw |
| **代码生成** | LLM (qwen3.5-plus) / opencode |
| **GitHub 集成** | GitHub CLI (gh) |
| **定时任务** | crontab + GitHub Actions |
| **状态管理** | GitHub Labels + pr-merge.yml |

---

## 📁 项目结构

```
openclaw-auto-dev/
├── .github/workflows/
│   ├── issue-check.yml      # GitHub Actions 定时扫描
│   └── pr-merge.yml         # PR 合并后自动更新标签
├── scripts/
│   ├── multi-agent-run.sh   # 四 Agent 主流程（核心）
│   ├── heartbeat-check.sh    # OpenClaw 心跳专用
│   ├── cron-heartbeat.sh    # crontab 专用
│   └── scan-issues.sh       # Issue 扫描
├── src/                     # 示例代码
├── SPEC.md                  # 当前 Issue 的需求规格
├── TEST_REPORT.md           # 当前 Issue 的测试报告
├── agents/                  # 各 Agent 产物目录
├── HEARTBEAT.md             # OpenClaw 心跳配置
├── HEARTBEAT-MECHANISM.md   # 心跳机制详解
├── MULTI_AGENT_DESIGN.md    # 多 Agent 设计文档
└── README.md               # 本文件
```

---

## 🚀 快速开始

### 1. 配置 GitHub Secrets

**无需配置 GH_TOKEN secret**（workflow 使用 `github.token` 内置变量）。

### 2. 触发方式

**方式 A：自动（推荐）**
- crontab 每 30 分钟自动触发

**方式 B：手动**
```bash
cd openclaw-auto-dev
./scripts/multi-agent-run.sh <issue_number>
```

### 3. 创建新 Issue

创建 Issue 并添加标签 `openclaw-new`，系统自动处理

---

## 📊 监控

```bash
# 查看各状态 Issue
gh issue list --label "openclaw-new"
gh issue list --label "openclaw-completed"

# 查看 GitHub Actions 运行
gh run list --limit 5

# 查看心跳日志
tail -f logs/cron-heartbeat.log
```

---

## ⚠️ 重要设计决策

1. **Token 认证**：workflow 用 `${{ github.token }}`，不用 `GH_TOKEN` secret
2. **心跳单一源**：`heartbeat-check.sh` 和 `cron-heartbeat.sh` 均调用 `multi-agent-run.sh`
3. **Developer 基于 SPEC.md 开发**：不用关键词硬编码模板

---

**详细设计文档**: [MULTI_AGENT_DESIGN.md](./MULTI_AGENT_DESIGN.md)  
**心跳配置**: [HEARTBEAT.md](./HEARTBEAT.md)  
**部署指南**: [docs/setup.md](./docs/setup.md)
