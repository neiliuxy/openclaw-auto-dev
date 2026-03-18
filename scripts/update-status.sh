#!/bin/bash
# 状态更新工具脚本
# 用法：./scripts/update-status.sh <issue_number> <new_status>

set -e

ISSUE_NUMBER=$1
NEW_STATUS=$2

if [ -z "$ISSUE_NUMBER" ] || [ -z "$NEW_STATUS" ]; then
    echo "用法：$0 <issue_number> <new_status>"
    echo "状态选项：new, processing, pr-created, completed, error"
    exit 1
fi

case $NEW_STATUS in
    new)
        LABEL="openclaw-new"
        ;;
    processing)
        LABEL="openclaw-processing"
        ;;
    pr-created)
        LABEL="openclaw-pr-created"
        ;;
    completed)
        LABEL="openclaw-completed"
        ;;
    error)
        LABEL="openclaw-error"
        ;;
    *)
        echo "❌ 未知状态：$NEW_STATUS"
        exit 1
        ;;
esac

echo "🔄 更新 Issue #$ISSUE_NUMBER 状态为 $LABEL..."

# 移除所有 openclaw 相关标签
gh issue edit "$ISSUE_NUMBER" --remove-label "openclaw-new" 2>/dev/null || true
gh issue edit "$ISSUE_NUMBER" --remove-label "openclaw-processing" 2>/dev/null || true
gh issue edit "$ISSUE_NUMBER" --remove-label "openclaw-pr-created" 2>/dev/null || true
gh issue edit "$ISSUE_NUMBER" --remove-label "openclaw-completed" 2>/dev/null || true
gh issue edit "$ISSUE_NUMBER" --remove-label "openclaw-error" 2>/dev/null || true

# 添加新标签
gh issue edit "$ISSUE_NUMBER" --add-label "$LABEL"

echo "✅ 状态更新成功"
