#!/bin/bash
#===============================================================================
# close-stale-prs.sh — Close Stale Pull Requests
#
# Closes pull requests that have been inactive for a specified period.
#
# Usage:
#   bash scripts/close-stale-prs.sh --dry-run           # Show what would close
#   bash scripts/close-stale-prs.sh --execute           # Actually close PRs
#   bash scripts/close-stale-prs.sh --days <N>          # Days of inactivity (default: 30)
#   bash scripts/close-stale-prs.sh --pr <num>          # Close specific PR
#   bash scripts/close-stale-prs.sh --verbose           # Verbose output
#
# Exit Codes:
#   0: Success (no stale PRs found or all stale PRs closed)
#   1: Error encountered
#   2: Dry-run mode with PRs pending closure
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO="neiliuxy/openclaw-auto-dev"

# CLI options
DRY_RUN=false
EXECUTE_MODE=false
VERBOSE=false
STALE_DAYS=30
CHECK_PR=""
STALE_PR_REASON="This PR has been stale for over $STALE_DAYS days with no activity. Closing per pipeline cleanup policy."

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
            --days)
                STALE_DAYS="$2"
                shift 2
                ;;
            --pr)
                CHECK_PR="$2"
                shift 2
                ;;
            --verbose|-v)
                VERBOSE=true
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
close-stale-prs.sh — Close Stale Pull Requests

Usage:
    bash scripts/close-stale-prs.sh [options]

Options:
    --dry-run           Show what PRs would be closed (default)
    --execute           Actually close the stale PRs
    --days <N>          Days of inactivity before closing (default: 30)
    --pr <num>          Close a specific PR by number
    --verbose, -v       Verbose output
    --help, -h          Show this help

Examples:
    # Check which PRs are stale
    bash scripts/close-stale-prs.sh --dry-run

    # Close PRs stale for 30+ days
    bash scripts/close-stale-prs.sh --execute

    # Close PRs stale for 14+ days
    bash scripts/close-stale-prs.sh --execute --days 14

    # Close a specific PR
    bash scripts/close-stale-prs.sh --execute --pr 11
EOF
}

#-------------------------------------------------------------------------------
# Core Detection Logic
#-------------------------------------------------------------------------------

# Get list of stale PRs (PRs with no updates for given days)
get_stale_prs() {
    local days="${1:-$STALE_DAYS}"
    
    if ! has_gh; then
        log_error "gh CLI not available"
        return 1
    fi
    
    # Get all open PRs and filter by last update time
    # Using gh pr list with --json to get updated time
    gh pr list --repo "$REPO" --state open --json number,title,updatedAt,author --jq '
        .[] | select(.updatedAt < now | . - ( "'"$days*"' | sub("(?<d>[0-9]+)" ; .d | tonumber | . * 86400) | strftime("%Y-%m-%dT%H:%M:%SZ"))) |
        {
            number: .number,
            title: .title,
            updatedAt: .updatedAt,
            author: .author.login
        }
    ' 2>/dev/null || true
}

# Get stale PRs based on days (using date comparison)
get_stale_prs_simple() {
    local days="${1:-$STALE_DAYS}"
    local cutoff_date
    cutoff_date=$(date -d "$days days ago" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -v-"${days}d" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)
    
    if ! has_gh; then
        log_error "gh CLI not available"
        return 1
    fi
    
    # Get all open PRs
    local prs
    prs=$(gh pr list --repo "$REPO" --state open --json number,title,updatedAt,author --limit 100 2>/dev/null || echo "[]")
    
    # Filter by date using jq
    echo "$prs" | jq -r --arg cutoff "$cutoff_date" '
        .[] | select(.updatedAt < $cutoff) |
        {
            number: .number,
            title: .title,
            updatedAt: .updatedAt,
            author: .author.login,
            days_stale: ((now | sub("(?<tz>[+-][0-9]{2}):(?<tm>[0-9]{2})$"; "Z") | sub("(?<=[0-9]{2})(?=[0-9]{2})"; " hour") | fromdate) - (.updatedAt | fromdate)) / 86400 | floor
        }
    ' 2>/dev/null || true
}

# Check if a specific PR is stale
is_pr_stale() {
    local pr_num="$1"
    local days="${2:-$STALE_DAYS}"
    
    if ! has_gh; then
        log_error "gh CLI not available"
        return 1
    fi
    
    local cutoff_date
    cutoff_date=$(date -d "$days days ago" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -v-"${days}d" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)
    
    local pr_data
    pr_data=$(gh pr view "$pr_num" --repo "$REPO" --json updatedAt --jq '.updatedAt' 2>/dev/null || echo "")
    
    if [[ -z "$pr_data" ]]; then
        return 1
    fi
    
    # Compare dates
    local pr_timestamp pr_cutoff_timestamp
    pr_timestamp=$(date -d "$pr_data" '+%s' 2>/dev/null || echo "0")
    pr_cutoff_timestamp=$(date -d "$cutoff_date" '+%s' 2>/dev/null || echo "0")
    
    if [[ "$pr_timestamp" -lt "$pr_cutoff_timestamp" ]]; then
        return 0  # Is stale
    else
        return 1  # Not stale
    fi
}

#-------------------------------------------------------------------------------
# Core Action Logic
#-------------------------------------------------------------------------------

# Close a specific PR
close_pr() {
    local pr_num="$1"
    local comment="${2:-$STALE_PR_REASON}"
    
    if ! has_gh; then
        log_error "gh CLI not available"
        return 1
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would close PR #$pr_num"
        return 0
    fi
    
    # Add a comment before closing
    gh pr comment "$pr_num" --repo "$REPO" --body "$comment" 2>/dev/null || true
    
    # Close the PR
    if gh pr close "$pr_num" --repo "$REPO" 2>/dev/null; then
        log_success "Closed stale PR #$pr_num"
        return 0
    else
        log_error "Failed to close PR #$pr_num"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Main Logic
#-------------------------------------------------------------------------------

close_specific_pr() {
    local pr_num="$1"
    
    log_info "Checking PR #$pr_num..."
    
    # Check if PR exists
    local pr_info
    pr_info=$(gh pr view "$pr_num" --repo "$REPO" --json number,title,state,updatedAt --jq '.' 2>/dev/null || echo "{}")
    
    if [[ "$pr_info" == "{}" ]]; then
        log_error "PR #$pr_num not found"
        return 1
    fi
    
    local pr_state pr_title pr_updated
    pr_state=$(echo "$pr_info" | jq -r '.state')
    pr_title=$(echo "$pr_info" | jq -r '.title')
    pr_updated=$(echo "$pr_info" | jq -r '.updatedAt')
    
    if [[ "$pr_state" != "OPEN" ]]; then
        log_info "PR #$pr_num is already $pr_state"
        return 0
    fi
    
    [[ "$VERBOSE" == "true" ]] && log_info "PR #$pr_num: $pr_title (updated: $pr_updated)"
    
    if is_pr_stale "$pr_num" "$STALE_DAYS"; then
        log_info "PR #$pr_num is stale (last updated: $pr_updated)"
        close_pr "$pr_num"
    else
        log_info "PR #$pr_num is not stale (last updated: $pr_updated)"
    fi
}

close_all_stale_prs() {
    local days="${1:-$STALE_DAYS}"
    local stale_count=0
    local closed_count=0
    local error_count=0
    
    log_info "Scanning for stale PRs (${days}+ days inactive)..."
    
    # Get stale PRs
    while IFS= read -r pr_json; do
        [[ -z "$pr_json" ]] && continue
        
        stale_count=$((stale_count + 1))
        local pr_num pr_title days_stale
        pr_num=$(echo "$pr_json" | jq -r '.number')
        pr_title=$(echo "$pr_json" | jq -r '.title')
        days_stale=$(echo "$pr_json" | jq -r '.days_stale')
        
        echo ""
        log_info "Found stale PR #$pr_num: $pr_title (${days_stale} days stale)"
        
        if close_pr "$pr_num"; then
            closed_count=$((closed_count + 1))
        else
            error_count=$((error_count + 1))
        fi
    done < <(get_stale_prs_simple "$days" | jq -c '.')
    
    echo ""
    if [[ $stale_count -eq 0 ]]; then
        log_success "No stale PRs found."
        return 0
    fi
    
    log_info "Found $stale_count stale PR(s), closed $closed_count, errors: $error_count"
    
    if [[ $error_count -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

#-------------------------------------------------------------------------------
# Main Entry Point
#-------------------------------------------------------------------------------

main() {
    parse_args "$@"
    
    cd "$REPO_DIR"
    
    if [[ -n "$CHECK_PR" ]]; then
        close_specific_pr "$CHECK_PR"
        exit $?
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Running in DRY-RUN mode (no changes will be made)"
        log_info "Checking for PRs stale for $STALE_DAYS+ days..."
        echo ""
        
        # Just show what would be closed
        local found=false
        while IFS= read -r pr_json; do
            [[ -z "$pr_json" ]] && continue
            found=true
            
            local pr_num pr_title days_stale
            pr_num=$(echo "$pr_json" | jq -r '.number')
            pr_title=$(echo "$pr_json" | jq -r '.title')
            days_stale=$(echo "$pr_json" | jq -r '.days_stale')
            
            log_info "Would close PR #$pr_num: $pr_title (${days_stale} days stale)"
        done < <(get_stale_prs_simple "$STALE_DAYS" | jq -c '.')
        
        if [[ "$found" == "false" ]]; then
            log_success "No stale PRs found."
            exit 0
        fi
        
        echo ""
        log_info "Run with --execute to close these PRs."
        exit 2
    fi
    
    if [[ "$EXECUTE_MODE" == "true" ]]; then
        log_info "Closing stale PRs (${STALE_DAYS}+ days inactive)..."
        close_all_stale_prs "$STALE_DAYS"
        exit $?
    fi
    
    # Default: dry-run
    DRY_RUN=true
    main --dry-run
}

main "$@"
