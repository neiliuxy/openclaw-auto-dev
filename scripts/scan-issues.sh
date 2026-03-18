#!/bin/bash
# OpenClaw Auto Dev - Issue 扫描脚本
# 用法：./scripts/scan-issues.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/scan-$(date '+%Y-%m-%d').log"

# 确保日志目录存在
mkdir -p "$LOG_DIR"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "🔍 开始扫描 GitHub Issue..."

# 检查是否有正在处理的 Issue
log "📋 检查是否有 Issue 正在处理中..."
processing=$(gh issue list --repo neiliuxy/openclaw-auto-dev --state open --label "openclaw-processing" --limit 1 2>/dev/null || echo "")

if [ -n "$processing" ]; then
    log "⚠️ 已有 Issue 在处理中，跳过本次扫描"
    log "处理中：$processing"
    exit 0
fi

log "✅ 没有正在处理的 Issue"

# 查询新的 Issue
log "📬 查询 openclaw-new 状态的 Issue..."
new_issues=$(gh issue list --repo neiliuxy/openclaw-auto-dev --state open --label "openclaw-new" --json number,title,createdAt --limit 1 2>/dev/null || echo "")

if [ -z "$new_issues" ]; then
    log "ℹ️ 无新 Issue，本次扫描完成"
    exit 0
fi

log "🎉 发现新 Issue: $new_issues"

# 获取第一个 Issue 的编号
issue_number=$(echo "$new_issues" | jq -r '.[0].number')

if [ -n "$issue_number" ] && [ "$issue_number" != "null" ]; then
    log "🎯 准备处理 Issue #$issue_number"
    
    # 输出到临时文件，供后续处理
    echo "$issue_number" > /tmp/openclaw_auto_dev_next_issue.txt
    
    log "✅ 扫描完成，下一个处理：Issue #$issue_number"
    
    # 在这里可以调用 process-issue.sh 脚本
    # "$SCRIPT_DIR/process-issue.sh" "$issue_number"
else
    log "ℹ️ 无有效 Issue 需要处理"
    exit 0
fi
