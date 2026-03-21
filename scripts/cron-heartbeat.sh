#!/bin/bash
# OpenClaw Auto Dev - 定时心跳检查（cron 专用）
# 用法：./scripts/cron-heartbeat.sh
# 职责：扫描新 Issue → 发现则触发 Multi-Agent 四角色流程

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPORT_FILE="$PROJECT_ROOT/scan-result.json"
LOG_FILE="$PROJECT_ROOT/logs/cron-heartbeat.log"

mkdir -p "$PROJECT_ROOT/logs"

# 执行扫描
"$SCRIPT_DIR/scan-issues.sh"

# 读取扫描结果
if [ ! -f "$REPORT_FILE" ]; then
    echo "❌ 扫描失败：结果文件不存在" >> "$PROJECT_ROOT/logs/cron-error.log"
    exit 1
fi

# 解析结果
status=$(jq -r '.status' "$REPORT_FILE")
message=$(jq -r '.message' "$REPORT_FILE")
timestamp=$(jq -r '.timestamp' "$REPORT_FILE")
issue_number=$(jq -r '.issue_number // "null"' "$REPORT_FILE")
issue_title=$(jq -r '.issue_title // "null"' "$REPORT_FILE")

# 写入报告文件
cat > "$PROJECT_ROOT/cron-report.md" <<EOF
## 🔍 OpenClaw Auto Dev Issue 扫描结果

**扫描时间**: $timestamp

| 项目 | 状态 |
|------|------|
| 📊 **状态** | $status |
| 📝 **详情** | $message |
EOF

if [ "$issue_number" != "null" ]; then
    cat >> "$PROJECT_ROOT/cron-report.md" <<EOF
| 🔢 **Issue 编号** | #$issue_number |
| 📝 **Issue 标题** | $issue_title |
EOF
fi

cat >> "$PROJECT_ROOT/cron-report.md" <<EOF

---

**系统状态**: $([ "$status" = "idle" ] && echo "✅ 正常运行" || echo "⚠️ 有任务进行中")
EOF

echo "[$timestamp] 扫描完成：$status - $message" >> "$LOG_FILE"

# 发现新 Issue → 触发 Multi-Agent 四角色流程
if [ "$status" = "new_issue" ] && [ "$issue_number" != "null" ]; then
    echo "[$timestamp] 🎯 发现新 Issue #$issue_number，开始 Multi-Agent 流程..." >> "$LOG_FILE"
    "$SCRIPT_DIR/multi-agent-run.sh" "$issue_number" >> "$LOG_FILE" 2>&1
fi
