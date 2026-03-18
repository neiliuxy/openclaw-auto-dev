# OpenClaw Auto Dev - 全自动开发示例项目

🤖 **AI 驱动的 GitHub Issue → PR 自动化工作流**

---

## 📋 项目概述

本项目演示如何使用 OpenClaw 实现全自动软件开发流程：

```
Issue 创建 → 自动检测 → 分支开发 → PR 提交 → 自动合并 → 状态更新
```

---

## 🔄 工作流程

### 状态流转

```
openclaw-new → openclaw-processing → openclaw-pr-created → openclaw-completed
```

### 详细流程

| 步骤 | 动作 | 执行者 | 频率 |
|------|------|--------|------|
| 1 | 扫描新 Issue | OpenClaw | 每 30 分钟 |
| 2 | 筛选 `openclaw-new` 状态 | OpenClaw | 自动 |
| 3 | 更新状态为 `openclaw-processing` | OpenClaw | 自动 |
| 4 | 创建功能分支 | OpenClaw | 自动 |
| 5 | 开发/修复代码 | OpenClaw | 自动 |
| 6 | 提交代码 & 创建 PR | OpenClaw | 自动 |
| 7 | 更新状态为 `openclaw-pr-created` | OpenClaw | 自动 |
| 8 | 等待人工审核/自动合并 | 人工/Auto Merge | - |
| 9 | 合并后更新为 `openclaw-completed` | OpenClaw | 自动 |

---

## 🏷️ Issue 状态标签

| 标签 | 含义 | 触发条件 |
|------|------|----------|
| `openclaw-new` | 新 Issue，等待处理 | Issue 创建时手动添加 |
| `openclaw-processing` | OpenClaw 正在处理 | 自动更新 |
| `openclaw-pr-created` | PR 已创建，等待审核 | PR 创建后自动更新 |
| `openclaw-completed` | 已完成合并 | PR 合并后自动更新 |
| `openclaw-error` | 处理失败 | 异常时添加 |

---

## 🛠️ 技术栈

| 组件 | 技术选型 |
|------|----------|
| **自动化框架** | OpenClaw |
| **代码生成** | opencode AI |
| **GitHub 集成** | GitHub CLI (gh) |
| **定时任务** | GitHub Actions |
| **状态管理** | GitHub Labels |

---

## 📁 项目结构

```
openclaw-auto-dev/
├── .github/workflows/
│   ├── issue-check.yml      # Issue 检查定时任务
│   └── pr-merge.yml         # PR 合并后处理
├── scripts/
│   └── process-issue.sh     # Issue 处理脚本
├── src/                     # 示例代码
├── tests/                   # 测试代码
├── docs/
│   └── setup.md             # 部署指南
├── logs/                    # 处理日志
├── .gitignore
├── HEARTBEAT.md             # OpenClaw 心跳配置
├── DESIGN.md                # 设计方案
└── README.md                # 本文件
```

---

## 🚀 快速开始

### 1. 配置 GitHub Secrets

- `GH_TOKEN` - GitHub Personal Access Token（需要 `repo` 权限）

### 2. 启用 GitHub Actions

访问：https://github.com/neiliuxy/openclaw-auto-dev/actions

### 3. 创建测试 Issue

创建 Issue 并添加标签 `openclaw-new`

### 4. 等待处理

30 分钟内 OpenClaw 会自动检测并处理

---

## 📊 监控

```bash
# 查看 Issue 状态
gh issue list --label "openclaw-new"
gh issue list --label "openclaw-processing"
gh issue list --label "openclaw-completed"

# 查看 Actions 日志
gh run list --limit 5
```

---

## 📄 许可证

MIT License

---

**详细设计文档**: [DESIGN.md](./DESIGN.md)  
**部署指南**: [docs/setup.md](./docs/setup.md)
