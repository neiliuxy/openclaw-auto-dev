#!/bin/bash
#===============================================================================
# cleanup-merged-branches.sh — Clean up stale openclaw/issue-* branches
#
# This script finds all openclaw/issue-* branches where the corresponding
# PR has been merged, and deletes the local and remote branches.
#
# Usage:
#   bash scripts/cleanup-merged-branches.sh [--dry-run] [--force]
#
# Options:
#   --dry-run  Show what would be deleted without actually deleting
#   --force    Skip confirmation prompts
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="$REPO_DIR/.pipeline-state"

DRY_RUN=false
FORCE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${RESET} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_success() { echo -e "${GREEN}[OK]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*"; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--force]"
            echo "  --dry-run  Show what would be deleted without actually deleting"
            echo "  --force    Skip confirmation prompts"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

cd "$REPO_DIR"

# Check if gh is available
if ! command -v gh &>/dev/null; then
    log_error "gh CLI not available. Please install GitHub CLI: https://cli.github.com/"
    exit 1
fi

# Get repo name from git remote
REPO_NAME=$(git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/' || echo "")
if [[ -z "$REPO_NAME" ]]; then
    log_error "Could not determine repo name from git remote"
    exit 1
fi

log_info "Repository: $REPO_NAME"

# Get all openclaw/issue-* branches
BRANCHES=$(git branch -r 2>/dev/null | grep 'openclaw/issue-' | sed 's|.*origin/||' || echo "")

if [[ -z "$BRANCHES" ]]; then
    log_info "No openclaw/issue-* branches found"
    exit 0
fi

declare -a TO_DELETE_LOCAL=()
declare -a TO_DELETE_REMOTE=()
declare -a SKIPPED=()

while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue

    # Extract issue number from branch name
    # openclaw/issue-123 -> 123
    issue_num=$(echo "$branch" | sed 's/openclaw\/issue-//')

    if ! [[ "$issue_num" =~ ^[0-9]+$ ]]; then
        log_warn "Skipping '$branch' (cannot extract issue number)"
        SKIPPED+=("$branch")
        continue
    fi

    # Check if PR exists and is merged for this branch
    pr_info=$(gh pr list --repo "$REPO_NAME" --head "$branch" --json number,state --jq '.[0]' 2>/dev/null || echo "")

    if [[ -z "$pr_info" ]]; then
        log_warn "No PR found for branch '$branch' — skipping (may not be merged yet)"
        SKIPPED+=("$branch (no PR)")
        continue
    fi

    pr_state=$(echo "$pr_info" | jq -r '.state' 2>/dev/null || echo "")
    pr_num=$(echo "$pr_info" | jq -r '.number' 2>/dev/null || echo "")

    if [[ "$pr_state" == "MERGED" ]]; then
        log_info "Branch '$branch' has merged PR #$pr_num — marked for cleanup"
        TO_DELETE_LOCAL+=("$branch")
        TO_DELETE_REMOTE+=("$branch")
    else
        log_warn "Branch '$branch' has PR #$pr_num in state '$pr_state' — skipping"
        SKIPPED+=("$branch (PR #$pr_num $pr_state)")
    fi
done <<< "$BRANCHES"

if [[ ${#TO_DELETE_LOCAL[@]} -eq 0 ]]; then
    log_info "No merged branches to clean up"
    [[ ${#SKIPPED[@]} -gt 0 ]] && log_info "Skipped ${#SKIPPED[@]} branches"
    exit 0
fi

echo ""
log_info "Branches to delete (${#TO_DELETE_LOCAL[@]}):"
for branch in "${TO_DELETE_LOCAL[@]}"; do
    echo "  - $branch"
done
echo ""

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    log_info "Skipped branches (${#SKIPPED[@]}):"
    for b in "${SKIPPED[@]}"; do
        echo "  - $b"
    done
    echo ""
fi

if [[ "$DRY_RUN" == "true" ]]; then
    log_warn "DRY RUN — no branches were deleted"
    exit 0
fi

if [[ "$FORCE" != "true" ]]; then
    echo -n "Proceed with deletion? [y/N] "
    read -r response
    if [[ "$response" != "y" && "$response" != "Y" ]]; then
        log_info "Aborted"
        exit 0
    fi
fi

# Delete remote branches first
for branch in "${TO_DELETE_REMOTE[@]}"; do
    log_info "Deleting remote branch: origin/$branch"
    if git push origin --delete "$branch" 2>/dev/null; then
        log_success "Deleted remote branch: origin/$branch"
    else
        log_warn "Remote branch '$branch' may already be deleted or not found"
    fi
done

# Delete local branches
for branch in "${TO_DELETE_LOCAL[@]}"; do
    log_info "Deleting local branch: $branch"
    if git branch -D "$branch" 2>/dev/null; then
        log_success "Deleted local branch: $branch"
    else
        log_warn "Local branch '$branch' not found"
    fi
done

log_success "Cleanup complete!"
