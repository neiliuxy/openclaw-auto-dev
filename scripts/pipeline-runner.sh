#!/bin/bash
#===============================================================================
# pipeline-runner.sh — State-driven pipeline runner for OpenClaw Issue Processing
#
# Stages:
#   0: Initial (Architect) — creates SPEC.md from issue
#   1: Architect complete (Developer) — generates code file
#   2: Developer complete (Tester) — builds and creates TEST_REPORT.md
#   3: Tester complete (Reviewer) — creates and merges PR
#   4: All complete — pipeline exits cleanly
#
# State file: .pipeline-state/<issue>_stage (JSON format)
#
# Usage:
#   bash scripts/pipeline-runner.sh <issue_number>
#   bash scripts/pipeline-runner.sh <issue_number> --continue
#===============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="$REPO_DIR/.pipeline-state"
OPENCLAW_DIR="$REPO_DIR/openclaw"
SRC_DIR="$REPO_DIR/src"

# Load OpenClaw config
OPENCLAW_MD="$REPO_DIR/OPENCLAW.md"
if [[ -f "$OPENCLAW_MD" ]]; then
    REPO_NAME=$(grep -E "^\s*-?\s*repo:" "$OPENCLAW_MD" | sed 's/.*repo:\s*//' | tr -d ' ')
    DEFAULT_BRANCH=$(grep -E "^\s*-?\s*default_branch:" "$OPENCLAW_MD" | sed 's/.*default_branch:\s*//' | tr -d ' ')
    SRC_DIR_CONFIG=$(grep -E "^\s*-?\s*src_dir:" "$OPENCLAW_MD" | sed 's/.*src_dir:\s*//' | tr -d ' ')
    [[ -n "$SRC_DIR_CONFIG" ]] && SRC_DIR="$REPO_DIR/$SRC_DIR_CONFIG"
else
    REPO_NAME="neiliuxy/openclaw-auto-dev"
    DEFAULT_BRANCH="master"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------

log_info() { echo -e "${BLUE}[INFO]${RESET} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${RESET} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*"; }

# Get current timestamp in Asia/Shanghai
get_timestamp() {
    TZ='Asia/Shanghai' date +'%Y-%m-%dT%H:%M:%S%z'
}

# Read current stage from state file (returns 0 if file doesn't exist)
get_stage() {
    local issue_num="$1"
    local state_file="$STATE_DIR/${issue_num}_stage"
    
    if [[ ! -f "$state_file" ]]; then
        echo "0"
        return
    fi
    
    # Try JSON parsing, fall back to plain integer
    local content
    content=$(cat "$state_file" 2>/dev/null || echo "")
    
    if [[ "$content" =~ ^\{.*\"stage\" ]]; then
        # JSON format: extract stage value
        local stage_val
        stage_val=$(echo "$content" | grep -o '"stage"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*' | head -1)
        echo "${stage_val:-0}"
    else
        # Legacy plain integer format
        echo "${content}"
    fi
}

# Write state file in JSON format
write_state() {
    local issue_num="$1"
    local stage_val="$2"
    local error_val="${3:-null}"
    
    mkdir -p "$STATE_DIR"
    local state_file="$STATE_DIR/${issue_num}_stage"
    local timestamp
    timestamp=$(get_timestamp)
    
    if [[ "$error_val" == "null" ]]; then
        cat > "$state_file" << EOF
{"issue":$issue_num,"stage":$stage_val,"updated_at":"$timestamp","error":null}
EOF
    else
        cat > "$state_file" << EOF
{"issue":$issue_num,"stage":$stage_val,"updated_at":"$timestamp","error":"$error_val"}
EOF
    fi

    log_info "State updated: stage=$stage_val"

    # Keep pipeline_state.json in sync atomically (Issue #4 fix)
    local json_status="in_progress"
    [[ "$error_val" != "null" ]] && json_status="failed"
    [[ "$stage_val" == "4" ]] && json_status="completed"
    sync_pipeline_state_json "$issue_num" "$stage_val" "$json_status"
}

# Clear state file (called after stage 4 completion)
clear_state() {
    local issue_num="$1"
    local state_file="$STATE_DIR/${issue_num}_stage"
    if [[ -f "$state_file" ]]; then
        rm -f "$state_file"
        log_info "State file cleared"
    fi
}

# Sync pipeline_state.json atomically to match the current {issue}_stage file
# This ensures pipeline_state.json is never out of sync with the source of truth.
sync_pipeline_state_json() {
    local issue_num="$1"
    local stage_val="$2"
    local status_val="${3:-in_progress}"

    local json_file="$STATE_DIR/pipeline_state.json"
    local tmp_file="${json_file}.tmp.$$"
    local timestamp
    timestamp=$(get_timestamp)

    cat > "$tmp_file" << EOF
{
  "stage": $stage_val,
  "status": "$status_val",
  "started_at": "$(grep -o '"started_at":"[^"]*"' "$json_file" 2>/dev/null | cut -d'"' -f4 || echo "$timestamp")",
  "completed_at": "$timestamp",
  "repo": "$REPO_NAME",
  "branch": "openclaw/issue-$issue_num",
  "issue": $issue_num,
  "architect_output": ".pipeline-state/${issue_num}_architect_output.md"
}
EOF
    mv "$tmp_file" "$json_file"
    log_info "pipeline_state.json synced: stage=$stage_val status=$status_val"
}

# Check if gh CLI is available
has_gh() {
    command -v gh &>/dev/null
}

# Update GitHub issue labels
update_labels() {
    local issue_num="$1"
    local from_label="$2"
    local to_label="$3"
    
    if ! has_gh; then
        log_warn "gh CLI not available, skipping label update"
        return 0
    fi
    
    # Remove old label if exists
    if [[ -n "$from_label" ]]; then
        gh api "repos/$REPO_NAME/issues/$issue_num/labels/$from_label" --silent --delete 2>/dev/null || true
    fi
    
    # Add new label
    gh api "repos/$REPO_NAME/issues/$issue_num/labels" --silent -F "labels[]=$to_label" 2>/dev/null || {
        log_warn "Failed to add label $to_label"
    }
}

# Add openclaw-error label on failure
add_error_label() {
    local issue_num="$1"
    
    if ! has_gh; then
        log_warn "gh CLI not available, skipping error label"
        return 0
    fi
    
    gh api "repos/$REPO_NAME/issues/$issue_num/labels" --silent -F "labels[]=openclaw-error" 2>/dev/null || {
        log_warn "Failed to add openclaw-error label"
    }
}

# Send Feishu notification for stage completion
send_stage_notification() {
    local issue_num="$1"
    local stage_name="$2"
    local status="$3"
    local error_msg="${4:-}"
    
    local notify_script="$SCRIPT_DIR/notify-feishu.sh"
    if [[ ! -f "$notify_script" ]]; then
        log_warn "notify-feishu.sh not found, skipping notification"
        return 0
    fi
    
    # Set environment variables for the notification script
    export ISSUE_NUMBER="$issue_num"
    export PIPELINE_PROJECT_ROOT="$REPO_DIR"
    
    if [[ "$status" == "failed" && -n "$error_msg" ]]; then
        # Send failure notification
        "$notify_script" \
            --project "$REPO_DIR" \
            --stage "$stage_name" \
            --status "failed" \
            2>/dev/null || true
    else
        # Send completion notification
        "$notify_script" \
            --project "$REPO_DIR" \
            --stage "$stage_name" \
            --status "completed" \
            2>/dev/null || true
    fi
}

#-------------------------------------------------------------------------------
# Stage 1: Architect — Create SPEC.md
#-------------------------------------------------------------------------------
run_architect() {
    local issue_num="$1"
    
    log_info "=== Stage 1: Architect ==="
    
    # Track if stage completed successfully
    local stage_error=""
    
    # Get issue info
    local issue_title issue_body
    if has_gh; then
        issue_title=$(gh issue view "$issue_num" --repo "$REPO_NAME" --json title -q '.title' 2>/dev/null || echo "Issue-$issue_num")
        issue_body=$(gh issue view "$issue_num" --repo "$REPO_NAME" --json body -q '.body' 2>/dev/null || echo "")
    else
        issue_title="Issue-$issue_num"
        issue_body=""
    fi
    
    # Generate slug from title
    local slug
    slug=$(echo "$issue_title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]+/-/g' | sed 's/^-//;s/-$//' | cut -c1-50)
    [[ -z "$slug" ]] && slug="issue-$issue_num"
    
    local issue_dir="$OPENCLAW_DIR/${issue_num}_${slug}"
    mkdir -p "$issue_dir" || stage_error="Failed to create issue directory"
    
    local spec_file="$issue_dir/SPEC.md"
    
    # Check if SPEC.md already exists (don't overwrite on resume)
    if [[ -f "$spec_file" ]]; then
        log_info "SPEC.md already exists at $spec_file, skipping Architect"
        echo "$slug" > /tmp/pipeline_slug_$issue_num
        send_stage_notification "$issue_num" "architect" "completed"
        return 0
    fi
    
    if [[ -z "$stage_error" ]]; then
        # Create SPEC.md
        cat > "$spec_file" << EOF
# Issue #$issue_num — $issue_title

## Issue Information

- **Issue Number**: $issue_num
- **Title**: $issue_title
- **Generated**: $(get_timestamp)

## Description

$issue_body

## Specification

_Edit this section to add the technical specification for this issue._

### Goals

- 

### Implementation Plan

1. 

### Acceptance Criteria

- [ ] 

EOF
        log_success "SPEC.md created at $spec_file"
    fi
    
    # Git commit and push
    cd "$REPO_DIR"
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        git add "$issue_dir/SPEC.md" 2>/dev/null || stage_error="Failed to git add SPEC.md"
        git commit -m "feat(#$issue_num): Add SPEC.md for $slug" --allow-empty 2>/dev/null || stage_error="Failed to commit SPEC.md"
        git push origin "$(git rev-parse --abbrev-ref HEAD)" 2>/dev/null || stage_error="Failed to push SPEC.md"
    fi
    
    # Save slug for later stages
    echo "$slug" > /tmp/pipeline_slug_$issue_num
    
    # Update labels: openclaw-waiting → openclaw-architecting
    update_labels "$issue_num" "openclaw-waiting" "openclaw-architecting"
    
    if [[ -n "$stage_error" ]]; then
        log_error "Architect stage failed: $stage_error"
        write_state "$issue_num" "1" "$stage_error"
        add_error_label "$issue_num"
        send_stage_notification "$issue_num" "architect" "failed" "$stage_error"
        return 1
    fi
    
    write_state "$issue_num" "1"
    send_stage_notification "$issue_num" "architect" "completed"
    log_success "Architect stage complete"
}

#-------------------------------------------------------------------------------
# Stage 2: Developer — Generate code file
#-------------------------------------------------------------------------------
run_developer() {
    local issue_num="$1"
    
    log_info "=== Stage 2: Developer ==="
    
    # Track if stage completed successfully
    local stage_error=""
    
    # Get slug from previous stage (or issue title as fallback)
    local slug
    if [[ -f "/tmp/pipeline_slug_$issue_num" ]]; then
        slug=$(cat "/tmp/pipeline_slug_$issue_num")
    else
        # Fallback: get from issue title
        local issue_title
        issue_title=$(gh issue view "$issue_num" --repo "$REPO_NAME" --json title -q '.title' 2>/dev/null || echo "issue-$issue_num")
        slug=$(echo "$issue_title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]+/-/g' | sed 's/^-//;s/-$//' | cut -c1-50)
        [[ -z "$slug" ]] && slug="issue-$issue_num"
    fi
    
    local src_file="$SRC_DIR/${slug}.cpp"
    mkdir -p "$(dirname "$src_file")" || stage_error="Failed to create src directory"
    
    # Check if code file already exists (don't overwrite on resume)
    if [[ -f "$src_file" ]]; then
        log_info "Code file $src_file already exists, skipping Developer"
        send_stage_notification "$issue_num" "developer" "completed"
        return 0
    fi
    
    # Read SPEC.md for context
    local spec_content=""
    local spec_file="$OPENCLAW_DIR/${issue_num}_${slug}/SPEC.md"
    [[ -f "$spec_file" ]] && spec_content=$(cat "$spec_file")
    
    if [[ -z "$stage_error" ]]; then
        # Create code file
        cat > "$src_file" << EOF
// Issue #$issue_num: $slug
// Auto-generated by pipeline-runner.sh (Developer stage)
// 
// This is a placeholder implementation.
// Replace with actual implementation based on SPEC.md

#include <iostream>
#include <string>

int main() {
    std::cout << "Issue #$issue_num: $slug" << std::endl;
    std::cout << "Implementation pending - see SPEC.md for details." << std::endl;
    return 0;
}

EOF
        log_success "Code file created at $src_file"
    fi
    
    # Git commit and push
    cd "$REPO_DIR"
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        git add "$src_file" 2>/dev/null || stage_error="Failed to git add $src_file"
        git commit -m "feat(#$issue_num): Add $slug.cpp implementation" --allow-empty 2>/dev/null || stage_error="Failed to commit $src_file"
        git push origin "$(git rev-parse --abbrev-ref HEAD)" 2>/dev/null || stage_error="Failed to push $src_file"
    fi
    
    # Update labels: openclaw-architecting → openclaw-developing
    update_labels "$issue_num" "openclaw-architecting" "openclaw-developing"
    
    if [[ -n "$stage_error" ]]; then
        log_error "Developer stage failed: $stage_error"
        write_state "$issue_num" "2" "$stage_error"
        add_error_label "$issue_num"
        send_stage_notification "$issue_num" "developer" "failed" "$stage_error"
        return 1
    fi
    
    write_state "$issue_num" "2"
    send_stage_notification "$issue_num" "developer" "completed"
    log_success "Developer stage complete"
}

#-------------------------------------------------------------------------------
# Stage 3: Tester — Build and test, create TEST_REPORT.md
#-------------------------------------------------------------------------------
run_tester() {
    local issue_num="$1"
    
    log_info "=== Stage 3: Tester ==="
    
    # Track if stage completed successfully
    local stage_error=""
    
    # Get slug
    local slug
    if [[ -f "/tmp/pipeline_slug_$issue_num" ]]; then
        slug=$(cat "/tmp/pipeline_slug_$issue_num")
    else
        local issue_title
        issue_title=$(gh issue view "$issue_num" --repo "$REPO_NAME" --json title -q '.title' 2>/dev/null || echo "issue-$issue_num")
        slug=$(echo "$issue_title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]+/-/g' | sed 's/^-//;s/-$//' | cut -c1-50)
        [[ -z "$slug" ]] && slug="issue-$issue_num"
    fi
    
    local issue_dir="$OPENCLAW_DIR/${issue_num}_${slug}"
    local src_file="$SRC_DIR/${slug}.cpp"
    local report_file="$issue_dir/TEST_REPORT.md"
    mkdir -p "$issue_dir" || stage_error="Failed to create issue directory"
    
    # Build verification
    local build_status="PASS"
    local build_output=""
    
    if [[ -f "$src_file" ]]; then
        # Try to build
        cd "$REPO_DIR"
        build_output=$(mkdir -p build && cd build && cmake .. >/dev/null 2>&1 && make >/dev/null 2>&1 && echo "BUILD_SUCCESS" || echo "BUILD_FAILED")
        if [[ "$build_output" != "BUILD_SUCCESS" ]]; then
            build_status="FAIL"
            stage_error="Build failed: $build_output"
        fi
    else
        build_status="SKIP (no source file)"
    fi
    
    if [[ -z "$stage_error" ]]; then
        # Create TEST_REPORT.md
        cat > "$report_file" << EOF
# Test Report — Issue #$issue_num

- **Issue**: $issue_num
- **Slug**: $slug
- **Test Date**: $(get_timestamp)
- **Build Status**: $build_status

## Build Verification

\`\`\`
$build_output
\`\`\`

## Test Cases

| Test Case | Status | Notes |
|-----------|--------|-------|
| TC-1 | - | Not executed in this stage |
| TC-2 | - | Not executed in this stage |

## Summary

**Result**: $build_status

EOF
        log_success "TEST_REPORT.md created at $report_file"
    fi
    
    # Git commit and push
    cd "$REPO_DIR"
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        git add "$report_file" 2>/dev/null || stage_error="Failed to git add TEST_REPORT.md"
        git commit -m "test(#$issue_num): Add test report for $slug" --allow-empty 2>/dev/null || stage_error="Failed to commit TEST_REPORT.md"
        git push origin "$(git rev-parse --abbrev-ref HEAD)" 2>/dev/null || stage_error="Failed to push TEST_REPORT.md"
    fi
    
    # Update labels: openclaw-developing → openclaw-testing
    update_labels "$issue_num" "openclaw-developing" "openclaw-testing"
    
    if [[ -n "$stage_error" ]]; then
        log_error "Tester stage failed: $stage_error"
        write_state "$issue_num" "3" "$stage_error"
        add_error_label "$issue_num"
        send_stage_notification "$issue_num" "tester" "failed" "$stage_error"
        return 1
    fi
    
    write_state "$issue_num" "3"
    send_stage_notification "$issue_num" "tester" "completed"
    log_success "Tester stage complete"
}

#-------------------------------------------------------------------------------
# Stage 4: Reviewer — Create PR and merge
#-------------------------------------------------------------------------------
run_reviewer() {
    local issue_num="$1"
    
    log_info "=== Stage 4: Reviewer ==="
    
    # Track if stage completed successfully
    local stage_error=""
    
    # Get slug
    local slug
    if [[ -f "/tmp/pipeline_slug_$issue_num" ]]; then
        slug=$(cat "/tmp/pipeline_slug_$issue_num")
    else
        local issue_title
        issue_title=$(gh issue view "$issue_num" --repo "$REPO_NAME" --json title -q '.title' 2>/dev/null || echo "issue-$issue_num")
        slug=$(echo "$issue_title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]+/-/g' | sed 's/^-//;s/-$//' | cut -c1-50)
        [[ -z "$slug" ]] && slug="issue-$issue_num"
    fi
    
    local branch_name="openclaw/issue-$issue_num"
    
    # Update labels: openclaw-testing → openclaw-reviewing
    update_labels "$issue_num" "openclaw-testing" "openclaw-reviewing"
    
    if ! has_gh; then
        log_warn "gh CLI not available, skipping PR creation"
        write_state "$issue_num" "4"
        clear_state "$issue_num"
        send_stage_notification "$issue_num" "reviewer" "completed"
        log_success "Reviewer stage complete (no gh)"
        return 0
    fi
    
    # Create branch and PR
    cd "$REPO_DIR"
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "$DEFAULT_BRANCH")
    
    # Check if PR already exists
    local existing_pr
    existing_pr=$(gh pr list --repo "$REPO_NAME" --head "$branch_name" --json number -q '.[0].number' 2>/dev/null || echo "")
    
    if [[ -n "$existing_pr" ]]; then
        log_info "PR #$existing_pr already exists for branch $branch_name"
    else
        # Create branch if it doesn't exist
        if ! git rev-parse --verify "$branch_name" &>/dev/null; then
            git checkout -b "$branch_name" 2>/dev/null || stage_error="Failed to create branch $branch_name"
            git push origin "$branch_name" 2>/dev/null || stage_error="Failed to push branch $branch_name"
        fi
        
        if [[ -z "$stage_error" ]]; then
            # Create PR
            local pr_url
            pr_url=$(gh pr create --repo "$REPO_NAME" --base "$DEFAULT_BRANCH" --head "$branch_name" --title "Fix #$issue_num: $slug" --body "Closes #$issue_num" 2>/dev/null) || {
                stage_error="Failed to create PR"
            }
            [[ -n "$pr_url" ]] && log_success "PR created: $pr_url"
        fi
    fi
    
    # Try to merge PR (squash first, then merge)
    local pr_num
    pr_num=$(gh pr list --repo "$REPO_NAME" --head "$branch_name" --json number -q '.[0].number' 2>/dev/null || echo "")
    
    if [[ -n "$pr_num" ]]; then
        # Try squash merge first
        gh pr merge "$pr_num" --repo "$REPO_NAME" --squash --delete-branch 2>/dev/null || {
            # Fall back to regular merge
            gh pr merge "$pr_num" --repo "$REPO_NAME" --merge --delete-branch 2>/dev/null || {
                stage_error="Failed to merge PR #$pr_num"
            }
        }
        if [[ -z "$stage_error" ]]; then
            log_success "PR #$pr_num merged"
            # Post-merge branch cleanup (Issue #1 fix): explicitly delete source branch
            git push origin --delete "openclaw/issue-$issue_num" 2>/dev/null \
                && log_info "Remote branch openclaw/issue-$issue_num deleted" \
                || log_warn "Remote branch openclaw/issue-$issue_num already deleted or not found"
            # Also clean up local branch if it exists
            git branch -d "openclaw/issue-$issue_num" 2>/dev/null \
                || git branch -D "openclaw/issue-$issue_num" 2>/dev/null \
                || true
        fi
    fi
    
    if [[ -n "$stage_error" ]]; then
        log_error "Reviewer stage failed: $stage_error"
        write_state "$issue_num" "4" "$stage_error"
        add_error_label "$issue_num"
        send_stage_notification "$issue_num" "reviewer" "failed" "$stage_error"
        return 1
    fi
    
    write_state "$issue_num" "4"
    clear_state "$issue_num"
    send_stage_notification "$issue_num" "reviewer" "completed"
    log_success "Reviewer stage complete"

    # Step 2: Post-merge branch cleanup — clean up any stray openclaw/issue-* branches
    # whose PRs have been merged. Complements the inline cleanup above; also handles
    # edge cases where branches were merged outside this pipeline.
    if [[ -x "$SCRIPT_DIR/cleanup-merged-branches.sh" ]]; then
        log_info "Running post-merge branch cleanup..."
        if "$SCRIPT_DIR/cleanup-merged-branches.sh" --dry-run 2>/dev/null | grep -q "Branches to delete"; then
            "$SCRIPT_DIR/cleanup-merged-branches.sh" --force 2>/dev/null || true
        else
            log_info "No stray merged branches found"
        fi
    fi
}

#-------------------------------------------------------------------------------
# Validate state consistency at startup (Issue #4 fix)
# Ensures {issue}_stage and pipeline_state.json agree before proceeding.
#-------------------------------------------------------------------------------
validate_state_consistency() {
    local issue_num="$1"
    local state_file="$STATE_DIR/${issue_num}_stage"
    local json_file="$STATE_DIR/pipeline_state.json"

    # If neither file exists, nothing to validate
    if [[ ! -f "$state_file" && ! -f "$json_file" ]]; then
        return 0
    fi

    # Get stage from {issue}_stage file (source of truth)
    local stage_from_file
    stage_from_file=$(get_stage "$issue_num")

    # Get stage from pipeline_state.json if it exists
    if [[ -f "$json_file" ]]; then
        local stage_from_json
        stage_from_json=$(grep -o '"stage"[[:space:]]*:[[:space:]]*[0-9]*' "$json_file" 2>/dev/null | grep -o '[0-9]*' | head -1 || echo "")

        if [[ -n "$stage_from_json" && "$stage_from_json" != "$stage_from_file" ]]; then
            log_warn "State inconsistency detected:"
            log_warn "  ${issue_num}_stage = $stage_from_file"
            log_warn "  pipeline_state.json stage = $stage_from_json"
            log_warn "  Using ${issue_num}_stage as source of truth."
            log_warn "  pipeline_state.json will be synced on next write."
        fi
    fi
}

#-------------------------------------------------------------------------------
# Cleanup: Remove invalid state files from .pipeline-state/
#-------------------------------------------------------------------------------
cleanup_invalid_state_files() {
    local state_dir="${1:-.pipeline-state}"
    log_info "Cleaning up invalid state files in $state_dir..."
    # Delete non-numeric stage files (e.g., 0_stage, plan.json, architect_plan.md)
    find "$state_dir" -maxdepth 1 -name "*_stage" ! -name "[0-9]*_stage" -delete 2>/dev/null || true
    find "$state_dir" -maxdepth 1 -name "plan.json" -delete 2>/dev/null || true
    find "$state_dir" -maxdepth 1 -name "architect_plan.md" -delete 2>/dev/null || true
    # Also clean up the 0_stage file if present
    rm -f "$state_dir/0_stage" 2>/dev/null || true
    log_info "Cleanup complete"
}

#-------------------------------------------------------------------------------
# Validate state consistency at startup (Issue #4 fix)
# Ensures {issue}_stage and pipeline_state.json agree before proceeding.
#-------------------------------------------------------------------------------
validate_state_consistency() {
    local issue_num="$1"
    local state_file="$STATE_DIR/${issue_num}_stage"
    local json_file="$STATE_DIR/pipeline_state.json"

    # If neither file exists, nothing to validate
    if [[ ! -f "$state_file" && ! -f "$json_file" ]]; then
        return 0
    fi

    # Get stage from {issue}_stage file (source of truth)
    local stage_from_file
    stage_from_file=$(get_stage "$issue_num")

    # Get stage from pipeline_state.json if it exists
    if [[ -f "$json_file" ]]; then
        local stage_from_json
        stage_from_json=$(grep -o '"stage"[[:space:]]*:[[:space:]]*[0-9]*' "$json_file" 2>/dev/null | grep -o '[0-9]*' | head -1 || echo "")

        if [[ -n "$stage_from_json" && "$stage_from_json" != "$stage_from_file" ]]; then
            log_warn "State inconsistency detected:"
            log_warn "  ${issue_num}_stage = $stage_from_file"
            log_warn "  pipeline_state.json stage = $stage_from_json"
            log_warn "  Using ${issue_num}_stage as source of truth."
            log_warn "  pipeline_state.json will be synced on next write."
        fi
    fi
}

#-------------------------------------------------------------------------------
# Main Pipeline Logic
#-------------------------------------------------------------------------------
run_pipeline() {
    local issue_num="$1"
    local continue_mode="${2:-false}"
    
    log_info "Pipeline started for Issue #$issue_num (continue=$continue_mode)"
    
validate_state_consistency "$issue_num"
    
    # Determine starting stage
    local current_stage
    current_stage=$(get_stage "$issue_num")
    log_info "Current stage: $current_stage"
    
    # Handle stage 4 (already completed)
    if [[ "$current_stage" == "4" ]]; then
        log_info "Issue #$issue_num already completed, skipping"
        echo "Issue #$issue_num 已完成，跳过"
        return 0
    fi
    
    # In continue mode, respect current stage
    # Otherwise start from the current stage
    local start_stage="$current_stage"
    
    # If not in continue mode and stage is 0, start from 0
    # If in continue mode and stage is 0, we still start from 0
    if [[ "$continue_mode" == "false" && "$current_stage" == "0" ]]; then
        start_stage=0
    fi
    
    # Execute stages in order, skipping completed ones
    if [[ "$start_stage" -le 1 ]]; then
        run_architect "$issue_num"
    fi
    
    local updated_stage
    updated_stage=$(get_stage "$issue_num")
    if [[ "$updated_stage" -le 2 && "$start_stage" -le 2 ]]; then
        run_developer "$issue_num"
    fi
    
    updated_stage=$(get_stage "$issue_num")
    if [[ "$updated_stage" -le 3 && "$start_stage" -le 3 ]]; then
        run_tester "$issue_num"
    fi
    
    updated_stage=$(get_stage "$issue_num")
    if [[ "$updated_stage" -le 4 && "$start_stage" -le 4 ]]; then
        run_reviewer "$issue_num"
    fi
    
    log_success "Pipeline completed for Issue #$issue_num"
}

#-------------------------------------------------------------------------------
# Entry Point
#-------------------------------------------------------------------------------
main() {
    local issue_num=""
    local continue_mode=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --continue)
                continue_mode=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 <issue_number> [--continue]"
                echo "  --continue  Resume from current stage instead of starting over"
                exit 0
                ;;
            *)
                if [[ -z "$issue_num" ]]; then
                    issue_num="$1"
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$issue_num" ]]; then
        log_error "Usage: $0 <issue_number> [--continue]"
        exit 1
    fi
    
    # Validate issue number
    if ! [[ "$issue_num" =~ ^[0-9]+$ ]]; then
        log_error "Invalid issue number: $issue_num"
        exit 1
    fi
    
    # Run the pipeline
    run_pipeline "$issue_num" "$continue_mode"
}

main "$@"
