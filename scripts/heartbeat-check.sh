#!/bin/bash
# OpenClaw Auto Dev - 心跳检查 + 通知脚本
# 用法：./scripts/heartbeat-check.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 执行扫描
"$SCRIPT_DIR/scan-issues.sh"

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
