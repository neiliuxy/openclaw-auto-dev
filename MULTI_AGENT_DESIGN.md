# Multi-Agent Design — OpenClaw Auto Dev Pipeline

> **Status**: Current (replaces obsolete `DESIGN.md`)
> **Last Updated**: 2026-04-12

---

## Overview

The **openclaw-auto-dev** project implements a state-driven, multi-agent CI/CD pipeline that automates the processing of GitHub Issues through a four-stage workflow:

```
Issue Created → Architect → Developer → Tester → Reviewer → PR Merged
```

Each stage is handled by a specialized AI agent. The pipeline is crash-safe and resumable.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Issue                             │
│                  (labeled openclaw-new)                         │
└───────────────────────────┬───────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Pipeline Runner                               │
│            (scripts/pipeline-runner.sh)                        │
│                                                                 │
│  1. Read current stage from .pipeline-state/{issue}_stage       │
│  2. Spawn appropriate agent for current stage                   │
│  3. Write updated stage on completion                           │
│  4. Send Feishu notification                                    │
└───────────────────────────┬───────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
   ┌─────────┐        ┌───────────┐       ┌──────────┐
   │Architect│        │ Developer │       │  Tester  │
   │ Stage 1 │        │  Stage 2  │       │ Stage 3  │
   └────┬────┘        └─────┬─────┘       └────┬─────┘
        │                   │                  │
        ▼                   ▼                  ▼
   SPEC.md created    Code implemented    Tests run &
                       in src/          TEST_REPORT.md
                              \            /
                               \          /
                                ▼        ▼
                           ┌──────────────┐
                           │  Reviewer   │
                           │   Stage 4   │
                           └──────┬──────┘
                                  │
                                  ▼
                           PR Created & Merged
                           Branch Deleted
                           Stage → 4
```

---

## Stage Definitions

| Stage | Agent     | Input          | Output                    | State |
|-------|-----------|----------------|---------------------------|-------|
| 0     | —         | Issue created  | Initial state             | `0`   |
| 1     | Architect | Issue + labels | `openclaw/{num}_{slug}/SPEC.md` | `1` |
| 2     | Developer | `SPEC.md`      | `src/{slug}.cpp`          | `2`   |
| 3     | Tester    | `*.cpp`        | `TEST_REPORT.md`          | `3`   |
| 4     | Reviewer  | All artifacts  | PR merged, branch deleted | `4`   |

---

## State Management

### State Files

State is stored in `.pipeline-state/`:

| File | Format | Description |
|------|--------|-------------|
| `{issue}_stage` | JSON | Source of truth for a given issue's pipeline stage |
| `pipeline_state.json` | JSON | Global tracker for the active (or most recent) issue |

### State File Format (`{issue}_stage`)

```json
{
  "issue": 73,
  "stage": 1,
  "updated_at": "2026-04-12T22:20:00+08:00",
  "error": null
}
```

### Validation

On pipeline startup, `validate_state_consistency()` checks that `{issue}_stage` and `pipeline_state.json` agree. The `{issue}_stage` file is always the source of truth — if there's a mismatch, a warning is logged and the stage file takes precedence.

---

## Branch Strategy

- **Working branch**: Each issue is processed on a branch named `openclaw/issue-{num}`
- **Branch creation**: The Reviewer stage creates the PR branch if it doesn't exist
- **Post-merge cleanup**: After PR merge, the source branch is deleted both locally and remotely
- **Stale branch cleanup**: `scripts/cleanup-merged-branches.sh` can be run to clean up any remaining stale branches

---

## GitHub Labels

| Label | Stage | Description |
|-------|-------|-------------|
| `openclaw-new` | 0 | Issue waiting to be processed |
| `openclaw-architecting` | 1 | Architect stage in progress |
| `openclaw-developing` | 2 | Developer stage in progress |
| `openclaw-testing` | 3 | Tester stage in progress |
| `openclaw-reviewing` | 4 | Reviewer stage in progress |
| `openclaw-completed` | 4 | PR merged successfully |
| `openclaw-error` | — | A stage failed |

---

## Agent Responsibilities

### Architect (Stage 1)
- Reads the GitHub issue
- Creates `SPEC.md` with:
  - Issue description
  - Goals and acceptance criteria
  - Implementation plan
- **Does NOT write code**

### Developer (Stage 2)
- Reads `SPEC.md`
- Implements the code in `src/{slug}.cpp`
- Commits and pushes to the issue branch

### Tester (Stage 3)
- Builds the code (`cmake && make`)
- Runs tests via CTest
- Creates `TEST_REPORT.md` with results
- Commits and pushes

### Reviewer (Stage 4)
- Creates a PR from `openclaw/issue-{num}` → `main`
- Merges the PR (squash first, fallback to merge)
- Deletes the source branch
- Updates state to 4 and clears the stage file

---

## Concurrency Control

Only **one issue** can be processed at a time. This is enforced by:

1. **Label check**: The pipeline scans for `openclaw-new` labeled issues
2. **Active issue lock**: While one issue is in progress, others wait

---

## CI/CD Integration

A GitHub Actions workflow (`.github/workflows/cmake-tests.yml`) runs on every PR and push to `main`/`master`/`auto-dev`:

```yaml
on:
  push:
    branches: [main, master, auto-dev]
  pull_request:
    branches: [main, master, auto-dev]
```

The workflow:
1. Configures CMake
2. Builds the project
3. Runs CTest
4. Checks for leftover build artifacts in `src/`

---

## Error Handling

- Each stage catches errors and writes the error message to the state file
- Failed stages get the `openclaw-error` label
- The pipeline can be resumed with `--continue` flag
- Feishu notifications are sent on both success and failure

---

## Build Instructions

```bash
# From project root
cmake -B build
cmake --build build --parallel

# Run tests
ctest --test-dir build --output-on-failure
```

Or from `src/`:
```bash
cd src
cmake -B build
cmake --build build
ctest --test-dir build
```

---

## File Naming Conventions

- **Test files**: `src/*_test.cpp` or `src/*_test.sh`
- **Source files**: `src/{slug}.cpp`
- **Specs**: `openclaw/{num}_{slug}/SPEC.md`
- **Reports**: `openclaw/{num}_{slug}/TEST_REPORT.md`

> Note: Avoid special characters (colons, spaces) in filenames. Use underscores or hyphens.

---

## Key Scripts

| Script | Purpose |
|--------|---------|
| `scripts/pipeline-runner.sh` | Main pipeline runner |
| `scripts/cleanup-merged-branches.sh` | Clean up stale merged branches |
| `scripts/notify-feishu.sh` | Send Feishu notifications |
| `scripts/scan-issues.sh` | Scan for new issues to process |

---

## References

- `ARCHITECT.md` — Original architecture document
- `SPEC.md` (per-issue) — Issue-specific specification
- `.github/workflows/cmake-tests.yml` — CI configuration
