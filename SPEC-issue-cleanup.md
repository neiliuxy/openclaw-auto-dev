# SPEC.md — Issue Status Cleanup & Validation System

> **Project**: neiliuxy/openclaw-auto-dev
> **Version**: 1.0
> **Date**: 2026-04-09
> **Stage**: Architect (Stage 0)
> **Issue**: (Maintenance - Addressing Known Issues in SPEC.md)

---

## 1. Overview

### 1.1 Problem Statement

The pipeline has accumulated issues with abnormal status that need cleanup:

| Issue | Title | Problem |
|-------|-------|---------|
| #95 | test: 主会话顺序 spawn 验证 | CLOSED but still has `openclaw-new` label |
| #90 | feat: 实现 C++ 单例模式模板类 | Marked `openclaw-completed` but status abnormal |
| #73 | (min_stack) | Status abnormal (stage/3-reviewed, stage/4-done) |
| #11 | Fix: Complete Hello World (Issue #9) | Stale open PR since long ago |
| #125 | chore: pipeline self-test | Stale open PR |
| #132 | feat(#99): pipeline_99_test fix | Stale open PR |

### 1.2 Root Cause

The pipeline's status tracking relies on:
1. GitHub Issue labels (`openclaw-new`, `openclaw-completed`, etc.)
2. Local state files (`.pipeline-state/{issue}_stage`)

When a pipeline run is interrupted or incomplete, these can get out of sync, leading to:
- Issues closed but labels not updated
- State files not cleaned up after completion
- Open PRs never merged or closed

### 1.3 Solution

Implement an **Issue Status Cleanup & Validation System** that:
1. Detects issues with abnormal status
2. Provides automated cleanup actions
3. Validates pipeline state consistency

---

## 2. Functional Requirements

### 2.1 Detection Rules

The cleanup system must detect:

| Rule ID | Condition | Severity |
|---------|-----------|----------|
| D1 | Issue is CLOSED but has `openclaw-new` label | HIGH |
| D2 | Issue is OPEN but has `openclaw-completed` label | HIGH |
| D3 | Issue has `stage/N-*` labels but no active stage label | MEDIUM |
| D4 | Issue has conflicting stage labels (e.g., both `openclaw-developing` and `openclaw-testing`) | HIGH |
| D5 | Issue has `openclaw-error` label but is not being actively worked on | MEDIUM |
| D6 | State file exists but issue is CLOSED and `openclaw-completed` | LOW |
| D7 | State file missing but issue was in pipeline (has stage labels) | MEDIUM |

### 2.2 Cleanup Actions

| Action | Description |
|--------|-------------|
| C1 | Remove incorrect labels from closed issues |
| C2 | Add missing `openclaw-completed` to properly closed issues |
| C3 | Clean up orphaned state files |
| C4 | Close stale PRs (>30 days old with no activity) |
| C5 | Add `openclaw-error` label to issues that failed mid-pipeline |

### 2.3 Validation Checks

| Check | Description |
|-------|-------------|
| V1 | All issues with `openclaw-new` must have a state file or be currently processing |
| V2 | All issues with `openclaw-completed` must be CLOSED |
| V3 | State file stage values must be consistent with issue labels |

---

## 3. Implementation

### 3.1 New Script: `scripts/cleanup-issue-status.sh`

**Location**: `scripts/cleanup-issue-status.sh`

**Usage**:
```bash
# Dry run (show what would be done)
bash scripts/cleanup-issue-status.sh --dry-run

# Actually perform cleanup
bash scripts/cleanup-issue-status.sh --execute

# Check specific issue
bash scripts/cleanup-issue-status.sh --issue 95

# Verbose output
bash scripts/cleanup-issue-status.sh --verbose
```

**Exit Codes**:
- 0: Success (no issues found or all issues resolved)
- 1: Errors encountered
- 2: Dry run mode, changes pending

### 3.2 Script Behavior

```bash
#!/bin/bash
set -euo pipefail

# Detection Phase
detect_issues() {
    # D1: Closed issues with openclaw-new
    gh issue list --state closed --label "openclaw-new" --json number,title
    
    # D2: Open issues with openclaw-completed
    gh issue list --state open --label "openclaw-completed" --json number,title
    
    # D4: Issues with conflicting stage labels
    # (handled via label intersection check)
}

# Cleanup Phase  
cleanup_issue() {
    local issue_num="$1"
    local action="$2"  # remove-label, add-label, close-pr, delete-state
    
    case "$action" in
        remove-label)
            gh issue edit "$issue_num" --remove-label "openclaw-new"
            ;;
        add-label)
            gh issue edit "$issue_num" --add-label "openclaw-completed"
            ;;
        close-pr)
            local pr_num
            pr_num=$(gh pr list --head "$issue_num" --json number --jq '.[0].number')
            if [[ -n "$pr_num" ]]; then
                gh pr close "$pr_num" --comment "Closing stale PR per cleanup"
            fi
            ;;
        delete-state)
            rm -f ".pipeline-state/${issue_num}_stage"
            ;;
    esac
}
```

### 3.3 Integration with Heartbeat

Add cleanup check to `scripts/heartbeat-check.sh`:

```bash
# Run cleanup check every 6 hours
last_cleanup=$(cat "$STATE_DIR/.last_cleanup_timestamp" 2>/dev/null || echo 0)
current_time=$(date +%s)
cleanup_interval=21600  # 6 hours

if (( current_time - last_cleanup >= cleanup_interval )); then
    bash "$SCRIPT_DIR/cleanup-issue-status.sh" --dry-run --json > "$STATE_DIR/cleanup-report.json"
    if [[ -s "$STATE_DIR/cleanup-report.json" ]]; then
        log_warn "Found issues requiring cleanup. Run with --execute to fix."
    fi
    echo "$current_time" > "$STATE_DIR/.last_cleanup_timestamp"
fi
```

### 3.4 New CTest: `cleanup_validation_test`

**Location**: `tests/cleanup_validation_test.cpp`

**Test Cases**:
```cpp
TEST_F(CleanupValidation, DetectClosedWithNewLabel) {
    // Simulate issue #95: CLOSED but has openclaw-new
    std::string output = exec("gh issue list --state closed --label openclaw-new");
    EXPECT_TRUE(output.find("95") != std::string::npos);
}

TEST_F(CleanupValidation, DetectConflictingStageLabels) {
    // Issues should not have multiple stage labels
    // e.g., both openclaw-developing and openclaw-testing
}

TEST_F(CleanupValidation, StateFileConsistency) {
    // For each open issue with pipeline labels,
    // corresponding state file must exist
}
```

---

## 4. Files to Create/Modify

### 4.1 New Files

| File | Description |
|------|-------------|
| `scripts/cleanup-issue-status.sh` | Main cleanup script |
| `tests/cleanup_validation_test.cpp` | CTest for validation logic |
| `docs/cleanup-guide.md` | Documentation for the cleanup system |

### 4.2 Modified Files

| File | Change |
|------|--------|
| `scripts/heartbeat-check.sh` | Add periodic cleanup check |
| `tests/CMakeLists.txt` | Add cleanup_validation_test |
| `SPEC.md` | Add this spec as section 13 (Cleanup System) |

---

## 5. Acceptance Criteria

- [ ] `scripts/cleanup-issue-status.sh` exists and is executable
- [ ] `--dry-run` mode correctly identifies issue #95 as abnormal
- [ ] `--execute` mode fixes issue #95's labels
- [ ] Script handles all detection rules (D1-D7)
- [ ] Integration with heartbeat-check.sh works
- [ ] CTest `cleanup_validation_test` passes
- [ ] Documentation in `docs/cleanup-guide.md` is complete

---

## 6. Issue #95 Specific Fix

### 6.1 Current State of #95

```json
{
  "number": 95,
  "title": "test: 主会话顺序 spawn 验证",
  "state": "CLOSED",
  "labels": ["openclaw-new"]  // WRONG - should be openclaw-completed
}
```

### 6.2 Required Fix

```bash
# Remove incorrect label
gh issue edit 95 --remove-label "openclaw-new"

# Add correct label (optional - issue is already closed)
gh issue edit 95 --add-label "openclaw-completed"
```

### 6.3 Verification

```bash
gh issue view 95 --json labels
# Should show: ["openclaw-completed"] (and no openclaw-new)
```

---

## 7. Extension: Automated Cleanup (Future)

Once this system is proven, we can extend to automatic cleanup:

```bash
# In heartbeat-check.sh, auto-execute for HIGH severity
if (( severity == HIGH )) && [[ "$AUTO_FIX" == "true" ]]; then
    cleanup_issue "$issue_num" "$action"
fi
```

This would require `--execute` flag with proper safety checks.

---

## 8. Summary

This implementation addresses the Known Issues in SPEC.md section 9 by:
1. Creating a detection system for abnormal issue status
2. Providing automated cleanup actions
3. Fixing issue #95 specifically
4. Integrating with existing heartbeat mechanism
5. Adding validation tests

The cleanup system runs periodically and can be triggered manually, ensuring the pipeline maintains consistent state over time.
