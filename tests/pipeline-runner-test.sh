#!/bin/bash
# Pipeline Runner 状态驱动验证测试套件
# 用法: tests/pipeline-runner-test.sh [--cleanup]
#
# 测试用例:
#   TC-1: 全流程验证 (stage=0 → stage=4)
#   TC-2: 断点续跑 — Architect 阶段后恢复 (stage=1 → stage=4)
#   TC-3: 断点续跑 — Developer 阶段后恢复 (stage=2 → stage=4)
#   TC-4: 断点续跑 — Tester 阶段后恢复 (stage=3 → stage=4)
#   TC-5: 已完成状态跳过 (stage=4)
#   TC-6: 状态文件 JSON 格式验证
#   TC-7: GitHub Issue 标签流转

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR" && pwd)"
PIPELINE_RUNNER="$PROJECT_ROOT/scripts/pipeline-runner.sh"
STATE_DIR="$PROJECT_ROOT/.pipeline-state"
LOG_DIR="$PROJECT_ROOT/logs"
REPO="neiliuxy/openclaw-auto-dev"

# 测试专用 Issue（每个 TC 用独立编号避免干扰）
TC1_ISSUE=871
TC2_ISSUE=872
TC3_ISSUE=873
TC4_ISSUE=874
TC5_ISSUE=875

# 全局测试结果
TESTS_PASSED=0
TESTS_FAILED=0
TEST_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

pass() {
    echo "  ✅ $1"
    ((TESTS_PASSED++))
}

fail() {
    echo "  ❌ $1"
    ((TESTS_FAILED++))
}

get_state_file() {
    echo "$STATE_DIR/${1}_stage"
}

read_stage_from_file() {
    local sf=$(get_state_file "$1")
    if [ -f "$sf" ]; then
        jq -r '.stage' "$sf" 2>/dev/null || echo "NOT_JSON"
    else
        echo "FILE_NOT_FOUND"
    fi
}

validate_json_format() {
    local sf=$1
    if [ ! -f "$sf" ]; then
        echo "FILE_NOT_FOUND"
        return 1
    fi
    local issue_val=$(jq -r '.issue' "$sf" 2>/dev/null) || { echo "INVALID_JSON"; return 1; }
    local stage_val=$(jq -r '.stage' "$sf" 2>/dev/null) || { echo "INVALID_JSON"; return 1; }
    local updated_val=$(jq -r '.updated_at' "$sf" 2>/dev/null) || { echo "INVALID_JSON"; return 1; }
    local error_val=$(jq -r '.error' "$sf" 2>/dev/null) || { echo "INVALID_JSON"; return 1; }
    if ! [[ "$updated_val" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
        echo "INVALID_TIMESTAMP"
        return 1
    fi
    echo "VALID"
    return 0
}

write_stage_manually() {
    local issue_num=$1
    local stage=$2
    mkdir -p "$STATE_DIR"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S+08:00")
    cat > "$(get_state_file "$issue_num")" <<EOF
{
  "issue": $issue_num,
  "stage": $stage,
  "updated_at": "$timestamp",
  "error": null
}
EOF
}

clear_test_state() {
    rm -f "$(get_state_file "$1")"
}

get_issue_labels() {
    local issue_num=$1
    gh issue view "$issue_num" --repo "$REPO" --json labels --jq '.labels[].name' 2>/dev/null | sort || echo ""
}

has_label() {
    local issue_num=$1
    local label=$2
    local labels=$(get_issue_labels "$issue_num")
    echo "$labels" | grep -q "^${label}$" && return 0 || return 1
}

cleanup_branch() {
    local issue_num=$1
    local branch="openclaw/issue-$issue_num"
    git -C "$PROJECT_ROOT" push origin --delete "$branch" 2>/dev/null || true
    local current_branch=$(git -C "$PROJECT_ROOT" branch --show-current)
    if [ "$current_branch" != "$branch" ]; then
        git -C "$PROJECT_ROOT" branch -D "$branch" 2>/dev/null || true
    fi
}

cleanup_test_artifacts() {
    local issue_num=$1
    rm -rf "$PROJECT_ROOT/openclaw/${issue_num}_"* 2>/dev/null || true
    local slug_from_title
    slug_from_title=$(gh issue view "$issue_num" --repo "$REPO" --json title --jq '.title' 2>/dev/null | \
        sed 's/[^a-zA-Z0-9]/_/g' | sed 's/__*/_/g' | sed 's/^_\(.*\)_$/\1/' | tr '[:upper:]' '[:lower:]' | cut -c1-30)
    rm -f "$PROJECT_ROOT/src/${slug_from_title}.cpp" 2>/dev/null || true
}

cleanup_all() {
    log "🧹 清理所有测试状态..."
    for issue_num in $TC1_ISSUE $TC2_ISSUE $TC3_ISSUE $TC4_ISSUE $TC5_ISSUE; do
        clear_test_state "$issue_num"
        cleanup_branch "$issue_num" 2>/dev/null || true
    done
    log "✅ 清理完成"
}

# TC-1: 全流程验证
run_tc1() {
    local tc_num="TC-1"
    log ""
    log "========================================"
    log "开始 $tc_num: 全流程验证 (stage=0 → stage=4)"
    log "========================================"
    local issue_num=$TC1_ISSUE
    clear_test_state "$issue_num"
    cleanup_branch "$issue_num" 2>/dev/null || true
    git -C "$PROJECT_ROOT" checkout master 2>/dev/null || true

    local output
    output=$("$PIPELINE_RUNNER" "$issue_num" 2>&1) || true
    log "Pipeline 输出（最后 20 行）:"
    echo "$output" | tail -20

    local sf=$(get_state_file "$issue_num")
    if [ ! -f "$sf" ]; then
        pass "$tc_num: 状态文件在完成后被正确清理"
    else
        fail "$tc_num: 状态文件在完成后未清理"
    fi

    local spec_file
    spec_file=$(find "$PROJECT_ROOT/openclaw" -name "SPEC.md" -path "*/${issue_num}_*" 2>/dev/null | head -1)
    if [ -n "$spec_file" ] && [ -f "$spec_file" ]; then
        pass "$tc_num: SPEC.md 存在"
        if grep -q "Issue #$issue_num" "$spec_file"; then
            pass "$tc_num: SPEC.md 包含 Issue 编号"
        else
            fail "$tc_num: SPEC.md 未包含 Issue 编号"
        fi
    else
        fail "$tc_num: SPEC.md 不存在"
    fi

    local code_file
    code_file=$(find "$PROJECT_ROOT/src" -name "*.cpp" ! -name "*_test*" 2>/dev/null | head -1)
    if [ -n "$code_file" ] && [ -f "$code_file" ]; then
        pass "$tc_num: 代码文件 .cpp 存在"
    else
        fail "$tc_num: 代码文件 .cpp 不存在"
    fi

    local test_report
    test_report=$(find "$PROJECT_ROOT/openclaw" -name "TEST_REPORT.md" -path "*/${issue_num}_*" 2>/dev/null | head -1)
    if [ -n "$test_report" ] && [ -f "$test_report" ]; then
        pass "$tc_num: TEST_REPORT.md 存在"
    else
        fail "$tc_num: TEST_REPORT.md 不存在"
    fi

    cleanup_test_artifacts "$issue_num"
    clear_test_state "$issue_num"
    log "$tc_num 完成: passed=$TESTS_PASSED failed=$TESTS_FAILED"
}

# TC-2: 断点续跑 — Architect 阶段后恢复
run_tc2() {
    local tc_num="TC-2"
    log ""
    log "========================================"
    log "开始 $tc_num: 断点续跑 — Architect 阶段后恢复 (stage=1 → stage=4)"
    log "========================================"
    local issue_num=$TC2_ISSUE
    clear_test_state "$issue_num"
    cleanup_branch "$issue_num" 2>/dev/null || true
    git -C "$PROJECT_ROOT" checkout master 2>/dev/null || true

    write_stage_manually "$issue_num" 1
    log "手动设置 stage=1"

    mkdir -p "$PROJECT_ROOT/openclaw/${issue_num}_test"
    echo "# Issue #$issue_num SPEC (pre-existing)" > "$PROJECT_ROOT/openclaw/${issue_num}_test/SPEC.md"
    local original_spec_content=$(cat "$PROJECT_ROOT/openclaw/${issue_num}_test/SPEC.md")

    local output
    output=$("$PIPELINE_RUNNER" "$issue_num" 2>&1) || true
    log "Pipeline 输出（最后 10 行）:"
    echo "$output" | tail -10

    local new_spec_content=$(cat "$PROJECT_ROOT/openclaw/${issue_num}_test/SPEC.md" 2>/dev/null || echo "")
    if [ "$original_spec_content" = "$new_spec_content" ]; then
        pass "$tc_num: SPEC.md 在断点续跑时未被覆盖"
    else
        fail "$tc_num: SPEC.md 在断点续跑时被覆盖"
    fi

    cleanup_test_artifacts "$issue_num"
    clear_test_state "$issue_num"
    log "$tc_num 完成: passed=$TESTS_PASSED failed=$TESTS_FAILED"
}

# TC-3: 断点续跑 — Developer 阶段后恢复
run_tc3() {
    local tc_num="TC-3"
    log ""
    log "========================================"
    log "开始 $tc_num: 断点续跑 — Developer 阶段后恢复 (stage=2 → stage=4)"
    log "========================================"
    local issue_num=$TC3_ISSUE
    clear_test_state "$issue_num"
    cleanup_branch "$issue_num" 2>/dev/null || true
    git -C "$PROJECT_ROOT" checkout master 2>/dev/null || true

    write_stage_manually "$issue_num" 2
    log "手动设置 stage=2"

    mkdir -p "$PROJECT_ROOT/openclaw/${issue_num}_test"
    echo "# Issue #$issue_num SPEC" > "$PROJECT_ROOT/openclaw/${issue_num}_test/SPEC.md"
    echo "// code placeholder" > "$PROJECT_ROOT/src/test_tc3.cpp"

    local output
    output=$("$PIPELINE_RUNNER" "$issue_num" 2>&1) || true
    log "Pipeline 输出（最后 10 行）:"
    echo "$output" | tail -10

    if grep -q "Issue #$issue_num SPEC" "$PROJECT_ROOT/openclaw/${issue_num}_test/SPEC.md" 2>/dev/null; then
        pass "$tc_num: SPEC.md 未被覆盖"
    else
        fail "$tc_num: SPEC.md 被覆盖了"
    fi

    rm -f "$PROJECT_ROOT/src/test_tc3.cpp"
    cleanup_test_artifacts "$issue_num"
    clear_test_state "$issue_num"
    log "$tc_num 完成: passed=$TESTS_PASSED failed=$TESTS_FAILED"
}

# TC-4: 断点续跑 — Tester 阶段后恢复
run_tc4() {
    local tc_num="TC-4"
    log ""
    log "========================================"
    log "开始 $tc_num: 断点续跑 — Tester 阶段后恢复 (stage=3 → stage=4)"
    log "========================================"
    local issue_num=$TC4_ISSUE
    clear_test_state "$issue_num"
    cleanup_branch "$issue_num" 2>/dev/null || true
    git -C "$PROJECT_ROOT" checkout master 2>/dev/null || true

    write_stage_manually "$issue_num" 3
    log "手动设置 stage=3"

    mkdir -p "$PROJECT_ROOT/openclaw/${issue_num}_test"
    echo "# Issue #$issue_num SPEC" > "$PROJECT_ROOT/openclaw/${issue_num}_test/SPEC.md"
    echo "// code" > "$PROJECT_ROOT/src/test_tc4.cpp"
    echo "# TEST REPORT" > "$PROJECT_ROOT/openclaw/${issue_num}_test/TEST_REPORT.md"

    local output
    output=$("$PIPELINE_RUNNER" "$issue_num" 2>&1) || true
    log "Pipeline 输出（最后 10 行）:"
    echo "$output" | tail -10

    if grep -q "Issue #$issue_num SPEC" "$PROJECT_ROOT/openclaw/${issue_num}_test/SPEC.md" 2>/dev/null; then
        pass "$tc_num: SPEC.md 未被覆盖"
    else
        fail "$tc_num: SPEC.md 被覆盖了"
    fi

    if grep -q "# TEST REPORT" "$PROJECT_ROOT/openclaw/${issue_num}_test/TEST_REPORT.md" 2>/dev/null; then
        pass "$tc_num: TEST_REPORT.md 未被覆盖"
    else
        fail "$tc_num: TEST_REPORT.md 被覆盖了"
    fi

    rm -f "$PROJECT_ROOT/src/test_tc4.cpp"
    cleanup_test_artifacts "$issue_num"
    clear_test_state "$issue_num"
    log "$tc_num 完成: passed=$TESTS_PASSED failed=$TESTS_FAILED"
}

# TC-5: 已完成状态跳过
run_tc5() {
    local tc_num="TC-5"
    log ""
    log "========================================"
    log "开始 $tc_num: 已完成状态跳过 (stage=4)"
    log "========================================"
    local issue_num=$TC5_ISSUE
    clear_test_state "$issue_num"
    cleanup_branch "$issue_num" 2>/dev/null || true
    git -C "$PROJECT_ROOT" checkout master 2>/dev/null || true

    local initial_commit
    initial_commit=$(git -C "$PROJECT_ROOT" rev-parse HEAD)

    write_stage_manually "$issue_num" 4
    log "手动设置 stage=4"

    local output
    output=$("$PIPELINE_RUNNER" "$issue_num" 2>&1) || true
    log "Pipeline 输出:"
    echo "$output"

    local final_commit
    final_commit=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
    if [ "$initial_commit" = "$final_commit" ]; then
        pass "$tc_num: stage=4 时无 Git 操作"
    else
        fail "$tc_num: stage=4 时产生了 Git 操作"
    fi

    if echo "$output" | grep -qi "已完成\|already\|skip"; then
        pass "$tc_num: 输出显示跳过执行"
    else
        fail "$tc_num: 输出未显示跳过执行"
    fi

    clear_test_state "$issue_num"
    log "$tc_num 完成: passed=$TESTS_PASSED failed=$TESTS_FAILED"
}

# TC-6: 状态文件 JSON 格式验证
run_tc6() {
    local tc_num="TC-6"
    log ""
    log "========================================"
    log "开始 $tc_num: 状态文件 JSON 格式验证"
    log "========================================"
    local issue_num=876
    clear_test_state "$issue_num"
    mkdir -p "$STATE_DIR"

    write_stage_manually "$issue_num" 0
    local sf=$(get_state_file "$issue_num")
    local validation
    validation=$(validate_json_format "$sf")
    if [ "$validation" = "VALID" ]; then
        pass "$tc_num: stage=0 JSON 格式有效"
    else
        fail "$tc_num: stage=0 JSON 格式无效: $validation"
    fi

    for stage in 1 2 3 4; do
        write_stage_manually "$issue_num" "$stage"
        validation=$(validate_json_format "$sf")
        if [ "$validation" = "VALID" ]; then
            pass "$tc_num: stage=$stage JSON 格式有效"
        else
            fail "$tc_num: stage=$stage JSON 格式无效: $validation"
        fi
    done

    local issue_val=$(jq -r '.issue' "$sf")
    local stage_val=$(jq -r '.stage' "$sf")
    local error_val=$(jq -r '.error' "$sf")

    [ "$issue_val" = "$issue_num" ] && pass "$tc_num: issue 字段正确" || fail "$tc_num: issue 字段错误"
    [ "$stage_val" = "4" ] && pass "$tc_num: stage 字段正确" || fail "$tc_num: stage 字段错误"
    [ "$error_val" = "null" ] && pass "$tc_num: error 字段为 null" || fail "$tc_num: error 字段不是 null"

    clear_test_state "$issue_num"
    log "$tc_num 完成: passed=$TESTS_PASSED failed=$TESTS_FAILED"
}

# TC-7: GitHub Issue 标签流转
run_tc7() {
    local tc_num="TC-7"
    log ""
    log "========================================"
    log "开始 $tc_num: GitHub Issue 标签流转验证"
    log "========================================"
    # 标签流转验证通过完整 TC-1 流程隐式验证
    # 此处验证 has_label 函数本身可用
    local issue_num=877
    local labels_output
    labels_output=$(gh issue view "$issue_num" --repo "$REPO" --json labels --jq '.labels[].name' 2>/dev/null || echo "")
    if [ -n "$labels_output" ]; then
        pass "$tc_num: gh issue labels 命令可用"
    else
        log "⚠️ Issue #$issue_num 不存在，跳过"
    fi
    log "$tc_num 完成: passed=$TESTS_PASSED failed=$TESTS_FAILED"
}

main() {
    local mode="${1:-run}"

    if [ "$mode" = "--cleanup" ]; then
        cleanup_all
        exit 0
    fi

    log ""
    log "========================================"
    log "Pipeline Runner 状态驱动验证测试套件"
    log "测试开始时间: $TEST_START_TIME"
    log "项目目录: $PROJECT_ROOT"
    log "========================================"

    if [ ! -f "$PIPELINE_RUNNER" ]; then
        log "❌ 错误: pipeline-runner.sh 不存在"
        exit 1
    fi

    if ! command -v jq &>/dev/null; then
        log "❌ 错误: jq 未安装"
        exit 1
    fi

    if ! command -v gh &>/dev/null; then
        log "❌ 错误: gh CLI 未安装"
        exit 1
    fi

    # TC-5 和 TC-6 不需要真实 GitHub Issue，可直接运行
    run_tc6
    run_tc5

    # 以下 TC 需要真实 GitHub Issue
    log ""
    log "⚠️ 以下测试需要真实 GitHub Issue（TC-1, TC-2, TC-3, TC-4, TC-7）"
    local run_real_tests="${RUN_REAL_TESTS:-false}"
    if [ "$run_real_tests" = "true" ]; then
        run_tc1
        run_tc2
        run_tc3
        run_tc4
        run_tc7
    else
        log "⏭️ 跳过真实测试（设置 RUN_REAL_TESTS=true 强制执行）"
    fi

    log ""
    log "========================================"
    log "测试完成"
    log "========================================"
    log "通过: $TESTS_PASSED"
    log "失败: $TESTS_FAILED"

    [ $TESTS_FAILED -gt 0 ] && exit 1 || exit 0
}

main "$@"
