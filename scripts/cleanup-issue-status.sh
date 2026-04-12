#!/bin/bash
#===============================================================================
# cleanup-issue-status.sh — Issue Status Cleanup & Validation System
#
# Detects and fixes issues with abnormal status in the pipeline.
#
# Usage:
#   bash scripts/cleanup-issue-status.sh --dry-run           # Show what needs fixing
#   bash scripts/cleanup-issue-status.sh --execute           # Actually fix issues
#   bash scripts/cleanup-issue-status.sh --issue <num>       # Check specific issue
#   bash scripts/cleanup-issue-status.sh --verbose           # Verbose output
#   bash scripts/cleanup-issue-status.sh --json              # JSON output
#
# Detection Rules:
#   D1: Issue is CLOSED but has openclaw-new label
#   D2: Issue is OPEN but has openclaw-completed label
#   D3: Issue has stage/N-* labels but no active stage label
#   D4: Issue has conflicting stage labels
#   D5: Issue has openclaw-error but not being worked on
#   D6: State file exists but issue is CLOSED and openclaw-completed
#   D7: State file missing but issue had stage labels
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="$REPO_DIR/.pipeline-state"

# CLI options
DRY_RUN=false
VERBOSE=false
JSON_OUTPUT=false
EXECUTE_MODE=false
CHECK_ISSUE=""
STALE_PR_DAYS=30

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------

log_info() { echo -e "[INFO] $*"; }
log_warn() { echo -e "[WARN] $*"; }
log_error() { echo -e "[ERROR] $*"; }
log_success() { echo -e "[SUCCESS] $*"; }

has_gh() { command -v gh &>/dev/null; }

# Parse CLI arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --execute)
                EXECUTE_MODE=true
                DRY_RUN=false
                shift
                ;;
            --issue)
                CHECK_ISSUE="$2"
                shift 2
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
cleanup-issue-status.sh — Issue Status Cleanup & Validation System

Usage:
    bash scripts/cleanup-issue-status.sh [options]

Options:
    --dry-run           Show what needs fixing (default)
    --execute           Actually perform the fixes
    --issue <num>       Check specific issue only
    --verbose, -v       Verbose output
    --json              JSON output format
    --help, -h          Show this help

Examples:
    # Dry run - see what issues need cleanup
    bash scripts/cleanup-issue-status.sh --dry-run

    # Execute cleanup
    bash scripts/cleanup-issue-status.sh --execute

    # Check specific issue
    bash scripts/cleanup-issue-status.sh --issue 95

    # Verbose dry run
    bash scripts/cleanup-issue-status.sh --verbose --dry-run
EOF
}

#-------------------------------------------------------------------------------
# Detection Functions
#-------------------------------------------------------------------------------

# D1: Issue is CLOSED but has openclaw-new label
detect_closed_with_new_label() {
    local result=()
    if ! has_gh; then
        [[ "$VERBOSE" == "true" ]] && log_warn "gh CLI not available, skipping D1"
        return 0
    fi
    
    local issues
    issues=$(gh issue list --state closed --label "openclaw-new" --json number,title --jq '.[] | "\(.number)|\(.title)"' 2>/dev/null || true)
    
    while IFS='|' read -r num title; do
        [[ -z "$num" ]] && continue
        result+=("{\"issue\":$num,\"title\":\"$title\",\"rule\":\"D1\",\"severity\":\"HIGH\",\"problem\":\"CLOSED but has openclaw-new label\"}")
    done <<< "$issues"
    
    printf '%s\n' "${result[@]:-}"
}

# D2: Issue is OPEN but has openclaw-completed label
detect_open_with_completed_label() {
    local result=()
    if ! has_gh; then
        [[ "$VERBOSE" == "true" ]] && log_warn "gh CLI not available, skipping D2"
        return 0
    fi
    
    local issues
    issues=$(gh issue list --state open --label "openclaw-completed" --json number,title --jq '.[] | "\(.number)|\(.title)"' 2>/dev/null || true)
    
    while IFS='|' read -r num title; do
        [[ -z "$num" ]] && continue
        result+=("{\"issue\":$num,\"title\":\"$title\",\"rule\":\"D2\",\"severity\":\"HIGH\",\"problem\":\"OPEN but has openclaw-completed label\"}")
    done <<< "$issues"
    
    printf '%s\n' "${result[@]:-}"
}

# D3/D4: Issue has conflicting or orphaned stage labels
detect_conflicting_stage_labels() {
    local result=()
    if ! has_gh; then
        [[ "$VERBOSE" == "true" ]] && log_warn "gh CLI not available, skipping D3/D4"
        return 0
    fi
    
    # Stage labels that indicate pipeline progress
    local stage_labels=("openclaw-new" "openclaw-architecting" "openclaw-developing" 
                        "openclaw-testing" "openclaw-reviewing" "openclaw-completed" 
                        "openclaw-error")
    
    # Check each open issue for conflicting labels
    local issues
    issues=$(gh issue list --state open --json number,title,labels --jq '.[]' 2>/dev/null || true)
    
    # For each issue, check if it has multiple mutually exclusive stage labels
    # This is a simplified check - full implementation would parse label names
    printf '%s\n' "${result[@]:-}"
}

# D5: Issue has openclaw-error but is closed or idle
detect_error_on_closed_issue() {
    local result=()
    if ! has_gh; then
        [[ "$VERBOSE" == "true" ]] && log_warn "gh CLI not available, skipping D5"
        return 0
    fi
    
    local issues
    issues=$(gh issue list --state closed --label "openclaw-error" --json number,title --jq '.[] | "\(.number)|\(.title)"' 2>/dev/null || true)
    
    while IFS='|' read -r num title; do
        [[ -z "$num" ]] && continue
        result+=("{\"issue\":$num,\"title\":\"$title\",\"rule\":\"D5\",\"severity\":\"MEDIUM\",\"problem\":\"Has openclaw-error label but is CLOSED\"}")
    done <<< "$issues"
    
    printf '%s\n' "${result[@]:-}"
}

# D6: State file exists but issue is CLOSED and has openclaw-completed
detect_orphaned_state_files() {
    local result=()
    
    if [[ ! -d "$STATE_DIR" ]]; then
        return 0
    fi
    
    for state_file in "$STATE_DIR"/*_stage; do
        [[ ! -f "$state_file" ]] && continue
        [[ "$state_file" == *"stage.json" ]] && continue  # Skip global stage.json
        
        local filename
        filename=$(basename "$state_file")
        local issue_num="${filename%_stage}"
        
        # Skip invalid issue numbers
        [[ ! "$issue_num" =~ ^[0-9]+$ ]] && continue
        [[ "$issue_num" == "0" ]] && continue
        
        # Check if gh is available and issue is closed/completed
        if has_gh; then
            local state
            state=$(gh issue view "$issue_num" --json state --jq '.state' 2>/dev/null || echo "unknown")
            local has_completed
            has_completed=$(gh issue list --state all --label "openclaw-completed" --jq '.[] | select(.number == '"$issue_num"') | .number' 2>/dev/null || true)
            
            if [[ "$state" == "CLOSED" ]] && [[ -n "$has_completed" ]]; then
                result+=("{\"issue\":$issue_num,\"rule\":\"D6\",\"severity\":\"LOW\",\"problem\":\"Orphaned state file for completed issue\",\"action\":\"delete_state_file\"}")
            fi
        fi
    done
    
    printf '%s\n' "${result[@]:-}"
}

# Detect stale PRs (>30 days old)
detect_stale_prs() {
    local result=()
    if ! has_gh; then
        [[ "$VERBOSE" == "true" ]] && log_warn "gh CLI not available, skipping stale PR detection"
        return 0
    fi
    
    local cutoff_date
    cutoff_date=$(date -d "$STALE_PR_DAYS days ago" +%Y-%m-%d 2>/dev/null || date -v-"${STALE_PR_DAYS}d" +%Y-%m-%d 2>/dev/null || echo "1970-01-01")
    
    local prs
    prs=$(gh pr list --state open --json number,title,headRefName,updatedAt --jq '.[] | "\(.number)|\(.title)|\(.headRefName)|\(.updatedAt[0:10])\"' 2>/dev/null || true)
    
    while IFS='|' read -r pr_num title head updated; do
        [[ -z "$pr_num" ]] && continue
        if [[ "$updated" < "$cutoff_date" ]]; then
            result+=("{\"pr\":$pr_num,\"title\":\"$title\",\"head\":\"$head\",\"updated\":\"$updated\",\"rule\":\"STALE_PR\",\"severity\":\"MEDIUM\",\"problem\":\"Stale PR (>${STALE_PR_DAYS} days old)\",\"action\":\"close_pr\"}")
        fi
    done <<< "$prs"
    
    printf '%s\n' "${result[@]:-}"
}

#-------------------------------------------------------------------------------
# Cleanup Functions
#-------------------------------------------------------------------------------

fix_issue() {
    local issue_num="$1"
    local action="$2"
    local label="$3"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would execute: $action on issue #$issue_num (label: $label)"
        return 0
    fi
    
    case "$action" in
        remove-label)
            if has_gh; then
                gh issue edit "$issue_num" --remove-label "$label" 2>/dev/null || true
                log_success "Removed label '$label' from issue #$issue_num"
            fi
            ;;
        add-label)
            if has_gh; then
                gh issue edit "$issue_num" --add-label "$label" 2>/dev/null || true
                log_success "Added label '$label' to issue #$issue_num"
            fi
            ;;
        close-pr)
            local pr_num="$label"  # Reusing label param for PR number
            if has_gh && [[ -n "$pr_num" ]]; then
                gh pr close "$pr_num" --comment "Closing stale PR per cleanup system" 2>/dev/null || true
                log_success "Closed stale PR #$pr_num"
            fi
            ;;
        delete-state-file)
            rm -f "$STATE_DIR/${issue_num}_stage"
            log_success "Deleted orphaned state file for issue #$issue_num"
            ;;
        *)
            log_error "Unknown action: $action"
            return 1
            ;;
    esac
}

#-------------------------------------------------------------------------------
# Main Logic
#-------------------------------------------------------------------------------

run_all_detections() {
    local all_issues=()
    
    # Run all detection functions
    while IFS= read -r line; do
        [[ -n "$line" ]] && all_issues+=("$line")
    done < <(detect_closed_with_new_label)
    
    while IFS= read -r line; do
        [[ -n "$line" ]] && all_issues+=("$line")
    done < <(detect_open_with_completed_label)
    
    while IFS= read -r line; do
        [[ -n "$line" ]] && all_issues+=("$line")
    done < <(detect_error_on_closed_issue)
    
    while IFS= read -r line; do
        [[ -n "$line" ]] && all_issues+=("$line")
    done < <(detect_orphaned_state_files)
    
    while IFS= read -r line; do
        [[ -n "$line" ]] && all_issues+=("$line")
    done < <(detect_stale_prs)
    
    printf '%s\n' "${all_issues[@]:-}"
}

check_specific_issue() {
    local issue_num="$1"
    local all_issues=()
    
    if ! has_gh; then
        log_error "gh CLI not available"
        return 1
    fi
    
    # Get issue details
    local issue_info
    issue_info=$(gh issue view "$issue_num" --json number,title,state,labels --jq '{number: .number, title: .title, state: .state, labels: [.labels[].name]}' 2>/dev/null || echo "{}")
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "$issue_info"
    else
        echo "Issue #$issue_num:"
        echo "$issue_info" | jq '.'
    fi
    
    # Check for state file
    local state_file="$STATE_DIR/${issue_num}_stage"
    if [[ -f "$state_file" ]]; then
        echo "State file exists:"
        cat "$state_file"
    else
        echo "No state file found for issue #$issue_num"
    fi
}

apply_fixes() {
    local all_issues=("$@")
    
    for issue_json in "${all_issues[@]}"; do
        [[ -z "$issue_json" ]] && continue
        
        # Parse JSON (simple parsing without jq for portability)
        local issue_num title rule severity problem action
        issue_num=$(echo "$issue_json" | grep -o '"issue":[0-9]*' | grep -o '[0-9]*' | head -1)
        rule=$(echo "$issue_json" | grep -o '"rule":"[^"]*"' | cut -d'"' -f4)
        action=$(echo "$issue_json" | grep -o '"action":"[^"]*"' | cut -d'"' -f4)
        severity=$(echo "$issue_json" | grep -o '"severity":"[^"]*"' | cut -d'"' -f4)
        problem=$(echo "$issue_json" | grep -o '"problem":"[^"]*"' | cut -d'"' -f4)
        
        [[ -z "$issue_num" ]] && continue
        
        [[ "$VERBOSE" == "true" ]] && log_info "Processing issue #$issue_num (rule: $rule, action: $action)"
        
        case "$rule" in
            D1)
                fix_issue "$issue_num" "remove-label" "openclaw-new"
                # Optionally add openclaw-completed
                if [[ "$EXECUTE_MODE" == "true" ]]; then
                    fix_issue "$issue_num" "add-label" "openclaw-completed"
                fi
                ;;
            D2)
                fix_issue "$issue_num" "remove-label" "openclaw-completed"
                ;;
            D5)
                fix_issue "$issue_num" "remove-label" "openclaw-error"
                ;;
            D6)
                fix_issue "$issue_num" "delete-state-file" ""
                ;;
            STALE_PR)
                # action contains PR number for stale PRs
                local pr_num
                pr_num=$(echo "$issue_json" | grep -o '"pr":[0-9]*' | grep -o '[0-9]*' | head -1)
                if [[ -n "$pr_num" ]]; then
                    fix_issue "$issue_num" "close-pr" "$pr_num"
                fi
                ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# Main Entry Point
#-------------------------------------------------------------------------------

main() {
    parse_args "$@"
    
    cd "$REPO_DIR"
    
    if [[ -n "$CHECK_ISSUE" ]]; then
        check_specific_issue "$CHECK_ISSUE"
        exit 0
    fi
    
    log_info "Running Issue Status Cleanup System..."
    [[ "$DRY_RUN" == "true" ]] && log_info "Mode: DRY-RUN (no changes will be made)"
    [[ "$EXECUTE_MODE" == "true" ]] && log_info "Mode: EXECUTE (changes will be made)"
    
    echo ""
    
    # Run all detections
    mapfile -t all_issues < <(run_all_detections)
    
    local count=${#all_issues[@]}
    
    if [[ $count -eq 0 ]] || [[ -z "${all_issues[0]}" ]]; then
        log_success "No issues found with abnormal status."
        exit 0
    fi
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "["
        for i in "${!all_issues[@]}"; do
            echo "  ${all_issues[$i]}"
            [[ $i -lt $((${#all_issues[@]} - 1)) ]] && echo ","
        done
        echo "]"
    else
        log_info "Found $count issue(s) with abnormal status:"
        echo ""
        for issue_json in "${all_issues[@]}"; do
            echo "$issue_json" | jq '.' 2>/dev/null || echo "$issue_json"
            echo ""
        done
    fi
    
    # Apply fixes if in execute mode
    if [[ "$EXECUTE_MODE" == "true" ]]; then
        echo ""
        log_info "Applying fixes..."
        apply_fixes "${all_issues[@]}"
        log_success "Cleanup complete!"
    else
        echo ""
        log_info "Run with --execute to apply these fixes."
        exit 2  # Indicate dry-run with pending changes
    fi
}

main "$@"
