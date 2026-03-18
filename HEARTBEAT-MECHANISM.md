# ❤️ 心跳机制 - OpenClaw Auto Dev

## 概述

OpenClaw Auto Dev 使用心跳机制实现**定期自动扫描 GitHub Issue**，确保不错过任何需要处理的任务。

---

## 工作机制

```
┌─────────────────────────────────────────────────────────────┐
│  OpenClaw 系统心跳触发 (每 30 分钟)                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  执行扫描脚本：./scripts/heartbeat-check.sh                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  1. 调用 scan-issues.sh 扫描 GitHub                         │
│  2. 生成扫描结果报告 (scan-result.json)                     │
│  3. 输出格式化报告到终端                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  ✅ AI 立即向用户报告扫描结果（无论有无 Issue）              │
└─────────────────────────────────────────────────────────────┘
```

---

## 核心特性

### 1. 定期扫描
- **频率**: 每 30 分钟自动执行一次
- **触发**: OpenClaw 心跳机制
- **配置**: `HEARTBEAT.md` 文件定义任务

### 2. 智能过滤
- 只扫描带有 `openclaw-new` 标签的 Issue
- 自动跳过正在处理的 Issue（`openclaw-processing` 标签）
- 避免重复处理

### 3. 强制报告
- **无论有无 Issue，都必须向用户报告**
- 不再等用户主动询问
- 报告内容包括：扫描时间、状态、详情

---

## 文件结构

```
openclaw-auto-dev/
├── HEARTBEAT.md                      # OpenClaw 心跳配置文件
├── scripts/
│   ├── heartbeat-check.sh            # 心跳检查主脚本
│   ├── scan-issues.sh                # Issue 扫描脚本
│   └── process-issue.sh              # Issue 处理脚本（待完善）
├── logs/
│   ├── scan-YYYY-MM-DD.log          # 每日扫描日志
│   └── cron-heartbeat.log           # 心跳执行日志
└── scan-result.json                  # 最新扫描结果（JSON 格式）
```

---

## 脚本说明

### `scripts/heartbeat-check.sh`
主入口脚本，执行完整的心跳检查流程：
```bash
cd /home/admin/.openclaw/workspace/openclaw-auto-dev
./scripts/heartbeat-check.sh
```

### `scripts/scan-issues.sh`
核心扫描逻辑：
1. 检查是否有正在处理的 Issue
2. 查询新的 Issue（`openclaw-new` 标签）
3. 生成扫描结果报告
4. 输出到 `scan-result.json`

---

## Issue 状态流转

```
openclaw-new          → 新创建的 Issue，等待处理
     ↓
openclaw-processing   → 正在处理中（避免重复扫描）
     ↓
openclaw-pr-created   → PR 已创建，等待合并
     ↓
openclaw-completed    → 已完成（PR 已合并）
```

**异常状态**:
- `openclaw-error` → 处理失败，需要人工介入

---

## 报告格式

### 无 Issue 时
```
🔍 OpenClaw Auto Dev Issue 扫描结果

扫描时间：2026-03-18 18:00:25

| 项目     | 状态           |
|----------|----------------|
| 📊 状态  | 无新 Issue     |
| ✅ 处理中 | 无             |
| 📝 详情  | 无新 Issue 需要处理 |

系统状态：✅ 正常运行
```

### 发现新 Issue 时
```
🎉 OpenClaw Auto Dev Issue 扫描结果

扫描时间：2026-03-18 18:00:25

| 项目     | 状态               |
|----------|--------------------|
| 📊 状态  | 发现新 Issue！     |
| 🔢 Issue | #123               |
| 📝 标题  | 添加用户登录功能   |

🚀 准备开始处理...
```

### 有 Issue 处理中时
```
⚠️ OpenClaw Auto Dev Issue 扫描结果

扫描时间：2026-03-18 18:00:25

| 项目     | 状态               |
|----------|--------------------|
| 📊 状态  | 已有 Issue 在处理中 |
| 🔢 Issue | #123               |
| 📝 标题  | 添加用户登录功能   |

⏳ 等待当前 Issue 处理完成后再继续...
```

---

## 配置说明

### OpenClaw 心跳配置 (`HEARTBEAT.md`)

```markdown
## OpenClaw Auto Dev - Issue 扫描

**频率**: 每 30 分钟检查一次

**任务**:
- 扫描 GitHub `neiliuxy/openclaw-auto-dev` 仓库
- 只查询带有 `openclaw-new` 标签的 Issue
- **每次扫描后必须立即向用户报告结果**（无论有无 Issue）

**执行命令**:
```bash
cd /home/admin/.openclaw/workspace/openclaw-auto-dev && ./scripts/heartbeat-check.sh
```
```

---

## 日志查看

### 实时日志
```bash
# 查看今日扫描日志
tail -f logs/scan-$(date '+%Y-%m-%d').log

# 查看心跳执行日志
tail -f logs/cron-heartbeat.log
```

### 历史日志
```bash
ls -la logs/
```

---

## 故障排查

### 问题 1: 扫描未执行
**检查**:
```bash
# 查看心跳配置
cat HEARTBEAT.md

# 手动执行测试
./scripts/heartbeat-check.sh
```

### 问题 2: 报告未生成
**检查**:
```bash
# 查看扫描结果
cat scan-result.json

# 查看日志
cat logs/scan-*.log
```

### 问题 3: GitHub API 限流
**解决**:
- 等待限流解除（通常 1 小时）
- 或使用 authenticated API（配置 `GH_TOKEN`）

---

## 最佳实践

1. **创建 Issue 时务必添加 `openclaw-new` 标签**
2. **处理中的 Issue 不要手动移除 `openclaw-processing` 标签**
3. **定期检查日志，确保心跳正常工作**
4. **遇到 `openclaw-error` 状态时及时人工介入**

---

## 未来扩展

- [ ] 支持多个仓库同时扫描
- [ ] Issue 优先级排序
- [ ] 自动测试生成与运行
- [ ] PR 自动 Code Review
- [ ] 每日/每周汇总报告

---

**最后更新**: 2026-03-18
