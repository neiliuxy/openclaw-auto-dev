# OpenClaw Auto Dev - 部署指南

## 📋 前置条件

1. **OpenClaw 已安装并配置**
   ```bash
   openclaw status
   ```

2. **GitHub CLI 已安装并认证**
   ```bash
   gh auth status
   ```

---

## 🔧 配置步骤

### 步骤 1：克隆项目

```bash
git clone https://github.com/neiliuxy/openclaw-auto-dev.git
cd openclaw-auto-dev
```

### 步骤 2：确认 crontab 配置

```bash
crontab -l
# 确认有: */30 * * * * cd .../openclaw-auto-dev && bash scripts/cron-heartbeat.sh
```

如需添加：
```bash
crontab -e
# 添加: */30 * * * * cd /home/admin/.openclaw/workspace/openclaw-auto-dev && bash scripts/cron-heartbeat.sh >> logs/cron-heartbeat.log 2>&1
```

### 步骤 3：GitHub Actions

workflow 已配置。无需额外 Secrets（使用内置 `github.token`）。

### 步骤 4：测试

创建带 `openclaw-new` 标签的 Issue，等待 30 分钟自动处理，或手动：

```bash
./scripts/multi-agent-run.sh <issue_number>
```

---

## 📊 监控

```bash
# 查看本地日志
tail -f logs/cron-heartbeat.log
tail -f logs/multi-agent-$(date '+%Y-%m-%d').log

# 查看 GitHub Actions
gh run list --limit 5

# 查看 Issue 状态
gh issue list --label "openclaw-new"
gh issue list --label "openclaw-completed"
```

---

## 🔍 故障排除

| 问题 | 解决方案 |
|------|----------|
| Issue 未自动处理 | 手动 `./scripts/multi-agent-run.sh <issue_number>` |
| pr-merge 标签更新失败 | 查看 GHA run 日志是否有 `GH_TOKEN` 错误 |
| LLM 代码生成失败 | 查看 `logs/multi-agent-*.log` 失败阶段 |

---

**详细设计**: [MULTI_AGENT_DESIGN.md](../MULTI_AGENT_DESIGN.md)
