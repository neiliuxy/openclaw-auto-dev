# Issue 自动检查机制

## 📋 概述

自动检查带有 `openclaw-new` 标签的 GitHub Issues，确保没有遗漏需要处理的任务。

---

## ⏰ 检查频率

**每 30 分钟** 自动执行一次

---

## 🔧 实现方式

### 方案 1: GitHub Actions（云端）

**文件**: `.github/workflows/check-issues.yml`

**优点**:
- ✅ 无需本地服务器
- ✅ GitHub 原生支持
- ✅ 运行日志在 GitHub 可见

**配置**:
```yaml
on:
  schedule:
    - cron: '*/30 * * * *'  # 每 30 分钟
```

**查看运行日志**: 
https://github.com/neiliuxy/openclaw-auto-dev/actions

---

### 方案 2: Local Cron（本地）

**文件**: `scripts/check-openclaw-issues.sh`

**优点**:
- ✅ 更灵活，可扩展
- ✅ 可以集成本地通知
- ✅ 可以自动调用 process-issue.sh

**Cron 配置**:
```bash
*/30 * * * * /path/to/check-openclaw-issues.sh
```

**查看日志**:
```bash
tail -f logs/issue-check.log
```

**查看状态**:
```bash
cat .validation/last-checked-issue.json
```

---

## 📊 工作流程

```
每 30 分钟
    ↓
查询 GitHub Issues
    ↓
筛选 openclaw-new 标签
    ↓
发现新 issue？
    ├─ 是 → 记录到状态文件 → 可选：自动处理
    └─ 否 → 记录日志 → 退出
```

---

## 📁 文件结构

```
openclaw-auto-dev/
├── .github/workflows/
│   └── check-issues.yml          # GitHub Actions 配置
├── scripts/
│   └── check-openclaw-issues.sh  # 检查脚本
├── logs/
│   ├── issue-check.log           # 检查日志
│   └── cron.log                  # Cron 运行日志
├── .validation/
│   └── last-checked-issue.json   # 状态追踪
└── ISSUE-CHECKER.md              # 本文档
```

---

## 🔍 日志示例

```
[2026-03-19 09:30:00] [STEP] ==========================================
[2026-03-19 09:30:00] [STEP] 开始检查 openclaw-new 标签 issue
[2026-03-19 09:30:00] [STEP] ==========================================
[2026-03-19 09:30:01] [INFO] 仓库：neiliuxy/openclaw-auto-dev
[2026-03-19 09:30:02] [INFO] 查询 GitHub Issues...
[2026-03-19 09:30:03] [INFO] 发现 2 个 openclaw-new 标签 issue
[2026-03-19 09:30:03] [STEP] ----------------------------------------
[2026-03-19 09:30:03] [INFO] Issue #9: Feature: Upgrade Hello World
[2026-03-19 09:30:03] [INFO] 作者：neiliuxy | 创建时间：2026-03-19T01:51:00Z
[2026-03-19 09:30:03] [INFO] ✅ Issue #9 已记录
[2026-03-19 09:30:03] [STEP] ==========================================
[2026-03-19 09:30:03] [INFO] 检查完成！
[2026-03-19 09:30:03] [STEP] ==========================================
```

---

## 🎯 自动处理扩展

可以在 `check-openclaw-issues.sh` 中添加自动处理逻辑：

```bash
# 发现新 issue 后自动处理
if [ "$processed" = "null" ]; then
    log_info "🤖 开始自动处理 Issue #$issue_num"
    
    # 调用处理脚本
    ./scripts/process-issue.sh $issue_num
    
    log_info "✅ Issue #$issue_num 处理完成"
fi
```

---

## ⚠️ 注意事项

1. **GitHub Token** - GitHub Actions 自动使用 `GITHUB_TOKEN`，本地 cron 需要 `gh auth login`
2. **重复处理** - 状态文件防止同一 issue 被多次处理
3. **错误处理** - 脚本失败会记录到日志，不会中断 cron

---

## 📝 手动触发

### GitHub Actions
```bash
# 在 GitHub 页面手动运行 workflow
https://github.com/neiliuxy/openclaw-auto-dev/actions/workflows/check-issues.yml
```

### 本地脚本
```bash
./scripts/check-openclaw-issues.sh
```

### 查看状态
```bash
# 查看已处理的 issue
cat .validation/last-checked-issue.json | jq

# 查看最近日志
tail -50 logs/issue-check.log
```

---

## 🔧 故障排查

### Cron 没有运行
```bash
# 检查 cron 服务
systemctl status cron

# 检查 cron 日志
grep CRON /var/log/syslog | tail -20

# 验证 crontab
crontab -l
```

### 脚本执行失败
```bash
# 手动运行查看错误
./scripts/check-openclaw-issues.sh

# 检查 gh 认证
gh auth status
```

---

**最后更新**: 2026-03-19  
**状态**: ✅ 运行中
