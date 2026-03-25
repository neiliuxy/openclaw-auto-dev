#!/bin/bash
# OpenClaw Auto Dev - 定时心跳检查（cron 专用）
# 用法：./scripts/cron-heartbeat.sh
# 职责：扫描新 Issue → 发现则触发 Pipeline

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPORT_FILE="$PROJECT_ROOT/scan-result.json"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/cron-heartbeat.log"
ERROR_LOG="$LOG_DIR/cron-error.log"
PIPELINE_RUNNER="$HOME/.openclaw/workspace/skills/openclaw-pipeline/pipeline-runner.sh"

# 日志轮转配置
MAX_LOG_SIZE=5242880  # 5MB
MAX_LOG_FILES=5       # 保留最近5个轮转日志

mkdir -p "$LOG_DIR"

# 日志轮转函数：超过 MAX_LOG_SIZE 则轮转
rotate_log() {
    local logfile="$1"
    if [ ! -f "$logfile" ]; then return; fi
    
    local size=$(stat -c%s "$logfile" 2>/dev/null || stat -f%z "$logfile" 2>/dev/null || echo 0)
    if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
        # 轮转日志：移动旧日志为 .1, .2, ...
        for i in $(seq $((MAX_LOG_FILES - 1)) -1 1); do
            if [ -f "${logfile}.${i}" ]; then
                mv "${logfile}.${i}" "${logfile}.$((i + 1))"
            fi
        done
        mv "$logfile" "${logfile}.1"
        # 创建新的空日志文件
        touch "$logfile"
    fi
}

# 执行日志轮转
rotate_log "$LOG_FILE"
rotate_log "$ERROR_LOG"

# 执行扫描
"$SCRIPT_DIR/scan-issues.sh"

# 读取扫描结果
if [ ! -f "$REPORT_FILE" ]; then
    echo "❌ 扫描失败：结果文件不存在" >> "$ERROR_LOG"
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

# 发现新 Issue → 触发 Pipeline
if [ "$status" = "new_issue" ] && [ "$issue_number" != "null" ]; then
    echo "[$timestamp] 🎯 发现新 Issue #$issue_number，开始 Pipeline..." >> "$LOG_FILE"
    PIPELINE_PROJECT_ROOT="$PROJECT_ROOT" bash "$PIPELINE_RUNNER" "$issue_number" >> "$LOG_FILE" 2>&1
fi
