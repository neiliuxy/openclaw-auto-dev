#!/bin/bash
# OpenClaw Auto Dev - 心跳检查脚本
# 职责：扫描新 Issue → 发现则触发 pipeline-runner.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO="neiliuxy/openclaw-auto-dev"

# 检查是否有正在处理的 Issue
PROCESSING_LABELS="openclaw-architecting openclaw-planning openclaw-developing openclaw-testing openclaw-reviewing"
for label in $PROCESSING_LABELS; do
    count=$(gh issue list --repo "$REPO" --state open --label "$label" --limit 1 --json number --jq 'length' 2>/dev/null || echo "0")
    if [ "$count" -gt 0 ]; then
        echo "⏳ 已有 Issue 正在处理中 ($label)，跳过"
        exit 0
    fi
done

# 查询 openclaw-new Issue
result=$(gh issue list --repo "$REPO" --state open --label "openclaw-new" --json number,title --limit 1 2>/dev/null || echo "[]")
count=$(echo "$result" | jq 'length' 2>/dev/null || echo "0")

if [ "$count" -eq 0 ]; then
    echo "✅ 无新 Issue"
    exit 0
fi

issue_number=$(echo "$result" | jq -r '.[0].number')
issue_title=$(echo "$result" | jq -r '.[0].title')

echo "🎉 发现新 Issue #$issue_number: $issue_title"

# 输出 JSON 供后续使用
cat > "$PROJECT_ROOT/scan-result.json" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "status": "new_issue",
  "issue_number": "$issue_number",
  "issue_title": "$issue_title"
}
EOF

echo "📡 请手动调用: pipeline-runner.sh $issue_number"
echo "   或通过 sessions_spawn 触发"
