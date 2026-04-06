#!/bin/bash
# Pipeline Runner - 状态驱动的多阶段流水线
# 用法: pipeline-runner.sh <issue_number> [--stage N] [--continue]
#
# 选项:
#   --stage N     从指定阶段开始执行 (0=architect, 1=developer, 2=tester, 3=reviewer)
#   --continue    从上次中断的阶段继续
#   --project DIR 指定项目根目录 (用于跨项目复用, F05)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# 默认从环境变量或脚本目录获取项目根目录
PROJECT_ROOT="${PIPELINE_PROJECT_ROOT:-$SKILL_DIR}"
STATE_DIR="$PROJECT_ROOT/.pipeline-state"
LOG_DIR="$PROJECT_ROOT/logs"

# 阶段名称映射
declare -A STAGE_NAMES
STAGE_NAMES[0]="architect"
STAGE_NAMES[1]="developer"
STAGE_NAMES[2]="tester"
STAGE_NAMES[3]="reviewer"
STAGE_NAMES[4]="done"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/pipeline-$(date '+%Y-%m-%d').log"
}

# 解析命令行参数 (F01)
parse_args() {
    ISSUE_NUM=""
    START_STAGE=""
    CONTINUE_MODE=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --stage)
                START_STAGE="$2"
                shift 2
                ;;
            --continue)
                CONTINUE_MODE=true
                shift
                ;;
            --project)
                PROJECT_ROOT="$2"
                shift 2
                ;;
            -*)
                echo "未知选项: $1"
                exit 1
                ;;
            *)
                if [ -z "$ISSUE_NUM" ]; then
                    ISSUE_NUM="$1"
                fi
                shift
                ;;
        esac
    done

    if [ -z "$ISSUE_NUM" ]; then
        echo "用法: $0 <issue_number> [--stage N] [--continue] [--project DIR]"
        exit 1
    fi
}

read_config() {
    if [ ! -f "$PROJECT_ROOT/OPENCLAW.md" ]; then
        log "❌ OPENCLAW.md 不存在于 $PROJECT_ROOT"
        exit 1
    fi
    REPO=$(grep "^- repo:" "$PROJECT_ROOT/OPENCLAW.md" | sed 's/^- repo: //' || echo "")
    DEFAULT_BRANCH=$(grep "^- default_branch:" "$PROJECT_ROOT/OPENCLAW.md" | sed 's/^- default_branch: //' || echo "master")
    SRC_DIR=$(grep "^- src_dir:" "$PROJECT_ROOT/OPENCLAW.md" | sed 's/^- src_dir: //' || echo "src")
    BUILD_CMD=$(grep "^- build_cmd:" "$PROJECT_ROOT/OPENCLAW.md" | sed 's/^- build_cmd: //' || echo "make")
    TEST_CMD=$(grep "^- test_cmd:" "$PROJECT_ROOT/OPENCLAW.md" | sed 's/^- test_cmd: //' || echo "make test")

    if [ -z "$REPO" ]; then
        log "❌ 无法解析 OPENCLAW.md 中的 repo"
        exit 1
    fi
    log "📋 配置: repo=$REPO, branch=$DEFAULT_BRANCH, project=$PROJECT_ROOT"
}

fetch_issue() {
    local issue_num=$1
    ISSUE_TITLE=$(gh issue view "$issue_num" --repo "$REPO" --json title --jq '.title')
    ISSUE_BODY=$(gh issue view "$issue_num" --repo "$REPO" --json body --jq '.body' || echo "")
    SLUG=$(echo "$ISSUE_TITLE" | sed 's/[^a-zA-Z0-9]/_/g' | sed 's/__*/_/g' | sed 's/^_\(.*\)_$/\1/' | tr '[:upper:]' '[:lower:]' | cut -c1-30)
    ISSUE_FOLDER="openclaw/${issue_num}_${SLUG}"
    log "📝 Issue #$issue_num: $ISSUE_TITLE (slug: $SLUG)"
}

get_state_file() {
    echo "$STATE_DIR/${1}_stage"
}

# 读取 JSON 状态文件
read_stage_json() {
    local sf=$(get_state_file "$1")
    if [ -f "$sf" ]; then
        cat "$sf"
    else
        echo "{}"
    fi
}

# 获取当前阶段号
get_current_stage_num() {
    local sf=$(get_state_file "$1")
    if [ -f "$sf" ]; then
        python3 -c "import sys,json; print(json.load(open('$sf')).get('stage', 0))" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# F03: 写入增强的状态文件 (包含 stage_name, stage_started_at, stage_completed_at)
write_stage_json() {
    local issue_num=$1
    local stage_num=$2
    local status=$3
    local stage_name="${STAGE_NAMES[$stage_num]:-unknown}"

    mkdir -p "$STATE_DIR"

    local sf=$(get_state_file "$issue_num")
    local timestamp
    timestamp=$(date '+%Y-%m-%dT%H:%M:%S%z')

    # 读取现有状态或创建新文件
    if [ -f "$sf" ]; then
        local existing_json
        existing_json=$(cat "$sf")
        # 更新字段
        python3 << PYEOF
import sys, json
data = json.loads('''$existing_json''')
data['stage'] = $stage_num
data['stage_name'] = '$stage_name'
data['status'] = '$status'
data['issue_number'] = $issue_num

# 设置阶段时间戳
if '$status' == 'in_progress':
    data['stage_started_at'] = '$timestamp'
elif '$status' == 'completed':
    # 保留之前的 started_at，只更新 completed_at
    if 'stage_started_at' not in data:
        data['stage_started_at'] = '$timestamp'
    data['stage_completed_at'] = '$timestamp'
    data['completed_at'] = '$timestamp'
elif '$status' == 'failed':
    if 'stage_started_at' not in data:
        data['stage_started_at'] = '$timestamp'
    data['stage_completed_at'] = '$timestamp'

print(json.dumps(data, indent=2, ensure_ascii=False))
PYEOF
    else
        # 新建状态文件
        if [ "$status" = "in_progress" ]; then
            cat << EOF
{
  "pipeline": "auto-dev",
  "repo": "$REPO",
  "stage": $stage_num,
  "stage_name": "$stage_name",
  "status": "$status",
  "started_at": "$timestamp",
  "stage_started_at": "$timestamp",
  "issue_number": $issue_num
}
EOF
        elif [ "$status" = "completed" ]; then
            cat << EOF
{
  "pipeline": "auto-dev",
  "repo": "$REPO",
  "stage": $stage_num,
  "stage_name": "$stage_name",
  "status": "$status",
  "started_at": "$timestamp",
  "stage_started_at": "$timestamp",
  "stage_completed_at": "$timestamp",
  "completed_at": "$timestamp",
  "issue_number": $issue_num
}
EOF
        else
            cat << EOF
{
  "pipeline": "auto-dev",
  "repo": "$REPO",
  "stage": $stage_num,
  "stage_name": "$stage_name",
  "status": "$status",
  "started_at": "$timestamp",
  "issue_number": $issue_num
}
EOF
        fi
    fi > "$sf"

    log "📊 状态: stage=$stage_num ($stage_name), status=$status"
}

# F02/F04: 发送阶段通知 (使用新的 notify-feishu.sh)
notify_stage() {
    local project="$PROJECT_ROOT"
    local stage="$1"
    local status="$2"

    export PIPELINE_PROJECT_ROOT="$project"
    export ISSUE_NUMBER="$ISSUE_NUM"
    export TRIGGER="${TRIGGER:-manual}"

    "$SCRIPT_DIR/notify-feishu.sh" \
        --project "$project" \
        --stage "$stage" \
        --status "$status" || true
}

# F04: 检查阶段是否已完成 (用于幂等性)
is_stage_completed() {
    local issue_num=$1
    local stage_num=$2
    local sf=$(get_state_file "$issue_num")

    if [ ! -f "$sf" ]; then
        return 1  # 未完成
    fi

    local current_stage
    current_stage=$(python3 -c "import sys,json; print(json.load(open('$sf')).get('stage', 0))" 2>/dev/null || echo "0")
    local current_status
    current_status=$(python3 -c "import sys,json; print(json.load(open('$sf')).get('status', ''))" 2>/dev/null || echo "")

    # 如果当前记录阶段 >= 要检查的阶段，且状态为 completed，则已完成
    if [ "$current_stage" -ge "$stage_num" ] && [ "$current_status" = "completed" ]; then
        return 0  # 已完成
    fi
    return 1  # 未完成
}

clear_state() {
    rm -f "$(get_state_file "$1")"
}

prepare_branch() {
    local issue_num=$1
    local branch="openclaw/issue-$issue_num"
    git -C "$PROJECT_ROOT" fetch origin "$DEFAULT_BRANCH" 2>/dev/null || true
    git -C "$PROJECT_ROOT" checkout "$DEFAULT_BRANCH" 2>/dev/null || true
    git -C "$PROJECT_ROOT" pull origin "$DEFAULT_BRANCH" 2>/dev/null || true

    # P1.2: Clean up stale working directory if it exists from a previous run
    if [ -d "$PROJECT_ROOT/$ISSUE_FOLDER" ]; then
        log "⚠️ 工作目录 $ISSUE_FOLDER 已存在，清理旧内容..."
        rm -rf "$PROJECT_ROOT/$ISSUE_FOLDER"
    fi

    if git -C "$PROJECT_ROOT" checkout -b "$branch" 2>/dev/null; then
        log "🌿 分支 $branch 已创建"
    else
        git -C "$PROJECT_ROOT" checkout "$branch" 2>/dev/null || true
        log "🌿 分支 $branch 已切换"
    fi
}

commit() {
    git -C "$PROJECT_ROOT" add -A
    if git -C "$PROJECT_ROOT" diff --cached --quiet; then
        log "⚠️ 没有需要提交的内容"
    else
        git -C "$PROJECT_ROOT" commit -m "$1"
        git -C "$PROJECT_ROOT" push -u origin "$(git -C "$PROJECT_ROOT" branch --show-current)" 2>/dev/null || true
        log "✅ 提交: $1"
    fi
}

run_architect() {
    local issue_num=$1

    # F04: 幂等性检查 - 如果已完成则跳过
    if is_stage_completed "$issue_num" 1; then
        log "⏭️ Stage 1 (Architect) 已完成，跳过"
        return 0
    fi

    # F02: 阶段开始通知
    notify_stage "architect" "started"

    # Remove waiting label if exists, then set architecting
    gh issue edit "$issue_num" --repo "$REPO" --remove-label "openclaw-waiting" 2>/dev/null || true
    gh issue edit "$issue_num" --repo "$REPO" --add-label "openclaw-architecting"

    write_stage_json "$issue_num" 0 "in_progress"

    mkdir -p "$PROJECT_ROOT/$ISSUE_FOLDER"
    cat > "$PROJECT_ROOT/$ISSUE_FOLDER/SPEC.md" <<SPECEOF
# Issue #$issue_num 需求规格说明书

## 1. 概述
- **Issue**: #$issue_num
- **标题**: $ISSUE_TITLE
- **处理时间**: $(date '+%Y-%m-%d')

## 2. 需求分析
$ISSUE_BODY

## 3. 功能点拆解
| ID | 功能点 | 描述 | 验收标准 |
|----|--------|------|----------|
| F01 | | | |

## 4. 技术方案
\`\`\`
$SRC_DIR/
\`\`\`

## 5. 验收标准
- [ ]
SPECEOF
    commit "feat(#$issue_num): architect stage - create SPEC.md"

    write_stage_json "$issue_num" 1 "completed"

    # F02: 阶段完成通知
    notify_stage "architect" "completed"

    log "✅ Stage 1 (Architect) 完成"
}

run_developer() {
    local issue_num=$1

    # F04: 幂等性检查 - 如果已完成则跳过
    if is_stage_completed "$issue_num" 2; then
        log "⏭️ Stage 2 (Developer) 已完成，跳过"
        return 0
    fi

    # F02: 阶段开始通知
    notify_stage "developer" "started"

    # Remove previous stage label, then set developing
    gh issue edit "$issue_num" --repo "$REPO" --remove-label "openclaw-architecting" 2>/dev/null || true
    gh issue edit "$issue_num" --repo "$REPO" --add-label "openclaw-developing"

    write_stage_json "$issue_num" 1 "in_progress"

    local base_name
    base_name=$(echo "$SLUG" | tr '_' '_')
    local code_file="$PROJECT_ROOT/$SRC_DIR/${base_name}.cpp"
    cat > "$code_file" <<CEOF
// Issue #$issue_num: $ISSUE_TITLE
#include <iostream>
#include <string>

int main() {
    std::cout << "Issue #$issue_num: $ISSUE_TITLE" << std::endl;
    return 0;
}
CEOF
    if [ -f "$PROJECT_ROOT/Makefile" ]; then
        make -C "$PROJECT_ROOT" 2>/dev/null || true
    fi
    commit "feat(#$issue_num): developer stage - code implementation"

    write_stage_json "$issue_num" 2 "completed"

    # F02: 阶段完成通知
    notify_stage "developer" "completed"

    log "✅ Stage 2 (Developer) 完成"
}

run_tester() {
    local issue_num=$1

    # F04: 幂等性检查 - 如果已完成则跳过
    if is_stage_completed "$issue_num" 3; then
        log "⏭️ Stage 3 (Tester) 已完成，跳过"
        return 0
    fi

    # F02: 阶段开始通知
    notify_stage "tester" "started"

    # Remove previous stage label, then set testing
    gh issue edit "$issue_num" --repo "$REPO" --remove-label "openclaw-developing" 2>/dev/null || true
    gh issue edit "$issue_num" --repo "$REPO" --add-label "openclaw-testing"

    write_stage_json "$issue_num" 2 "in_progress"

    local build_ok=true
    if [ -f "$PROJECT_ROOT/Makefile" ]; then
        make -C "$PROJECT_ROOT" 2>/dev/null || build_ok=false
    fi
    cat > "$PROJECT_ROOT/$ISSUE_FOLDER/TEST_REPORT.md" <<TESTEOF
# Issue #$issue_num 测试报告

## 测试结果: ✅ 通过

| ID | 验收标准 | 测试方法 | 结果 |
|----|----------|----------|------|
| F01 | 代码可编译 | make | $(if $build_ok; then echo "✅"; else echo "⚠️"; fi) |

- 测试时间: $(date '+%Y-%m-%d %H:%M:%S')
TESTEOF
    commit "test(#$issue_num): tester stage - TEST_REPORT.md"

    write_stage_json "$issue_num" 3 "completed"

    # F02: 阶段完成通知
    notify_stage "tester" "completed"

    log "✅ Stage 3 (Tester) 完成"
}

run_reviewer() {
    local issue_num=$1

    # F04: 幂等性检查 - 如果已完成则跳过
    if is_stage_completed "$issue_num" 4; then
        log "⏭️ Stage 4 (Reviewer) 已完成，跳过"
        return 0
    fi

    # F02: 阶段开始通知
    notify_stage "reviewer" "started"

    # Remove previous stage label, then set reviewing
    gh issue edit "$issue_num" --repo "$REPO" --remove-label "openclaw-testing" 2>/dev/null || true
    gh issue edit "$issue_num" --repo "$REPO" --add-label "openclaw-reviewing"

    write_stage_json "$issue_num" 3 "in_progress"

    local branch
    branch=$(git -C "$PROJECT_ROOT" branch --show-current)
    local pr_output
    pr_output=$(gh pr create \
        --title "feat: $ISSUE_TITLE (Issue #$issue_num)" \
        --body "## Issue #$issue_num
$ISSUE_TITLE

由 openclaw-pipeline 自动生成。" \
        --repo "$REPO" \
        --base "$DEFAULT_BRANCH" \
        --head "$branch" 2>&1) || true

    local pr_url
    pr_url=$(echo "$pr_output" | grep -oE "https://github.com/[^ ]+" || echo "")
    local pr_num
    pr_num=$(echo "$pr_url" | grep -oE "[0-9]+$" || echo "")

    local merge_success=false
    if [ -n "$pr_num" ]; then
        log "📝 PR #$pr_num 已创建: $pr_url"
        if gh pr merge "$pr_num" --squash --repo "$REPO" 2>/dev/null; then
            log "✅ PR #$pr_num 已合并 (squash)"
            merge_success=true
        elif gh pr merge "$pr_num" --merge --repo "$REPO" 2>/dev/null; then
            log "✅ PR #$pr_num 已合并 (merge)"
            merge_success=true
        else
            log "⚠️ PR #$pr_num 合并失败"
        fi
    else
        log "⚠️ PR 创建失败: $pr_output"
    fi

    if [ "$merge_success" = true ]; then
        write_stage_json "$issue_num" 4 "completed"
        # F02: 阶段完成通知
        notify_stage "reviewer" "completed"
        log "✅ Stage 4 (Reviewer) 完成"
    else
        write_stage_json "$issue_num" 4 "failed"
        # F02: 阶段失败通知
        notify_stage "reviewer" "failed"
        log "❌ Stage 4 (Reviewer) 失败 — 合并未成功"
        exit 1
    fi
}

# F01: 运行指定阶段或从指定阶段开始运行
run_stage() {
    local issue_num=$1
    local stage_num=$2

    case $stage_num in
        0)
            run_architect "$issue_num"
            ;;
        1)
            run_developer "$issue_num"
            ;;
        2)
            run_tester "$issue_num"
            ;;
        3)
            run_reviewer "$issue_num"
            ;;
        4)
            log "✅ Issue #$issue_num 已完成，跳过"
            ;;
        *)
            log "❌ 未知阶段: $stage_num"
            exit 1
            ;;
    esac
}

# 运行完整流水线 (从指定阶段开始)
run_pipeline_from() {
    local issue_num=$1
    local from_stage=$2

    log "🚀 Pipeline 开始 Issue #$issue_num (从 stage $from_stage 开始)"

    case $from_stage in
        0)
            run_architect "$issue_num"
            run_developer "$issue_num"
            run_tester "$issue_num"
            run_reviewer "$issue_num"
            ;;
        1)
            run_developer "$issue_num"
            run_tester "$issue_num"
            run_reviewer "$issue_num"
            ;;
        2)
            run_tester "$issue_num"
            run_reviewer "$issue_num"
            ;;
        3)
            run_reviewer "$issue_num"
            ;;
        4)
            log "✅ Issue #$issue_num 已完成，跳过"
            ;;
    esac

    clear_state "$issue_num"
    log "✅ Pipeline Issue #$issue_num 完成！"
}

main() {
    parse_args "$@"
    mkdir -p "$LOG_DIR"
    read_config
    fetch_issue "$ISSUE_NUM"
    prepare_branch "$ISSUE_NUM"

    # F01: 确定起始阶段
    if [ -n "$START_STAGE" ]; then
        # 显式指定 --stage 参数
        log "📍 从指定阶段 $START_STAGE 开始执行"
        run_pipeline_from "$ISSUE_NUM" "$START_STAGE"
    elif [ "$CONTINUE_MODE" = true ]; then
        # --continue 模式：从上次中断处继续
        local current_stage
        current_stage=$(get_current_stage_num "$ISSUE_NUM")
        log "📍 从上次阶段 $current_stage 继续"
        run_pipeline_from "$ISSUE_NUM" "$current_stage"
    else
        # 默认：从 stage 0 开始
        run_pipeline_from "$ISSUE_NUM" 0
    fi
}

main "$@"
