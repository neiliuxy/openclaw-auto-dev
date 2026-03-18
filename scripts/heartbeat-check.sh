#!/bin/bash
# OpenClaw Auto Dev - 心跳检查 + 自动处理脚本
# 用法：./scripts/heartbeat-check.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 错误处理函数
error_exit() {
    echo "❌ 错误：$1" >&2
    # 生成错误报告
    cat > "$PROJECT_ROOT/scan-result.json" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "status": "error",
  "message": "$1"
}
EOF
    exit 1
}

# 检查依赖
if ! command -v gh &> /dev/null; then
    error_exit "GitHub CLI (gh) 未安装"
fi

if ! command -v jq &> /dev/null; then
    error_exit "jq 未安装"
fi

# 检查 GitHub 认证
if ! gh auth status &> /dev/null; then
    error_exit "GitHub 未认证，请运行 'gh auth login'"
fi

# 执行扫描
"$SCRIPT_DIR/scan-issues.sh" || error_exit "扫描脚本执行失败"

# 检查是否有新 Issue 需要处理
if [ -f "$PROJECT_ROOT/scan-result.json" ]; then
    STATUS=$(jq -r '.status' "$PROJECT_ROOT/scan-result.json")
    ISSUE_NUMBER=$(jq -r '.issue_number // empty' "$PROJECT_ROOT/scan-result.json")
    
    if [ "$STATUS" = "new_issue" ] && [ -n "$ISSUE_NUMBER" ]; then
        echo "🚀 发现新 Issue #$ISSUE_NUMBER，开始自动处理..."
        "$SCRIPT_DIR/process-issue.sh" "$ISSUE_NUMBER"
    fi
fi

# 读取扫描结果
REPORT_FILE="$PROJECT_ROOT/scan-result.json"

if [ ! -f "$REPORT_FILE" ]; then
    echo "❌ 扫描结果文件不存在"
    exit 1
fi

# 解析结果
status=$(jq -r '.status' "$REPORT_FILE")
message=$(jq -r '.message' "$REPORT_FILE")
timestamp=$(jq -r '.timestamp' "$REPORT_FILE")
issue_number=$(jq -r '.issue_number // "null"' "$REPORT_FILE")
issue_title=$(jq -r '.issue_title // "null"' "$REPORT_FILE")

# 生成通知消息
case "$status" in
    "idle")
        echo "🔍 **OpenClaw Auto Dev 扫描完成**
        
📊 **状态**: 无新 Issue
📝 **详情**: $message
⏰ **时间**: $timestamp

✅ 系统正常运行，等待新 Issue 中..."
        ;;
    "processing")
        echo "⚠️ **OpenClaw Auto Dev 扫描完成**
        
📊 **状态**: 已有 Issue 在处理中
🔢 **Issue**: #$issue_number
📝 **标题**: $issue_title
⏰ **时间**: $timestamp

⏳ 等待当前 Issue 处理完成后再继续..."
        ;;
    "new_issue")
        echo "🎉 **OpenClaw Auto Dev 扫描完成**
        
📊 **状态**: 发现新 Issue！
🔢 **Issue**: #$issue_number
📝 **标题**: $issue_title
⏰ **时间**: $timestamp

🚀 准备开始处理..."
        ;;
    *)
        echo "🔍 **OpenClaw Auto Dev 扫描完成**
        
📊 **状态**: $status
📝 **详情**: $message
⏰ **时间**: $timestamp"
        ;;
esac
