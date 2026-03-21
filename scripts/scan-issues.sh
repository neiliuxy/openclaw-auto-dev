#!/bin/bash
# OpenClaw Auto Dev - Issue 扫描脚本
# 用法：./scripts/scan-issues.sh [--notify]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/scan-$(date '+%Y-%m-%d').log"
REPORT_FILE="$PROJECT_ROOT/scan-result.json"

# 确保日志目录存在
mkdir -p "$LOG_DIR"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 生成报告
generate_report() {
    local status="$1"
    local message="$2"
    local issue_number="$3"
    local issue_title="$4"
    
    # 使用 jq 正确转义 JSON 字符串
    if [ -n "$issue_number" ]; then
        jq -n \
            --arg timestamp "$(date -Iseconds)" \
            --arg status "$status" \
            --arg message "$message" \
            --argjson issue_number "$issue_number" \
            --arg issue_title "$issue_title" \
            --arg scan_log "$LOG_FILE" \
            '{
                timestamp: $timestamp,
                status: $status,
                message: $message,
                issue_number: $issue_number,
                issue_title: $issue_title,
                scan_log: $scan_log
            }' > "$REPORT_FILE"
    else
        jq -n \
            --arg timestamp "$(date -Iseconds)" \
            --arg status "$status" \
            --arg message "$message" \
            --arg scan_log "$LOG_FILE" \
            '{
                timestamp: $timestamp,
                status: $status,
                message: $message,
                issue_number: null,
                issue_title: null,
                scan_log: $scan_log
            }' > "$REPORT_FILE"
    fi
}

log "🔍 开始扫描 GitHub Issue..."

# 检查是否有正在处理的 Issue（multi-agent 所有阶段）
log "📋 检查是否有 Issue 正在处理中..."
ALL_STAGES="openclaw-processing openclaw-architecting openclaw-planning openclaw-developing openclaw-testing openclaw-reviewing"
processing="[]"
for label in $ALL_STAGES; do
    result=$(gh issue list --repo neiliuxy/openclaw-auto-dev --state open --label "$label" --json number,title --limit 1 2>/dev/null || echo "[]")
    count=$(echo "$result" | jq 'length')
    if [ "$count" -gt 0 ]; then
        processing="$result"
        break
    fi
done

processing_count=$(echo "$processing" | jq 'length')

if [ "$processing_count" -gt 0 ]; then
    issue_num=$(echo "$processing" | jq -r '.[0].number')
    issue_title=$(echo "$processing" | jq -r '.[0].title')
    log "⚠️ 已有 Issue 在处理中，跳过本次扫描"
    log "处理中：Issue #$issue_num - $issue_title"
    generate_report "processing" "已有 Issue 在处理中" "$issue_num" "$issue_title"
    exit 0
fi

log "✅ 没有正在处理的 Issue"

# 查询新的 Issue
log "📬 查询 openclaw-new 状态的 Issue..."
new_issues=$(gh issue list --repo neiliuxy/openclaw-auto-dev --state open --label "openclaw-new" --json number,title,createdAt --limit 5 2>/dev/null || echo "[]")

new_count=$(echo "$new_issues" | jq 'length')

if [ "$new_count" -eq 0 ]; then
    log "ℹ️ 无新 Issue，本次扫描完成"
    generate_report "idle" "无新 Issue 需要处理" "" ""
    exit 0
fi

log "🎉 发现 $new_count 个新 Issue"

# 获取第一个 Issue 的编号
issue_number=$(echo "$new_issues" | jq -r '.[0].number')
issue_title=$(echo "$new_issues" | jq -r '.[0].title')

if [ -n "$issue_number" ] && [ "$issue_number" != "null" ]; then
    log "🎯 准备处理 Issue #$issue_number: $issue_title"
    
    # 输出到临时文件，供后续处理
    echo "$issue_number" > /tmp/openclaw_auto_dev_next_issue.txt
    
    log "✅ 扫描完成，下一个处理：Issue #$issue_number"
    generate_report "new_issue" "发现新 Issue" "$issue_number" "$issue_title"
    
    # 在这里可以调用 process-issue.sh 脚本
    # "$SCRIPT_DIR/process-issue.sh" "$issue_number"
else
    log "ℹ️ 无有效 Issue 需要处理"
    generate_report "idle" "无有效 Issue" "" ""
    exit 0
fi
