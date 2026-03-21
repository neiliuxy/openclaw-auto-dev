# Multi-Agent 开发系统设计方案

> 📋 **版本**: v1.0  
> 📅 **日期**: 2026-03-21  
> 🎯 **目标**: 构建四角色多智能体协作开发系统

---

## 1. 系统概述

### 1.1 设计目标

在现有 `openclaw-auto-dev` 单体流程基础上，引入 **四 Agent 协作分工**：

| Agent | 职责 | 产出 |
|--------|------|------|
| **Agent-Architect** | 需求分析 + 开发方案设计 | `SPEC.md` 设计文档 |
| **Agent-Developer** | 根据方案进行代码开发 | 代码实现 |
| **Agent-Tester** | 验证需求是否正确实现 | `TEST_REPORT.md` |
| **Agent-Reviewer** | 判断合并 or 继续迭代 | 决策 + 状态更新 |

### 1.2 核心原则

- **Agent-Architect 不写代码** — 纯文档输出，避免角色混乱
- **每个 Agent 独立工作目录** — 通过文件系统传递产物（`/workspace/agents/{agent}/`）
- **单向工作流 + 反馈循环** — 正常推进，验证失败则打回 Agent-Developer
- **符合现有项目 Issue → PR 流程** — 复用状态标签体系

---

## 2. 架构总览

```
用户创建 Issue (openclaw-new)
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions (定时/触发)                  │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  Agent-Architect  ·  需求分析 & 开发方案设计                    │
│  📄 产出: SPEC.md (需求规格 + 技术方案 + 验收标准)              │
│  🚫 不写代码，只出文档                                         │
└──────────────────────────┬──────────────────────────────────┘
                           │ 文档就绪
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Agent-Developer  ·  代码开发                                 │
│  📂 读取 SPEC.md，实现所有功能点                               │
│  📄 产出: 完整代码实现                                         │
└──────────────────────────┬──────────────────────────────────┘
                           │ 代码完成
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Agent-Tester  ·  测试验证                                    │
│  📄 读取 SPEC.md + 代码，逐条验证                              │
│  📄 产出: TEST_REPORT.md (通过项 / 失败项 / 问题列表)          │
└──────────────────────────┬──────────────────────────────────┘
                           │ 验证报告
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Agent-Reviewer  ·  合并决策                                   │
│  ✅ 全部通过 → 创建 PR → 更新状态 → 合并                        │
│  ❌ 有失败项 → 打回 Agent-Developer 继续开发                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Agent 详细设计

### 3.1 Agent-Architect（需求分析 & 方案设计）

**角色定位**：纯规划型 Agent，专注理解、拆解、文档化，不碰代码。

#### 职责
- 接收 Issue 内容（标题、描述、标签）
- 分析需求背景和目标
- 拆解功能点（可独立验证的最小单元）
- 设计技术方案（目录结构、核心模块、依赖）
- 制定验收标准（每条功能点对应可测试的判定条件）
- 撰写 `SPEC.md` 文档

#### 产出文件：`SPEC.md`

```markdown
# Issue #XX 需求规格说明书

## 1. 概述
- **Issue**: #XX
- **标题**: [Issue 标题]
- **创建时间**: YYYY-MM-DD
- **处理时间**: YYYY-MM-DD

## 2. 需求分析

### 2.1 背景
[需求的业务背景或技术动因]

### 2.2 功能范围
**包含：**
- [功能点 A]
- [功能点 B]

**不包含：**
- [明确排除的功能]

### 2.3 功能点拆解

| ID | 功能点 | 描述 | 验收标准 |
|----|--------|------|----------|
| F01 | [名称] | [描述] | [可测试的判定条件] |
| F02 | [名称] | [描述] | [可测试的判定条件] |

## 3. 技术方案

### 3.1 目录结构
```
src/
  ├── module_a/
  │   ├── main.go
  │   └── main_test.go
  └── module_b/
      └── main.go
```

### 3.2 核心模块设计
[模块职责说明]

### 3.3 依赖清单
- [依赖 A: 版本/用途]

### 3.4 接口设计（如有）
[API 接口签名]

## 4. 验收标准

### 4.1 功能验收
- [ ] F01: [验收条件]
- [ ] F02: [验收条件]

### 4.2 质量标准
- 代码可通过 `make test`
- 无新增 lint 错误
- 提交信息符合 conventional commits 规范

## 5. 风险与备注
[已知风险、特殊约束]
```

#### 工作目录结构
```
agents/architect/
├── input/          # 原始 Issue 内容
├── output/         # 产出的 SPEC.md
└── logs/           # 执行日志
```

#### 判定规则
- 产出 `SPEC.md` 必须包含**所有**功能点的验收标准
- 验收标准必须**可自动化测试**（或可明确判定通过/失败）
- 如 Issue 描述模糊，Architect **必须先在 Issue 下提问**，不得自行假设

---

### 3.2 Agent-Developer（代码开发）

**角色定位**：实现型 Agent，读取方案，输出代码。

#### 职责
- 读取 `SPEC.md`
- 创建功能分支 `feature/issue-{N}-v{N}`
- 按照技术方案实现所有功能点（F01, F02, ...）
- 确保代码可编译、可运行
- 遵守项目现有的代码规范（Makefile、lint、format）
- 提交代码（每功能点单独 commit 方便追溯）

#### 产出
- 完整代码实现
- `COMMIT_LOG.md`（本次提交的功能点清单）

#### 判定规则
- 代码必须实现 `SPEC.md` 中的**所有**功能点
- 如发现 `SPEC.md` 有遗漏或错误，**先更新 SPEC.md 再开发**
- 禁止跳过 Architect 定义的验收标准自行发挥

#### 工作目录结构
```
agents/developer/
├── input/          # 复制 SPEC.md
├── output/         # 产出的代码
└── logs/
```

---

### 3.3 Agent-Tester（测试验证）

**角色定位**：验证型 Agent，客观判定，不做修改。

#### 职责
- 读取 `SPEC.md` + 实际代码
- 对每条验收标准（Checklist）逐条验证
- 验证方式：
  - **功能测试**：运行代码，执行场景
  - **单元测试**：运行 `make test`
  - **静态检查**：`make lint` / `make fmt`
  - **人工判定**：如无法自动化，在报告中标注需人工复核
- 撰写 `TEST_REPORT.md`

#### 产出文件：`TEST_REPORT.md`

```markdown
# 测试验证报告

## Issue #XX 测试报告

**测试时间**: YYYY-MM-DD
**测试人**: Agent-Tester

## 测试结果：✅ 通过 / ❌ 未通过

### 验收标准验证详情

| ID | 验收标准 | 测试方法 | 结果 | 说明 |
|----|----------|----------|------|------|
| F01 | [标准] | [方法] | ✅/❌ | [说明] |

### 通过项 (N)
- [ ] F01: [功能点]

### 失败项 (N)
- [ ] F03: [功能点] — 失败原因：[描述]

### 遗留问题
- [问题描述]

### 建议
[改进建议，如有]
```

#### 判定规则
- Tester **不修改代码**，只报告结果
- 如验证工具缺失，在报告中注明
- 所有验收标准必须**逐条验证**，不得跳过

#### 工作目录结构
```
agents/tester/
├── input/          # SPEC.md + 代码副本
├── output/         # TEST_REPORT.md
└── logs/
```

---

### 3.4 Agent-Reviewer（合并决策）

**角色定位**：决策型 Agent，基于验证结果决定流程走向。

#### 职责
- 读取 `TEST_REPORT.md`
- 判定结果：
  - **全部通过** → 创建 PR，更新 Issue 状态为 `openclaw-pr-created`，触发合并流程
  - **有失败项** → 打回 Agent-Developer，附上 `TEST_REPORT.md`，继续迭代
- 迭代超过阈值（默认 3 次）仍不通过 → 更新 Issue 状态为 `openclaw-error`，通知人工介入

#### 决策规则

```
IF all_tests_passed:
    → create_PR()
    → update_issue_status("openclaw-pr-created")
    → notify_collaborators()
ELIF iteration_count < MAX_ITERATIONS:
    → update_issue_status("openclaw-processing")
    → attach_test_report()
    → notify_developer_continue()
ELSE:
    → update_issue_status("openclaw-error")
    → notify_human_review()
```

#### 产出
- PR 创建（或打回通知）
- Issue 状态更新
- 迭代次数记录

#### 工作目录结构
```
agents/reviewer/
├── input/          # TEST_REPORT.md
├── output/         # 决策日志
└── logs/
```

---

## 4. 完整工作流程

### 4.1 流程图

```
用户创建 Issue (openclaw-new)
         │
         ▼
  ┌───────────────┐
  │   Architect   │  ←─ 读取 Issue，输出 SPEC.md
  └───────┬───────┘
          │ SPEC.md 就绪
          ▼
  ┌───────────────┐
  │   Developer   │  ←─ 读取 SPEC.md，输出代码
  └───────┬───────┘
          │ 代码完成
          ▼
  ┌───────────────┐
  │   Tester      │  ←─ 验证代码，输出 TEST_REPORT
  └───────┬───────┘
          │ 报告生成
          ▼
  ┌───────────────┐
  │   Reviewer    │  ←─ 决策：合并 or 打回
  └───────┬───────┘
          │
    ┌─────┴─────┐
    │           │
  ✅通过       ❌失败
    │           │
    ▼           ▼
  创建PR    打回 Developer
  更新状态    (带报告)
  合并代码    迭代开发
```

### 4.2 单次迭代时序

```
T+0     Issue 创建 (openclaw-new)
T+0~5   Architect: 分析需求，输出 SPEC.md
T+5~20  Developer: 实现代码
T+20~30 Tester: 验证，输出 TEST_REPORT
T+30~32 Reviewer: 决策
         ├─ 通过 → 创建 PR
         └─ 失败 → 打回 Developer (迭代+1)
```

### 4.3 分支命名规范

```
feature/issue-{N}           # 整体分支（Architect 后创建）
feature/issue-{N}-iter-{M} # 迭代分支（Reviewer 打回后创建）
```

### 4.4 Issue 状态标签（扩展）

| 状态标签 | 含义 | 触发时机 |
|----------|------|----------|
| `openclaw-new` | 新 Issue，等待处理 | 用户创建 |
| `openclaw-architecting` | Architect 正在分析 | Architect 启动 |
| `openclaw-planning` | 方案设计中 | Architect 产出 SPEC |
| `openclaw-developing` | Developer 正在开发 | Developer 启动 |
| `openclaw-testing` | Tester 正在验证 | Tester 启动 |
| `openclaw-reviewing` | Reviewer 决策中 | Reviewer 启动 |
| `openclaw-pr-created` | PR 已创建 | Reviewer 通过 |
| `openclaw-completed` | 已完成合并 | PR 合并 |
| `openclaw-error` | 异常/超迭代上限 | Reviewer 决策 |

---

## 5. 技术实现

### 5.1 现有系统复用

完全复用现有 `openclaw-auto-dev` 的：
- GitHub Actions 定时触发（每 30 分钟）
- `gh` CLI 进行 GitHub 操作
- 现有 Issue 标签体系（扩展新标签）
- `scripts/` 目录结构

### 5.2 新增脚本

```
scripts/
├── agent-architect.sh    # 调用 Architect Agent
├── agent-developer.sh    # 调用 Developer Agent
├── agent-tester.sh      # 调用 Tester Agent
├── agent-reviewer.sh    # 调用 Reviewer Agent
└── multi-agent-run.sh   # 主流程编排脚本
```

### 5.3 Agent 调用方式

每个 Agent 由 OpenClaw 子会话（`sessions_spawn`）实现：

```bash
# 示例：调用 Architect
openclaw agent --message "读取 Issue #XX，执行 Architect 职责，输出 SPEC.md 到 agents/architect/output/SPEC.md"
```

### 5.4 产物传递

通过共享文件系统：
```
openclaw-auto-dev/
├── SPEC.md              # Architect → Developer 共享
├── TEST_REPORT.md       # Tester → Reviewer 共享
├── agents/
│   ├── architect/output/SPEC.md
│   ├── developer/output/代码变更
│   ├── tester/output/TEST_REPORT.md
│   └── reviewer/output/决策日志
└── .agent-state         # 迭代次数、当前阶段
```

---

## 6. 与现有单 Agent 流程的对比

| 维度 | 现有单 Agent | Multi-Agent 四角色 |
|------|-------------|-------------------|
| 角色分工 | OpenClaw 全能 | 四 Agent 各司其职 |
| 方案设计 | 无正式文档 | 强制输出 SPEC.md |
| 质量门禁 | 依赖人工 Review | Tester 自动验证 |
| 迭代决策 | 人工判断 | Reviewer 自动化决策 |
| 可追溯性 | 弱 | 强（每阶段产物） |
| 适用场景 | 简单 Issue | 复杂需求/多人协作 |

---

## 7. 实施步骤

1. **Phase 1** — 在现有 `openclaw-auto-dev` 中新增 `SPEC.md` 模板
2. **Phase 2** — 实现 `agent-architect.sh`，拆分需求分析职责
3. **Phase 3** — 扩展现有开发脚本，引入 SPEC.md 作为输入约束
4. **Phase 4** — 实现 `agent-tester.sh`，自动运行测试并生成报告
5. **Phase 5** — 实现 `agent-reviewer.sh`，自动决策流程走向
6. **Phase 6** — 全流程联调，替换现有单一处理逻辑

---

## 8. 风险与约束

| 风险 | 缓解措施 |
|------|----------|
| SPEC.md 质量差导致后续全部返工 | Architect 必须通过 Review，不通过则打回重写 |
| Tester 无法自动化验证某些功能 | 支持人工判定标注，Reviewer 转为人工介入 |
| 迭代超过阈值无法收敛 | 3 次迭代后强制转入 `openclaw-error`，人工处理 |
| Agent 间传递丢失上下文 | 通过共享文件系统持久化所有产物 |
