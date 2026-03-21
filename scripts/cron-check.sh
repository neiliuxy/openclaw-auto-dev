#!/bin/bash
# Cron 检查脚本 - 由 OpenClaw cron 调用
# 用法: ./scripts/cron-check.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO="neiliuxy/openclaw-auto-dev"

# 检查是否有正在处理的 Issue（所有阶段）
check_processing() {
    local ALL_STAGES="openclaw-architecting openclaw-planning openclaw-developing openclaw-testing openclaw-reviewing openclaw-processing"
    for label in $ALL_STAGES; do
        count=$(gh issue list --repo "$REPO" --state open --label "$label" --limit 1 --json number --jq 'length' 2>/dev/null || echo "0")
        if [ "$count" -gt 0 ]; then
            echo "已有 Issue 正在处理 ($label)，跳过"
            return 1
        fi
    done
    return 0
}

# 检查新 Issue
check_new_issue() {
    local result
    result=$(gh issue list --repo "$REPO" --state open --label "openclaw-new" --json number,title --limit 1 2>/dev/null || echo "[]")
    local count
    count=$(echo "$result" | jq 'length' 2>/dev/null || echo "0")
    if [ "$count" -eq 0 ]; then
        echo "无新 Issue"
        return 1
    fi
    
    local issue_number
    local issue_title
    issue_number=$(echo "$result" | jq -r '.[0].number')
    issue_title=$(echo "$result" | jq -r '.[0].title')
    
    echo "发现新 Issue #$issue_number: $issue_title"
    
    # 执行多 Agent 流程
    "$SCRIPT_DIR/multi-agent-run.sh" "$issue_number"
    return $?
}

# 主流程
main() {
    cd "$PROJECT_ROOT"
    
    if ! check_processing; then
        exit 0
    fi
    
    if ! check_new_issue; then
        exit 0
    fi
}

main "$@"
