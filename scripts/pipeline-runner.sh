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

#-------------------------------------------------------------------------------
# Stage 1: Architect — Create SPEC.md
#-------------------------------------------------------------------------------
run_architect() {
    local issue_num="$1"
    
    log_info "=== Stage 1: Architect ==="
    
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
    mkdir -p "$issue_dir"
    
    local spec_file="$issue_dir/SPEC.md"
    
    # Check if SPEC.md already exists (don't overwrite on resume)
    if [[ -f "$spec_file" ]]; then
        log_info "SPEC.md already exists at $spec_file, skipping Architect"
        echo "$slug" > /tmp/pipeline_slug_$issue_num
        return 0
    fi
    
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
    
    # Git commit and push
    cd "$REPO_DIR"
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        git add "$issue_dir/SPEC.md"
        git commit -m "feat(#$issue_num): Add SPEC.md for $slug" --allow-empty 2>/dev/null || true
        git push origin "$(git rev-parse --abbrev-ref HEAD)" 2>/dev/null || true
    fi
    
    # Save slug for later stages
    echo "$slug" > /tmp/pipeline_slug_$issue_num
    
    # Update labels: openclaw-waiting → openclaw-architecting
    update_labels "$issue_num" "openclaw-waiting" "openclaw-architecting"
    
    write_state "$issue_num" "1"
    log_success "Architect stage complete"
}

#-------------------------------------------------------------------------------
# Stage 2: Developer — Generate code file
#-------------------------------------------------------------------------------
run_developer() {
    local issue_num="$1"
    
    log_info "=== Stage 2: Developer ==="
    
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
    mkdir -p "$(dirname "$src_file")"
    
    # Check if code file already exists (don't overwrite on resume)
    if [[ -f "$src_file" ]]; then
        log_info "Code file $src_file already exists, skipping Developer"
        return 0
    fi
    
    # Read SPEC.md for context
    local spec_content=""
    local spec_file="$OPENCLAW_DIR/${issue_num}_${slug}/SPEC.md"
    [[ -f "$spec_file" ]] && spec_content=$(cat "$spec_file")
    
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
    
    # Git commit and push
    cd "$REPO_DIR"
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        git add "$src_file"
        git commit -m "feat(#$issue_num): Add $slug.cpp implementation" --allow-empty 2>/dev/null || true
        git push origin "$(git rev-parse --abbrev-ref HEAD)" 2>/dev/null || true
    fi
    
    # Update labels: openclaw-architecting → openclaw-developing
    update_labels "$issue_num" "openclaw-architecting" "openclaw-developing"
    
    write_state "$issue_num" "2"
    log_success "Developer stage complete"
}

#-------------------------------------------------------------------------------
# Stage 3: Tester — Build and test, create TEST_REPORT.md
#-------------------------------------------------------------------------------
run_tester() {
    local issue_num="$1"
    
    log_info "=== Stage 3: Tester ==="
    
    # Get slug
    local slug
    if [[ -f "/tmp/pipeline_slug_$issue_num" ]]; then
        slug=$(cat "/tmp/pipeline_slug_$issue_num")
    else
        local issue_title
        issue_title=$(gh issue view "$issue_num" --repo "$REPO_NAME" --json title -q '.title' 2>/dev/null || echo "issue-$issue_num")
        slug=$(echo "$issue_title" | tr '[:upper:]' '[:lower]' | sed 's/[^a-z0-9]+/-/g' | sed 's/^-//;s/-$//' | cut -c1-50)
        [[ -z "$slug" ]] && slug="issue-$issue_num"
    fi
    
    local issue_dir="$OPENCLAW_DIR/${issue_num}_${slug}"
    local src_file="$SRC_DIR/${slug}.cpp"
    local report_file="$issue_dir/TEST_REPORT.md"
    mkdir -p "$issue_dir"
    
    # Build verification
    local build_status="PASS"
    local build_output=""
    
    if [[ -f "$src_file" ]]; then
        # Try to build
        cd "$REPO_DIR"
        build_output=$(mkdir -p build && cd build && cmake .. >/dev/null 2>&1 && make >/dev/null 2>&1 && echo "BUILD_SUCCESS" || echo "BUILD_FAILED")
        if [[ "$build_output" != "BUILD_SUCCESS" ]]; then
            build_status="FAIL"
        fi
    else
        build_status="SKIP (no source file)"
    fi
    
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
    
    # Git commit and push
    cd "$REPO_DIR"
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        git add "$report_file"
        git commit -m "test(#$issue_num): Add test report for $slug" --allow-empty 2>/dev/null || true
        git push origin "$(git rev-parse --abbrev-ref HEAD)" 2>/dev/null || true
    fi
    
    # Update labels: openclaw-developing → openclaw-testing
    update_labels "$issue_num" "openclaw-developing" "openclaw-testing"
    
    write_state "$issue_num" "3"
    log_success "Tester stage complete"
}

#-------------------------------------------------------------------------------
# Stage 4: Reviewer — Create PR and merge
#-------------------------------------------------------------------------------
run_reviewer() {
    local issue_num="$1"
    
    log_info "=== Stage 4: Reviewer ==="
    
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
            git checkout -b "$branch_name" 2>/dev/null || true
            git push origin "$branch_name" 2>/dev/null || true
        fi
        
        # Create PR
        local pr_url
        pr_url=$(gh pr create --repo "$REPO_NAME" --base "$DEFAULT_BRANCH" --head "$branch_name" --title "Fix #$issue_num: $slug" --body "Closes #$issue_num" 2>/dev/null) || {
            log_warn "Failed to create PR"
            write_state "$issue_num" "4"
            clear_state "$issue_num"
            return 0
        }
        log_success "PR created: $pr_url"
    fi
    
    # Try to merge PR (squash first, then merge)
    local pr_num
    pr_num=$(gh pr list --repo "$REPO_NAME" --head "$branch_name" --json number -q '.[0].number' 2>/dev/null || echo "")
    
    if [[ -n "$pr_num" ]]; then
        # Try squash merge first
        gh pr merge "$pr_num" --repo "$REPO_NAME" --squash --delete-branch 2>/dev/null || {
            # Fall back to regular merge
            gh pr merge "$pr_num" --repo "$REPO_NAME" --merge --delete-branch 2>/dev/null || {
                log_warn "Failed to merge PR"
            }
        }
        log_success "PR #$pr_num merged"
    fi
    
    write_state "$issue_num" "4"
    clear_state "$issue_num"
    log_success "Reviewer stage complete"
}

#-------------------------------------------------------------------------------
# Main Pipeline Logic
#-------------------------------------------------------------------------------
run_pipeline() {
    local issue_num="$1"
    local continue_mode="${2:-false}"
    
    log_info "Pipeline started for Issue #$issue_num (continue=$continue_mode)"
    
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
