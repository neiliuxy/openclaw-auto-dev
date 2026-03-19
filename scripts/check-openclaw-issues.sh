#!/bin/bash
# check-openclaw-issues.sh - 每 30 分钟检查新的 openclaw-new 标签 issue

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
LOG_FILE="$PROJECT_ROOT/logs/issue-check.log"
STATE_FILE="$PROJECT_ROOT/.validation/last-checked-issue.json"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] $1" | tee -a "$LOG_FILE"
}

log_info() { log "${GREEN}[INFO]${NC} $1"; }
log_warn() { log "${YELLOW}[WARN]${NC} $1"; }
log_error() { log "${RED}[ERROR]${NC} $1"; }
log_step() { log "${BLUE}[STEP]${NC} $1"; }

# 确保目录存在
mkdir -p "$PROJECT_ROOT/logs"
mkdir -p "$PROJECT_ROOT/.validation"

# 初始化状态文件
if [ ! -f "$STATE_FILE" ]; then
    echo '{"lastChecked": 0, "processedIssues": []}' > "$STATE_FILE"
fi

log_step "=========================================="
log_step "开始检查 openclaw-new 标签 issue"
log_step "=========================================="

cd "$PROJECT_ROOT"

# 获取当前仓库
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
log_info "仓库：$REPO"

# 获取所有 open 状态且带有 openclaw-new 标签的 issue
log_info "查询 GitHub Issues..."
issues=$(gh issue list --label "openclaw-new" --state open --json number,title,createdAt,author,url --limit 20)

if [ -z "$issues" ] || [ "$issues" = "[]" ]; then
    log_info "✅ 没有新的 openclaw-new 标签 issue"
    exit 0
fi

# 解析 issue 数量
issue_count=$(echo "$issues" | jq 'length')
log_info "发现 $issue_count 个 openclaw-new 标签 issue"

# 遍历每个 issue
echo "$issues" | jq -c '.[]' | while read -r issue; do
    issue_num=$(echo "$issue" | jq -r '.number')
    issue_title=$(echo "$issue" | jq -r '.title')
    issue_author=$(echo "$issue" | jq -r '.author.login')
    issue_url=$(echo "$issue" | jq -r '.url')
    created_at=$(echo "$issue" | jq -r '.createdAt')
    
    log_step "----------------------------------------"
    log_info "Issue #$issue_num: $issue_title"
    log_info "作者：$issue_author | 创建时间：$created_at"
    log_info "URL: $issue_url"
    
    # 检查是否已经处理过
    processed=$(cat "$STATE_FILE" | jq ".processedIssues | index($issue_num)")
    if [ "$processed" != "null" ]; then
        log_warn "⚠️ Issue #$issue_num 已经在处理中，跳过"
        continue
    fi
    
    # 标记为已发现
    log_info "📝 记录 Issue #$issue_num 为待处理"
    
    # 更新状态文件
    current=$(cat "$STATE_FILE")
    echo "$current" | jq ".processedIssues += [$issue_num] | .lastChecked = $(date +%s)" > "$STATE_FILE"
    
    # 可以在这里触发自动处理
    # 例如：调用 process-issue.sh 脚本
    # ./scripts/process-issue.sh $issue_num
    
    log_info "✅ Issue #$issue_num 已记录"
done

log_step "=========================================="
log_info "检查完成！"
log_step "=========================================="

# 输出摘要
echo ""
echo "📊 摘要:"
echo "   发现 issue 数：$issue_count"
echo "   检查时间：$(date)"
echo "   状态文件：$STATE_FILE"
echo ""
