# Branch Strategy

## Overview

This document describes the branching strategy for `neiliuxy/openclaw-auto-dev`.

## Branch Types

| Branch Pattern | Purpose | Lifecycle |
|---------------|---------|-----------|
| `main` | Production-ready code | Permanent |
| `auto-dev` | Active development | Permanent |
| `develop` | Deprecated | To be merged into `auto-dev` |
| `openclaw/issue-*` | Per-issue feature branches | Deleted after PR merge |
| `architect/issue-*` | Architect analysis branches | Deleted after SPEC.md written |
| `developer/issue-*` | Developer implementation branches | Deleted after PR merge |
| `dev/issue-*` | Legacy per-issue branches | Deleted after PR merge |

## Branch Naming Convention

- Issues use the pattern `openclaw/issue-<number>` (e.g., `openclaw/issue-152`)
- Architect output uses `architect/issue-<number>` or `architect/spec-<date>`
- Developer uses `openclaw/issue-<number>` or `developer/issue-<number>`

## Branch Cleanup

### Automatic Cleanup

After a PR is merged, the feature branch (`openclaw/issue-*`) should be deleted.
This is handled by the `scripts/cleanup-branches.sh` script which:
1. Identifies merged PRs
2. Deletes corresponding feature branches
3. Skips protected branches (main, auto-dev)

### Manual Cleanup

To preview what would be deleted:
```bash
./scripts/cleanup-branches.sh --dry-run
```

To actually delete:
```bash
./scripts/cleanup-branches.sh
```

## Protection Rules

- `main`: Protected - requires PR, status checks must pass
- `auto-dev`: Protected - requires PR (recommended)
- `develop`: Not protected - deprecated, to be merged into auto-dev

## Workflow

```
1. Issue created with label openclaw-new
   ↓
2. Architect creates branch architect/issue-<num>
   ↓
3. Developer creates branch openclaw/issue-<num>
   ↓
4. PR merged → cleanup-branches.sh deletes feature branch
```

## Deprecated Branches

Stale branches older than 30 days with patterns:
- `architect/issue-*` (post-SPEC)
- `developer/issue-*` (post-merge)
- `dev/issue-*` (legacy)

These are cleaned up via `cleanup-branches.sh`.
