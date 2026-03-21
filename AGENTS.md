# AGENTS.md - AI 开发指南

**OpenClaw Auto Dev 项目** — 多 Agent 自动化 GitHub Issue 处理系统

---

## 🎯 系统架构

本项目采用**四 Agent 协作流程**，由 `multi-agent-run.sh` 统一编排：

```
Architect → Developer → Tester → Reviewer → PR 合并
```

各 Agent 角色详情见 `MULTI_AGENT_DESIGN.md`。

---

## 🤖 核心原则

### 1. Trust but Verify
- **永远不要假设**操作正确执行了
- 始终验证：运行测试、编译检查
- 验证失败 = 回滚，不要提交

### 2. 产物驱动开发
- Architect 输出 SPEC.md（需求规格）
- Developer 基于 SPEC.md 开发
- Tester 基于 SPEC.md 验证
- Reviewer 基于 TEST_REPORT.md 决策

### 3. 小步提交
- 每个 Issue 一个分支：`openclaw/issue-{num}`
- 提交信息包含 Issue 引用：`feat: add feature (closes #N)`

---

## 🛠️ 关键脚本

| 脚本 | 用途 |
|------|------|
| `scripts/multi-agent-run.sh` | 四 Agent 主流程（核心） |
| `scripts/heartbeat-check.sh` | OpenClaw HEARTBEAT 调用 |
| `scripts/cron-heartbeat.sh` | crontab 调用 |
| `scripts/scan-issues.sh` | GitHub Issue 扫描 |

---

## 📝 Issue 处理流程

1. 用户创建 Issue，打上 `openclaw-new` 标签
2. 心跳触发 `multi-agent-run.sh`
3. 四 Agent 依次执行：Architect → Developer → Tester → Reviewer
4. PR 合并，pr-merge.yml 自动更新标签为 `openclaw-completed`

---

## 🔧 本地调试

```bash
# 手动触发多 Agent 流程
./scripts/multi-agent-run.sh <issue_number>

# 查看日志
tail -f logs/multi-agent-$(date '+%Y-%m-%d').log
tail -f logs/cron-heartbeat.log

# 仅扫描 Issue
./scripts/scan-issues.sh
```

---

## 🚨 常见错误

| 错误 | 原因 | 解决 |
|------|------|------|
| `GH_TOKEN: 未配置` | workflow 用了 `secrets.GH_TOKEN` | 改用 `github.token` |
| PR 没合并 | Reviewer 没调用 `gh pr merge` | 检查 `multi-agent-run.sh` Reviewer 阶段 |
| 状态标签不一致 | pr-merge.yml 失败 | 检查 workflow 中 `GH_TOKEN` |
| 代码与 Issue 不符 | Developer 用模板而非 SPEC | 重写 Developer 阶段逻辑 |

---

**完整设计文档**: [MULTI_AGENT_DESIGN.md](./MULTI_AGENT_DESIGN.md)
