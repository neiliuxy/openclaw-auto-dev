# SPEC.md — openclaw-auto-dev 项目规格说明书

> **项目**: neiliuxy/openclaw-auto-dev
> **类型**: AI 驱动的 GitHub Issue → PR 全自动开发流水线
> **当前版本**: v2.0
> **更新日期**: 2026-04-28
> **分支**: `architect/spec-20260428` (from `auto-dev`)
> **Pipeline 状态**: Stage 0 — Architect 分析阶段

---

## 1. 项目概述

### 1.1 项目目标

**openclaw-auto-dev** 是一个由 OpenClaw 多 Agent 编排驱动的全自动软件开发流水线，实现：

```
GitHub Issue 创建（label: openclaw-new）
    → 四角色 Agent 协作（Architect → Developer → Tester → Reviewer）
    → Pull Request 自动创建与合并
    → 状态全生命周期追踪
```

### 1.2 核心价值

| 特性 | 说明 |
|------|------|
| **状态驱动** | 流水线状态存储在 `.pipeline-state/` 目录下的 JSON 文件中，支持断点续跑 |
| **四角色协作** | Architect（需求分析）、Developer（代码实现）、Tester（测试验证）、Reviewer（合并决策） |
| **幂等性设计** | 每个阶段可安全重复执行，已完成的阶段自动跳过 |
| **跨项目复用** | Pipeline Runner 支持 `--project` 参数指定项目根目录 |
| **飞书通知** | 每阶段开始/完成/失败均通过 `notify-feishu.sh` 发送通知 |
| **并发控制** | 单线程处理（同时只处理一个 Issue），避免分支冲突 |

### 1.3 技术栈

| 组件 | 技术选型 |
|------|----------|
| **Agent 编排** | OpenClaw subagent/skill 机制 |
| **状态管理** | `.pipeline-state/<issue>_stage` JSON 文件 |
| **GitHub 集成** | GitHub CLI (`gh`) |
| **流水线脚本** | Bash (`scripts/pipeline-runner.sh`) |
| **状态库** | C++ (`src/pipeline_state.cpp/h`) |
| **构建系统** | CMake + Make |
| **定时触发** | OpenClaw heartbeat (`heartbeat-check.sh`) |
| **CI/CD** | GitHub Actions (`.github/workflows/ci.yml`) |
| **通知** | 飞书 Webhook (`notify-feishu.sh`) |

---

## 2. 流水线架构

### 2.1 四阶段流程

```
┌─────────────────────────────────────────────────────────────────┐
│ Issue 创建，添加标签 openclaw-new                                │
└────────────────────────┬────────────────────────────────────────┘
                         │ heartbeat-check.sh 扫描到新 Issue
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ [Stage 0] openclaw-new ──→ openclaw-architecting                │
│  Agent: Architect                                                 │
│  输出: openclaw/<num>_<slug>/SPEC.md                            │
│  状态文件: .pipeline-state/<num>_stage → stage=1, status=completed│
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ [Stage 1] openclaw-architecting ──→ openclaw-developing         │
│  Agent: Developer                                                 │
│  输出: 代码提交到分支 openclaw/issue-<num>                       │
│  状态文件: .pipeline-state/<num>_stage → stage=2, status=completed│
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ [Stage 2] openclaw-developing ──→ openclaw-testing               │
│  Agent: Tester                                                    │
│  输出: openclaw/<num>_<slug>/TEST_REPORT.md                     │
│  状态文件: .pipeline-state/<num>_stage → stage=3, status=completed│
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ [Stage 3] openclaw-testing ──→ openclaw-reviewing                │
│  Agent: Reviewer                                                  │
│  输出: PR 创建 + Squash Merge 到 main/auto-dev                   │
│  状态文件: .pipeline-state/<num>_stage → stage=4, status=completed│
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ [Done] PR 合并完成，添加标签 openclaw-completed                  │
│  清理 .pipeline-state/<num>_stage 文件                          │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 内部 Stage 值映射

| Stage 值 | Agent | GitHub Label | 输出产物 |
|----------|-------|-------------|---------|
| 0 | Architect | `openclaw-architecting` | `openclaw/<num>_*/SPEC.md` |
| 1 | Developer | `openclaw-developing` | 代码提交到 `openclaw/issue-<num>` |
| 2 | Tester | `openclaw-testing` | `openclaw/<num>_*/TEST_REPORT.md` |
| 3 | Reviewer | `openclaw-reviewing` | PR 合并到 `main` 或 `auto-dev` |
| 4 | — | `openclaw-completed` | 流水线完成，清理状态文件 |

> **注意**: `pipeline_state.h` 中定义的 `PipelineStage` 枚举值比 GitHub Labels 少 1（即 `ArchitectDone = 1` 对应 Stage 0 完成后），因为 0 表示"未开始"。

### 2.3 状态文件格式

**文件路径**: `.pipeline-state/<issue_number>_stage`

**JSON 格式**:
```json
{
  "pipeline": "auto-dev",
  "repo": "neiliuxy/openclaw-auto-dev",
  "stage": 2,
  "stage_name": "developer",
  "status": "completed",
  "started_at": "2026-04-28T21:45:00+0800",
  "stage_started_at": "2026-04-28T21:45:00+0800",
  "stage_completed_at": "2026-04-28T21:50:00+0800",
  "completed_at": "2026-04-28T21:50:00+0800",
  "issue_number": 102,
  "error": null
}
```

**兼容性格式**: 支持旧版纯整数格式（如 `2`），自动检测 `{` 第一个字符。

---

## 3. 核心模块详解

### 3.1 `scripts/pipeline-runner.sh` — 流水线编排脚本

**入口**: `pipeline-runner.sh <issue_number> [--stage N] [--continue] [--project DIR]`

**参数说明**:

| 参数 | 说明 |
|------|------|
| `issue_number` | 要处理的 Issue 编号（必需） |
| `--stage N` | 从指定阶段开始（N=0~3） |
| `--continue` | 从上次中断的阶段继续 |
| `--project DIR` | 指定项目根目录（跨项目复用） |

**主要函数**:

| 函数 | 功能 |
|------|------|
| `run_architect()` | Stage 0：分析 Issue，生成 SPEC.md |
| `run_developer()` | Stage 1：读取 SPEC.md，实现代码 |
| `run_tester()` | Stage 2：验证实现，生成 TEST_REPORT.md |
| `run_reviewer()` | Stage 3：创建 PR，合并到目标分支 |
| `is_stage_completed()` | 幂等性检查（阶段已完成则跳过） |
| `notify_stage()` | 发送飞书通知 |
| `write_stage_json()` | 写入增强状态文件（含时间戳） |

**关键设计（F 系列）**:

| 设计点 | 说明 |
|--------|------|
| F01 | 支持 `--stage N` 和 `--continue` 灵活控制 |
| F02 | 阶段通知（started/completed/failed 三种状态） |
| F03 | 增强状态文件（stage_name, stage_started_at, stage_completed_at） |
| F04 | 幂等性设计（已完成阶段自动跳过） |
| F05 | 跨项目复用（`--project DIR` 参数） |

### 3.2 `src/pipeline_state.cpp/h` — 状态读写库

**功能**: C++ 版本的流水线状态读写工具，供测试二进制文件使用。

**主要函数**:

| 函数 | 说明 |
|------|------|
| `read_stage(issue_number, state_dir)` | 读取当前 stage 值，返回 -1 表示文件不存在 |
| `write_stage(issue_number, stage, state_dir)` | 写入纯整数格式（旧版兼容） |
| `write_stage_with_error(issue_number, stage, error, state_dir)` | 写入 JSON 格式状态文件 |
| `read_state(issue_number, state_dir)` | 读取完整 PipelineState 结构体 |
| `stage_to_description(stage)` | stage 值转字符串描述 |

### 3.3 `scripts/heartbeat-check.sh` — 心跳扫描

**功能**: OpenClaw heartbeat 触发后，扫描 GitHub 是否有待处理的 Issue。

**逻辑**:
1. 检查当前是否有 Issue 正在处理中（通过 `.pipeline-state/*_stage` 文件判断）
2. 如果有，跳过（单线程控制）
3. 如果无，扫描带有 `openclaw-new` 标签的 Issue
4. 取第一个，调用 `pipeline-runner.sh` 处理

### 3.4 `scripts/notify-feishu.sh` — 飞书通知

**触发时机**: 每个阶段开始（started）、完成（completed）、失败（failed）时调用。

**调用方式**: 通过环境变量 `ISSUE_NUMBER`, `PIPELINE_PROJECT_ROOT`, `TRIGGER` 传递上下文。

### 3.5 `scripts/cleanup-branches.sh` — 分支清理

**功能**: 合并后的 `openclaw/issue-*` 分支需要定期清理。

**用法**: `cleanup-branches.sh [--dry-run]`

**特性**: `--dry-run` 预览模式，安全可控。

---

## 4. GitHub Labels 体系

| Label | 用途 | 颜色 |
|-------|------|------|
| `openclaw-new` | 新 Issue，等待处理 | #0E8A16 |
| `openclaw-architecting` | Architect 阶段进行中 | #FBCA04 |
| `openclaw-developing` | Developer 阶段进行中 | #FBCA04 |
| `openclaw-testing` | Tester 阶段进行中 | #5319E7 |
| `openclaw-reviewing` | Reviewer 阶段进行中 | #B60205 |
| `openclaw-completed` | 已合并 | #0E8A16 |
| `openclaw-error` | 处理失败 | #D93F0B |
| `openclaw-processing` | 正在处理（通用） | #1E8A16 |

---

## 5. 分支策略

| 分支 | 用途 | 保护状态 |
|------|------|----------|
| `main` | 生产代码 | ✅ 受保护（推荐） |
| `auto-dev` | 主动开发分支（当前默认合并目标） | ✅ 受保护（推荐） |
| `develop` | 已废弃，请使用 `auto-dev` | 不受保护 |
| `openclaw/issue-<num>` | 各 Issue 对应功能分支 | PR 合并后清理 |

**说明**: `auto-dev` 是当前活跃开发分支，`pipeline-runner.sh` 默认合并目标为 `DEFAULT_BRANCH`（从 `OPENCLAW.md` 读取，默认为 `master`）。建议统一使用 `auto-dev` 作为默认分支。

---

## 6. 项目结构

```
openclaw-auto-dev/
├── .github/workflows/ci.yml      # CI: cmake + make + ctest
├── scripts/
│   ├── pipeline-runner.sh          # 流水线主脚本
│   ├── heartbeat-check.sh          # 心跳扫描脚本
│   ├── scan-issues.sh              # GitHub Issue 扫描工具
│   ├── notify-feishu.sh            # 飞书通知脚本
│   ├── cleanup-branches.sh         # 分支清理脚本
│   ├── cron-heartbeat.sh           # cron 心跳入口
│   ├── cron-check.sh               # cron 定时检查
│   ├── update-status.sh            # 状态更新工具
│   ├── check-conflicts.sh          # 分支冲突检查
│   └── validate-changes.sh         # 变更验证脚本
├── src/
│   ├── CMakeLists.txt              # C++ 构建配置
│   ├── pipeline_state.cpp/h         # 状态文件读写库
│   ├── pipeline_97_test.cpp         # 各 Issue 的测试文件
│   ├── pipeline_99_test.cpp
│   ├── pipeline_102_test.cpp
│   ├── pipeline_104_test.cpp
│   ├── pipeline_83_test.cpp
│   ├── spawn_order_test.cpp
│   ├── ini_parser.cpp/h
│   ├── string_utils.cpp/h
│   ├── file_finder.cpp
│   ├── min_stack.cpp
│   ├── binary_tree.cpp
│   ├── level_order.cpp
│   ├── matrix.cpp/h
│   └── ... (更多算法/工具源文件)
├── tests/                           # C++ 测试（CMake 测试目标）
├── openclaw/                        # 各 Issue 的工件目录
│   ├── <num>_<slug>/
│   │   ├── SPEC.md                  # Architect 输出
│   │   └── TEST_REPORT.md           # Tester 输出
├── .pipeline-state/                 # 流水线状态文件目录
│   ├── current_stage                # 全局流水线状态（0=空闲）
│   └── <issue>_stage                # 各 Issue 的状态文件
├── docs/
│   ├── BRANCH_STRATEGY.md           # 分支策略文档
│   └── setup.md                     # 部署指南
├── agents/                          # ⚠️ 已废弃，请勿使用
│   └── README.deprecated.md
├── HEARTBEAT.md                     # OpenClaw 心跳配置
├── HEARTBEAT-MECHANISM.md          # 心跳机制说明
├── OPENCLAW.md                     # OpenClaw 项目配置
├── project.yaml                    # LLM + 构建配置
├── CMakeLists.txt                  # 顶层构建配置
├── ARCHITECT.md                    # 架构文档（详细版）
├── DESIGN.md                       # 旧版设计文档（已归档）
└── README.md                       # 项目概述文档
```

---

## 7. 当前系统状态（2026-04-28）

### 7.1 健康状态

| 组件 | 状态 | 说明 |
|------|------|------|
| Pipeline Runner | ✅ 正常 | 支持 F01-F05 所有特性 |
| 状态文件 I/O | ✅ 正常 | JSON 格式 + 旧格式兼容 |
| CMake 构建 | ✅ 正常 | 所有源文件编译通过 |
| CI/CD | ✅ 正常 | `.github/workflows/ci.yml` 已配置 |
| 心跳扫描 | ✅ 正常 | `heartbeat-check.sh` 功能完整 |
| 分支清理 | ✅ 正常 | `cleanup-branches.sh` 可用 |
| 飞书通知 | ✅ 正常 | `notify-feishu.sh` 已实现 |
| 幂等性 | ✅ 正常 | 已完成阶段自动跳过 |
| Issue 扫描 | ✅ 正常 | 0 个 openclaw-new Issue，流水线空闲 |

### 7.2 最近完成/活跃的 Issues

| Issue | 状态 | 说明 |
|-------|------|------|
| #152 | 已合并 | test coverage enhancement |
| #112 | 已合并 | Architect 任务 |
| #104 | 已合并 | pipeline 全流程自动触发验证 |
| #102 | 已合并 | pipeline 方案验证 |
| #99 | 已合并 | pipeline 修复/增强 |
| #97 | 已合并 | pipeline 测试 |
| #64 | 已合并 | 二叉树遍历 |
| #73 | 已合并 | min_stack CMake 集成 |

### 7.3 已知问题

| # | 问题 | 严重度 | 状态 |
|---|------|--------|------|
| A | `develop` 分支仍存在，与 `auto-dev` 重复 | Medium | 待处理 |
| B | `auto-dev` 分支保护未通过 API 验证 | Low | 待确认 |
| C | `agents/README.md` 未删除（已被 `agents/README.deprecated.md` 替代） | Low | 待清理 |

---

## 8. 已实现的功能里程碑

| 日期 | 版本 | 主要变化 |
|------|------|----------|
| 2026-03-17 | v1.0 | 项目初始化，ARCHITECT.md / DESIGN.md 创建 |
| 2026-03-22 | v1.x | Pipeline Runner F01-F05 实现（跨项目、幂等性、阶段通知） |
| 2026-03-31 | v2.0 | 多 Issue 并行处理框架；`ARCHITECT.md` 重大更新 |
| 2026-04-09 | v2.x | `cleanup-branches.sh` 添加 |
| 2026-04-12 | v2.x | `.github/workflows/ci.yml` 添加 |
| 2026-04-22 | v2.x | `pipeline_102_test.cpp` 等综合测试文件添加 |
| 2026-04-26 | v2.x | 每周流水线健康检查，Issue A/B/C 识别 |
| 2026-04-28 | v2.x | 每周流水线健康检查 SPEC 更新（当前版本） |

---

## 9. 验收标准

| # | 标准 | 状态 |
|---|------|------|
| AC1 | `scripts/pipeline-runner.sh` 支持 `--stage N` 和 `--continue` | ✅ |
| AC2 | 状态文件使用 JSON 格式，支持旧格式兼容 | ✅ |
| AC3 | 每个阶段完成后发送飞书通知（started/completed/failed） | ✅ |
| AC4 | 已完成阶段可幂等重复执行（不重复工作） | ✅ |
| AC5 | `heartbeat-check.sh` 单线程控制（同时只处理一个 Issue） | ✅ |
| AC6 | `cleanup-branches.sh` 存在并可执行 | ✅ |
| AC7 | `.github/workflows/ci.yml` 配置 cmake + make + ctest | ✅ |
| AC8 | `docs/BRANCH_STRATEGY.md` 存在且准确 | ✅ |
| AC9 | `agents/` 目录标记为已废弃 | ✅ (README.deprecated.md 存在) |
| AC10 | `develop` 分支已合并或删除 | ⚠️ 未完成 |
| AC11 | Pipeline 空闲时无 `openclaw-new` Issue | ✅ |
| AC12 | `SPEC.md`（本文件）完整且最新 | ✅ |

---

## 10. 后续工作（由 Developer Agent 承接）

基于本 Architect 分析，以下是建议的后续工作，按优先级排序：

### P1 — 高优先级

1. **合并/删除 `develop` 分支**
   - 推荐操作：`git checkout auto-dev && git merge develop` 或强制删除
   - 验证命令：`./scripts/cleanup-branches.sh --dry-run`

2. **验证 `auto-dev` 分支保护**
   - 命令：`gh api repos/neiliuxy/openclaw-auto-dev/branches/auto-dev/protection`
   - 如未保护，按 ARCHITECT.md 中描述的方式添加

### P2 — 中优先级

3. **清理 `agents/` 残留文件**
   - 删除 `agents/README.md`（已被 `agents/README.deprecated.md` 替代）
   - 删除 `agents/architect/` 和 `agents/developer/` 如果为空目录

4. **完善 CI 触发条件**
   - 确认 CI 在 `openclaw/issue-*` 分支的 PR 上也能触发

### P3 — 低优先级（可后续迭代）

5. **考虑将默认合并目标从 `master` 统一为 `auto-dev`**
6. **添加 Issue 优先级标签支持**
7. **考虑支持并行多 Issue 处理**

---

## 11. 参考文档

| 文档 | 说明 |
|------|------|
| `ARCHITECT.md` | 详细架构文档（含状态机图、模块分解） |
| `DESIGN.md` | 旧版设计文档（已归档，仅供参考） |
| `docs/BRANCH_STRATEGY.md` | 分支策略详细说明 |
| `docs/setup.md` | 部署和设置指南 |
| `HEARTBEAT-MECHANISM.md` | 心跳机制说明 |
| `openclaw/<num>_*/SPEC.md` | 各 Issue 的需求规格（样本参考：#102, #104） |
| `openclaw/<num>_*/TEST_REPORT.md` | 各 Issue 的测试报告（样本参考：#102, #104） |

---

*Generated by Architect Agent — Pipeline v5, Stage 0*
*版本: v2.0 | 日期: 2026-04-28*
