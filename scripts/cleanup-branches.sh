#!/bin/bash
# cleanup-branches.sh - Clean up merged/stale branches
# Usage: ./cleanup-branches.sh [--dry-run]
#
# This script identifies and deletes branches that have been merged into main
# or are associated with closed completed issues.

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[DRY RUN] No branches will be deleted"
fi

REPO="${REPO:-neiliuxy/openclaw-auto-dev}"
MAIN_BRANCH="main"

echo "=== Branch Cleanup Script ==="
echo "Repository: $REPO"
echo "Main branch: $MAIN_BRANCH"
echo ""

# Get list of merged PRs
echo "Fetching merged PRs..."
MERGED_BRANCHES=$(gh pr list --repo "$REPO" --state merged --base "$MAIN_BRANCH" --json headRefName --jq '.[].headRefName' 2>/dev/null || echo "")

if [[ -z "$MERGED_BRANCHES" ]]; then
    echo "No merged PRs found."
    exit 0
fi

# Also check for branches matching openclaw/issue-* pattern that might be orphaned
echo "Checking for openclaw/issue-* branches..."
ALL_BRANCHES=$(git branch -r --list 'origin/openclaw/issue-*' 2>/dev/null | sed 's|origin/||' || echo "")

# Combine merged PRs with detected branches
CLEANUP_CANDIDATES=$(echo -e "$MERGED_BRANCHES\n$ALL_BRANCHES" | sort -u | grep -v '^$')

if [[ -z "$CLEANUP_CANDIDATES" ]]; then
    echo "No branches to clean up."
    exit 0
fi

echo "Found the following cleanup candidates:"
echo "$CLEANUP_CANDIDATES"
echo ""

DELETED_COUNT=0
SKIPPED_COUNT=0

for branch in $CLEANUP_CANDIDATES; do
    # Skip main and auto-dev branches
    if [[ "$branch" == "$MAIN_BRANCH" ]] || [[ "$branch" == "auto-dev" ]] || [[ "$branch" == "develop" ]]; then
        echo "[SKIP] $branch (protected)"
        ((SKIPPED_COUNT++)) || true
        continue
    fi

    # Check if branch exists remotely
    if git ls-remote --heads origin "$branch" | grep -q "$branch"; then
        if $DRY_RUN; then
            echo "[DRY RUN] Would delete: $branch"
        else
            echo "[DELETE] $branch"
            if git push origin --delete "$branch" 2>/dev/null; then
                echo "  → Deleted successfully"
                ((DELETED_COUNT++)) || true
            else
                echo "  → Failed to delete (may already be deleted)"
            fi
        fi
    else
        echo "[SKIP] $branch (not found remotely)"
        ((SKIPPED_COUNT++)) || true
    fi
done

echo ""
echo "=== Summary ==="
echo "Deleted: $DELETED_COUNT"
echo "Skipped: $SKIPPED_COUNT"
echo "Done!"
