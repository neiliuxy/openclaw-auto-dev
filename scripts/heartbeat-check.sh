#!/bin/bash
# OpenClaw Auto Dev - 心跳检查脚本
# 职责：扫描新 Issue + 检查 Pipeline 状态

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO="neiliuxy/openclaw-auto-dev"
STATE_DIR="$PROJECT_ROOT/.pipeline-state"
LOG_DIR="$PROJECT_ROOT/logs"

# 确保日志目录存在
mkdir -p "$LOG_DIR"

# 获取当前日期用于日志文件名
LOG_DATE=$(date '+%Y-%m-%d')
LOG_FILE="$LOG_DIR/scan-$LOG_DATE.log"

# 日志函数
log_scan() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    echo "[$level] $message"
}

# 检查是否有正在处理的 Issue
PROCESSING_LABELS="openclaw-architecting openclaw-planning openclaw-developing openclaw-testing openclaw-reviewing"
for label in $PROCESSING_LABELS; do
    count=$(gh issue list --repo "$REPO" --state open --label "$label" --limit 1 --json number --jq 'length' 2>/dev/null || echo "0")
    if [ "$count" -gt 0 ]; then
        log_scan "INFO" "已有 Issue 正在处理中 ($label)，跳过扫描"
        echo "⏳ 已有 Issue 正在处理中 ($label)，跳过"
        exit 0
    fi
done

# 检查 Pipeline 状态文件（未完成的 Issue）
if [ -d "$STATE_DIR" ] && [ "$(ls -A "$STATE_DIR" 2>/dev/null)" ]; then
    # 找到最新的状态文件
    latest_state=$(ls -t "$STATE_DIR"/*_stage 2>/dev/null | head -1)
    if [ -n "$latest_state" ]; then
        issue_num=$(basename "$latest_state" | sed 's/_stage//')
        stage=$(cat "$latest_state")
        log_scan "INFO" "检测到未完成的 Pipeline: Issue #$issue_num (stage=$stage)"
        echo "🔄 检测到未完成的 Pipeline: Issue #$issue_num (stage=$stage)"
        echo "NEED_SPAWN=true"
        echo "ISSUE_NUM=$issue_num"
        echo "CURRENT_STAGE=$stage"
        exit 0
    fi
fi

# 查询 openclaw-new Issue
result=$(gh issue list --repo "$REPO" --state open --label "openclaw-new" --json number,title --limit 1 2>/dev/null || echo "[]")
count=$(echo "$result" | jq 'length' 2>/dev/null || echo "0")

if [ "$count" -eq 0 ]; then
    log_scan "INFO" "扫描完成，无新 Issue"
    echo "✅ 无新 Issue"
    echo "STATUS=idle"
    exit 0
fi

issue_number=$(echo "$result" | jq -r '.[0].number')
issue_title=$(echo "$result" | jq -r '.[0].title')

log_scan "INFO" "发现新 Issue #$issue_number: $issue_title"
echo "🎉 发现新 Issue #$issue_number: $issue_title"
echo "STATUS=new_issue"
echo "ISSUE_NUM=$issue_number"
echo "ISSUE_TITLE=$issue_title"

# 输出 JSON 供后续使用
cat > "$PROJECT_ROOT/scan-result.json" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "status": "new_issue",
  "issue_number": "$issue_number",
  "issue_title": "$issue_title"
}
EOF

log_scan "INFO" "扫描结果已保存到 scan-result.json"

# 运行 Issue 状态清理（修复 labels 错乱等异常状态）
if [[ -f "$SCRIPT_DIR/cleanup-issue-status.sh" ]]; then
    log_scan "INFO" "运行 cleanup-issue-status.sh 进行状态检查..."
    cleanup_output=$(bash "$SCRIPT_DIR/cleanup-issue-status.sh" --dry-run 2>&1 || true)
    if echo "$cleanup_output" | grep -q "Found.*issue.*abnormal"; then
        log_scan "WARN" "发现异常 Issue 状态，需要手动处理"
        echo "$cleanup_output" >> "$LOG_FILE"
    elif echo "$cleanup_output" | grep -q "No abnormal"; then
        log_scan "INFO" "Issue 状态检查正常"
    fi
fi
