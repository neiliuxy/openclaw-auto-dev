# OpenClaw Auto Dev 心跳配置

> **⚠️ 已升级为 Multi-Agent 四角色流程**，见 `MULTI_AGENT_DESIGN.md`

## 任务说明

- **频率**: 每 30 分钟检查一次
- **并发**: 同时只处理一个 Issue
- **流程**: 四 Agent 协作（见下方）

## 四 Agent 开发流程

```
openclaw-new
    │
    ▼
Architect ──→ SPEC.md
    │         (需求分析 + 开发方案 + 验收标准)
    │         ⚠️ 不写代码，只出文档
    ▼
Developer ──→ 代码实现
    │         (读取 SPEC.md，实现全部功能点)
    ▼
Tester ────→ TEST_REPORT.md
    │         (逐条验证，生成报告)
    ▼
Reviewer ──→ PR / 打回迭代
    │         (通过 → 创建 PR；失败 → 打回 Developer)
    ▼
openclaw-pr-created / openclaw-processing (继续迭代)
    │
    ▼
PR 合并 ──→ openclaw-completed
```

## 检查清单

- [ ] 检查是否有 `openclaw-new` 状态的 Issue
- [ ] 如果有，获取第一个 Issue 编号
- [ ] 确认没有其他 Issue 正在处理中（`openclaw-architecting` / `openclaw-developing` 等）
- [ ] 按顺序执行四 Agent 流程

## Agent 执行脚本

```bash
# 1. Architect：分析需求，输出 SPEC.md
./scripts/agent-architect.sh <issue_number>

# 2. Developer：读取 SPEC.md，开发代码
./scripts/agent-developer.sh <issue_number>

# 3. Tester：验证实现，输出 TEST_REPORT.md
./scripts/agent-tester.sh <issue_number>

# 4. Reviewer：决策合并或打回
./scripts/agent-reviewer.sh <issue_number>

# 主流程（一键执行）
./scripts/multi-agent-run.sh <issue_number>
```

## Issue 状态标签（扩展版）

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

## 迭代规则

- 验证失败 → Reviewer 打回 Developer，最多 **3 次迭代**
- 3 次迭代后仍不通过 → `openclaw-error` + 通知人工介入
- 迭代分支命名：`feature/issue-{N}-iter-{M}`

## 产物文件

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

## 注意事项

1. **同时只处理一个 Issue**，避免状态冲突
2. **Architect 不写代码**，只输出 SPEC.md
3. **Tester 不修改代码**，只报告验证结果
4. 记录每次处理的日志到 `logs/` 目录

## 错误处理

- opencode 超时 → 添加 `openclaw-error` 标签
- SPEC.md 验收标准无法测试 → Architect 打回重写
- Git 冲突 → 重试或标记错误
- API 限流 → 等待 1 小时后重试
