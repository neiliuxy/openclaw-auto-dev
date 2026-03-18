# OpenClaw Auto Dev 心跳配置

## 任务说明

- **频率**: 每 30 分钟检查一次
- **并发**: 同时只处理一个 Issue
- **流程**: openclaw-new → openclaw-processing → openclaw-pr-created → openclaw-completed

## 检查清单

- [ ] 检查是否有 `openclaw-new` 状态的 Issue
- [ ] 如果有，获取第一个 Issue 编号
- [ ] 确认没有其他 Issue 正在处理中
- [ ] 调用 `scripts/process-issue.sh` 处理
- [ ] 等待 PR 创建
- [ ] PR 合并后更新为 `openclaw-completed`

## 命令参考

```bash
# 检查新 Issue
gh issue list --state open --label "openclaw-new" --limit 1

# 检查是否有正在处理的 Issue
gh issue list --state open --label "openclaw-processing" --limit 1

# 获取 Issue 详情
gh issue view <number> --json title,body,labels

# 更新 Issue 标签
gh issue edit <number> --add-label "openclaw-processing"
gh issue edit <number> --remove-label "openclaw-new"

# 创建分支
git checkout -b feature/issue-<number>

# 创建 PR
gh pr create --title "..." --body "..." --head "..." --base "main"
```

## 注意事项

1. 同时只处理一个 Issue，避免冲突
2. PR 需要人工审核后再合并
3. 如果处理失败，添加 `openclaw-error` 标签并记录日志
4. 记录每次处理的日志到 `logs/` 目录

## 错误处理

- opencode 超时 → 添加 `openclaw-error` 标签
- Git 冲突 → 重试或标记错误
- API 限流 → 等待 1 小时后重试
