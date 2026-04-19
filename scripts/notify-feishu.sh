#!/bin/bash
# 飞书通知脚本 - 支持分阶段通知
# 用法: notify-feishu.sh --project DIR --stage NAME --status STATUS
#       notify-feishu.sh "<title>" "<body>"
#
# 参数式调用 (F02, F05):
#   --project DIR      项目根目录 (默认: 脚本所在目录的父目录)
#   --stage NAME       阶段名: architect|developer|tester|reviewer
#   --status STATUS    状态: started|completed|failed
#
# 兼容性调用 (旧格式):
#   title body

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PIPELINE_PROJECT_ROOT:-$SCRIPT_DIR}"
APP_ID="cli_a922e5ddaeb8dbc3"
APP_SECRET="049enpZONlrAnf91BDMLMczIG63RaTGn"
USER_OPEN_ID="ou_716a580f47ba7c01cde66bef39fcaf11"

# 阶段名称映射 (用于通知显示)
declare -A STAGE_DISPLAY
STAGE_DISPLAY[architect]="🔵 Architect 设计"
STAGE_DISPLAY[developer]="🟢 Developer 开发"
STAGE_DISPLAY[tester]="🧪 Tester 测试"
STAGE_DISPLAY[reviewer]="🔍 Reviewer 评审"

# 状态 emoji 映射
declare -A STATUS_EMOJI
STATUS_EMOJI[started]="▶️ 开始"
STATUS_EMOJI[completed]="✅ 完成"
STATUS_EMOJI[failed]="❌ 失败"

usage() {
    cat <<EOF
用法: $0 [选项]
       $0 "<title>" "<body>"

选项:
  --project DIR    项目根目录
  --stage NAME     阶段名 (architect|developer|tester|reviewer)
  --status STATUS  状态 (started|completed|failed)
  -h, --help      显示帮助

示例:
  $0 --project /path/to/project --stage developer --status started
  $0 "Issue #85" "Architect 阶段开始"
EOF
}

# 解析参数
parse_args() {
    if [ $# -eq 0 ]; then
        return 0
    fi

    # 如果第一个参数不是以 -- 开头，认为是旧格式 (title body)
    if [[ "$1" != --* ]]; then
        LEGACY_TITLE="$1"
        LEGACY_BODY="${2:-}"
        return 0
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            --project)
                PROJECT_ROOT="$2"
                shift 2
                ;;
            --stage)
                STAGE_NAME="$2"
                shift 2
                ;;
            --status)
                STATUS="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "未知参数: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# 发送飞书通知
send_notification() {
    local title="$1"
    local body="$2"

    # 获取 tenant access token
    local token
    token=$(curl -s -X POST \
        "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
        -H "Content-Type: application/json" \
        -d "{\"app_id\": \"$APP_ID\", \"app_secret\": \"$APP_SECRET\"}" \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('tenant_access_token', ''))" 2>/dev/null || echo "")

    if [ -z "$token" ]; then
        echo "⚠️ 飞书通知: 获取 token 失败 (非致命，跳过通知)"
        return 0
    fi

    # 发送消息
    local response
    response=$(curl -s -X POST \
        "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=open_id" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{\"receive_id\": \"$USER_OPEN_ID\", \"msg_type\": \"text\", \"content\": {\"text\": \"🔔 $title\n\n$body\"}}")

    local code
    code=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code', -1))" 2>/dev/null || echo "-1")

    if [ "$code" = "0" ]; then
        echo "✅ 飞书通知已发送: $title"
    else
        echo "⚠️ 飞书通知发送失败: $response"
    fi
}

# 通知去重检查 (F04)
# 返回 0 表示应该发送通知，返回 1 表示应该跳过
should_notify() {
    local project="$1"
    local stage="$2"
    local status="$3"

    local state_file="$project/.pipeline-state/.notify_cache"
    mkdir -p "$project/.pipeline-state"

    # 生成通知 ID: stage + status
    local notify_id="${stage}_${status}"
    local timestamp
    timestamp=$(date '+%Y-%m-%dT%H:%M:%S%z')

    # 检查是否已发送过
    if [ -f "$state_file" ]; then
        local existing_ts
        existing_ts=$(grep "^${notify_id}=" "$state_file" 2>/dev/null | cut -d'=' -f2 || echo "")
        if [ -n "$existing_ts" ]; then
            # 检查是否在 1 小时内 (防止重复通知)
            local existing_epoch
            local current_epoch
            existing_epoch=$(date -d "${existing_ts}" +%s 2>/dev/null || echo 0)
            current_epoch=$(date +%s)
            local diff=$((current_epoch - existing_epoch))

            if [ "$diff" -lt 3600 ]; then
                echo "⏭️ 通知已发送过 ($notify_id at $existing_ts)，跳过"
                return 1
            fi
        fi
    fi

    # 记录本次通知
    echo "${notify_id}=${timestamp}" >> "$state_file"
    return 0
}

# 构建新格式通知内容 (F02)
build_stage_notification() {
    local project="$1"
    local stage="$2"
    local status="$3"
    local issue_num="${4:-}"

    local display_stage="${STAGE_DISPLAY[$stage]:-$stage}"
    local display_status="${STATUS_EMOJI[$status]:-$status}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    local title="${display_status} [Issue #${issue_num}] ${display_stage} 阶段"

    local body="状态: ${status}
时间: ${timestamp}
项目: ${project}
触发方式: ${TRIGGER:-manual}"

    echo "$title|$body"
}

# 主函数
main() {
    parse_args "$@"

    # 旧格式兼容
    if [ -n "${LEGACY_TITLE:-}" ]; then
        send_notification "$LEGACY_TITLE" "${LEGACY_BODY:-}"
        return
    fi

    # 新格式参数检查
    if [ -z "${PROJECT_ROOT:-}" ] || [ -z "${STAGE_NAME:-}" ] || [ -z "${STATUS:-}" ]; then
        echo "❌ 错误: 需要指定 --project, --stage, --status"
        usage
        exit 1
    fi

    # F04: 去重检查
    if ! should_notify "$PROJECT_ROOT" "$STAGE_NAME" "$STATUS"; then
        return 0
    fi

    # 构建通知内容
    local issue_num="${ISSUE_NUMBER:-}"
    local notification
    notification=$(build_stage_notification "$PROJECT_ROOT" "$STAGE_NAME" "$STATUS" "$issue_num")

    local title
    local body
    title=$(echo "$notification" | cut -d'|' -f1)
    body=$(echo "$notification" | cut -d'|' -f2)

    # 读取 ISSUE_NUMBER 从项目状态 (F05 跨项目)
    if [ -z "$issue_num" ]; then
        local state_file="$PROJECT_ROOT/.pipeline-state"/*_stage 2>/dev/null || true
        if [ -f "$state_file" ]; then
            issue_num=$(grep -o '"issue_number":[0-9]*' "$state_file" 2>/dev/null | head -1 | grep -o '[0-9]*' || echo "")
        fi
    fi
    if [ -z "$issue_num" ]; then
        issue_num="?"
    fi
    title=$(echo "$title" | sed "s/#?/#$issue_num/")

    send_notification "$title" "$body"
}

main "$@"
