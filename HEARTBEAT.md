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
    │         (通过 → 创建 PR + 合并；失败 → 打回 Developer)
    ▼
PR 合并 ──→ openclaw-completed
```

## Agent 执行脚本

```bash
# 推荐：直接运行多角色主流程
./scripts/multi-agent-run.sh <issue_number>

# 或：通过心跳脚本（自动检测新 Issue）
./scripts/heartbeat-check.sh    # OpenClaw HEARTBEAT
./scripts/cron-heartbeat.sh     # crontab
```

**注意**：四 Agent 均内嵌在 `multi-agent-run.sh` 中，不作为独立脚本存在。

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
- 3 次迭代后仍不通过 → `openclaw-error` + 人工介入
- 迭代分支命名：`openclaw/issue-{N}-iter-{M}`

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

- LLM API 不可用 → 使用智能 fallback 生成代码
- 编译失败 → 标记失败，Reviewer 打回
- Git 冲突 → 重试或标记错误
- API 限流 → 等待后重试
