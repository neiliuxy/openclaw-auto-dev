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

### 步骤 2：确认 cron 配置

```bash
crontab -l
# 确认有: */30 * * * * cd .../openclaw-auto-dev && bash scripts/cron-heartbeat.sh
```

如需添加：
```bash
crontab -e
# 添加: */30 * * * * cd /home/admin/.openclaw/workspace/openclaw-auto-dev && bash scripts/cron-heartbeat.sh >> logs/cron-heartbeat.log 2>&1
```

### 步骤 3：测试 Pipeline

创建带 `openclaw-new` 标签的 Issue，然后手动触发：

```bash
pipeline-runner.sh <issue_number>
```

其中 `pipeline-runner.sh` 位于：
```
~/.openclaw/workspace/skills/openclaw-pipeline/pipeline-runner.sh
```

---

## 📊 监控

```bash
# 查看 Pipeline 状态
ls -la .pipeline-state/

# 查看 Pipeline 日志
tail -f logs/pipeline-$(date '+%Y-%m-%d').log

# 查看 Issue 状态
gh issue list --label "openclaw-new"
gh issue list --label "openclaw-completed"
```

---

## 🔍 故障排除

| 问题 | 解决方案 |
|------|----------|
| Issue 未自动处理 | 手动调用 `pipeline-runner.sh <issue_number>` |
| Pipeline 卡在某阶段 | 检查 `.pipeline-state/<issue>_stage` 状态 |
| 重新开始 | `rm .pipeline-state/<issue>_stage` |
