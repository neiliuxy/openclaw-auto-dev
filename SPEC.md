# SPEC.md — Architect Analysis: Pipeline Health Review & Recommendations

> **Issue**: N/A (Scan-only architect run)
> **Branch**: `architect/spec-20260426` (created from `auto-dev`)
> **Created**: 2026-04-26T11:16:00+08:00
> **Pipeline Stage**: 0 (Architect)
> **Status**: `openclaw-architecting`

---

## 1. Problem Statement

The OpenClaw auto-dev pipeline (`neiliuxy/openclaw-auto-dev`) is functioning correctly for existing issues but shows several infrastructure-level issues that reduce reliability and developer experience:

### 1.1 Current System State

| Component | Status |
|-----------|--------|
| Open Issues (openclaw-new) | **0** — pipeline is idle |
| Latest issue | #152 (CLOSED, enhancement: test coverage) |
| Pipeline state | Stage 0, issue=0 (scan-only mode) |
| Branch `auto-dev` | Active, no unmerged changes |
| CI/CD | Not fully configured (no `.github/workflows/ci.yml`) |

### 1.2 Known Pain Points

| # | Problem | Severity |
|---|---------|----------|
| P1 | **Stale branch accumulation** — `architect/issue-*`, `developer/issue-*`, `dev/issue-*` branches pile up after merge, never deleted | Medium |
| P2 | **No CI workflow** — No `.github/workflows/ci.yml` to run `make && make test` on PRs | High |
| P3 | **No `openclaw-new` issues** — Pipeline is idle; need to ensure the scanning mechanism works when new issues arrive | Low (monitoring) |
| P4 | **Branch protection** — `main` branch likely protected but `auto-dev` is not; could accidentally receive direct pushes | Low |
| P5 | **`develop` branch orphaned** — A `develop` branch exists alongside `auto-dev`; unclear which is the true dev branch | Low |
| P6 | **Scan log spam** — Frequent `NO_STAGE_FILES_*.log` entries in `.pipeline-state/` during idle periods | Low |

---

## 2. Proposed Solution

### 2.1 Immediate: Branch Cleanup

Create a `scripts/cleanup-branches.sh` script that:
1. Lists all merged PRs (or closed issues with `openclaw-completed`)
2. Identifies corresponding feature branches
3. Deletes merged/stale branches older than 30 days

**Rationale**: The most actionable improvement. Reduces confusion and storage.

### 2.2 High Priority: Add CI Workflow

Create `.github/workflows/ci.yml`:
```yaml
name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: make
      - name: Test
        run: make test
```

**Rationale**: No quality gate currently exists for PRs. This is standard practice.

### 2.3 Medium Priority: Clarify Branch Strategy

Decide between `develop` vs `auto-dev`:
- Option A: Deprecate `develop`, use only `auto-dev`
- Option B: Set up a proper `develop` → `main` promotion flow

Update `ARCHITECT.md` and `README.md` to document the chosen strategy.

### 2.4 Low Priority: Scan Optimization

The scan script (`heartbeat-check.sh`) currently logs `NO_STAGE_FILES` entries even when nothing is happening. Suppress these logs to reduce noise, or route them to a rotating log.

---

## 3. File Changes Summary

### 3.1 New Files

| File | Purpose |
|------|---------|
| `.github/workflows/ci.yml` | CI workflow for build + test |
| `scripts/cleanup-branches.sh` | Branch hygiene script |
| `docs/BRANCH_STRATEGY.md` | Branch naming and lifecycle documentation |

### 3.2 Modified Files

| File | Change |
|------|--------|
| `ARCHITECT.md` | Update §4.2 Known Issues, §5 Implementation Plan with new findings; add §8.1 Branch Strategy |
| `README.md` | Add "Branch Strategy" section; link to CI badge |
| `scripts/heartbeat-check.sh` | Optionally suppress `NO_STAGE_FILES` logs during idle |

### 3.3 Files to Delete/Move

| File | Action |
|------|--------|
| `agents/README.md` | Deprecate (move to `agents/README.deprecated.md`) |
| `agents/architect/task.txt` | Delete (deprecated static task file) |
| `agents/developer/task.txt` | Delete (deprecated static task file) |
| `develop` branch | Delete or merge into `auto-dev` |

---

## 4. Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|-------------|
| AC1 | `scripts/cleanup-branches.sh` exists and is executable | `test -x scripts/cleanup-branches.sh` |
| AC2 | `.github/workflows/ci.yml` runs `make && make test` on every push | Actions tab shows green CI |
| AC3 | All deprecated agent files moved to `agents/README.deprecated.md` | `ls agents/` shows no stray task files |
| AC4 | `ARCHITECT.md` updated with current state and branch strategy | File reflects this SPEC |
| AC5 | No open issues with `openclaw-new` label; scan correctly reports idle | `gh issue list --repo neiliuxy/openclaw-auto-dev --state open --label openclaw-new` returns empty |
| AC6 | Branch cleanup script run (after approval) reduces stale branches by >50% | Compare `git branch -a` before/after |

---

## 5. Technical Approach

### 5.1 Branch Cleanup Script Logic

```
1. Get list of merged PRs from GitHub API
2. For each merged PR branch (pattern: openclaw/issue-*):
   a. Check if branch exists locally or remotely
   b. If corresponding issue is closed with openclaw-completed → delete branch
3. Log deleted branches to stdout
```

### 5.2 CI Workflow

Use `actions/checkout@v4` + native `make` (CMakeLists.txt present). No Docker needed since build is native.

### 5.3 Deprecation of agents/

The `agents/` directory contains static task files for old agents. These are superseded by dynamic task injection via the OpenClaw pipeline skill. Move them to `agents/README.deprecated.md` as a single reference file.

---

## 6. Verification Checklist

- [ ] `scripts/cleanup-branches.sh` created and tested (dry-run mode)
- [ ] `.github/workflows/ci.yml` created and verified via Actions
- [ ] `agents/` directory cleaned (deprecated files moved)
- [ ] `ARCHITECT.md` updated with §4.2 fixes and §5 implementation plan
- [ ] `README.md` updated with branch strategy note and CI badge
- [ ] Pipeline state file `.pipeline-state/0_stage` updated to stage=1

---

## 7. Notes

- This SPEC was generated during a scan-only architect run (issue=0, no open issues)
- The most recent closed issue was **#152** (test coverage improvement — enhancement, stage-3-done)
- All prior issues (#99, #102, #104) are merged/completed
- The pipeline is healthy but idle — next trigger will be a new `openclaw-new` issue

---

*Generated by Architect Agent — Pipeline v5, Stage 0*
