# Plan — openclaw-auto-dev (Pipeline Run 0 Finalization)

**Date:** 2026-04-06
**Stage:** 0 (Architect)
**Author:** Architect Agent
**Branch:** `pipeline-0-final` → `origin/main`

---

## 1. Requirements Analysis

### 1.1 Current Repo State

The openclaw-auto-dev repo is a **mature, state-driven multi-agent CI/CD pipeline**. The core pipeline infrastructure is complete and functional across 120+ merged PRs.

**What IS built (confirmed working):**

| Component | Status | Location |
|-----------|--------|----------|
| `pipeline_state` (state file R/W) | ✅ Complete | `src/pipeline_state.h/cpp` |
| `pipeline_notifier` (4-stage Feishu msgs) | ✅ Complete | `src/pipeline_notifier.h/cpp` |
| `spawn_order` (stage sequence validator) | ✅ Complete | `src/spawn_order.h/cpp` |
| `pipeline-runner.sh` (orchestration) | ✅ Complete | `scripts/pipeline-runner.sh` |
| GitHub Actions workflows | ✅ Complete | `.github/workflows/` |
| Algorithm library (quick_sort, matrix, etc.) | ✅ Complete | `src/*.h/cpp` |
| CTest suite (3 tests registered) | ✅ Complete | CMakeLists.txt |
| Per-issue `SPEC.md` + `TEST_REPORT.md` | ✅ Complete | `openclaw/{num}_{slug}/` |
| ARCHITECTURE.md | ✅ Committed | this commit |
| PLAN.md | ✅ Committed | this commit |

### 1.2 What Needs to Be Done (Developer Stage)

The pipeline infrastructure is complete. The remaining work is **housekeeping** to ensure the repo is clean and production-ready:

| Priority | Item | Description |
|----------|------|-------------|
| **P1** | Resolve any residual merge conflicts | Ensure no conflicting state from prior parallel development |
| **P2** | Verify CTest passes cleanly | All 3 tests (`spawn_order_test`, `pipeline_97_test`, `pipeline_83_test`) pass |
| **P2** | Clean `.pipeline-state/` | Remove any spurious/garbage state files |
| **P3** | Verify `origin/main` push is clean | Ensure this branch merges cleanly |

---

## 2. Architecture Design

### 2.1 System Architecture (Existing, Unchanged)

```
openclaw-new Issue
    │
    ▼
Stage 1: Architect ──→ SPEC.md (requirements analysis)
    │
    ▼
Stage 2: Developer ──→ Code implementation
    │
    ▼
Stage 3: Tester ────→ TEST_REPORT.md (verification)
    │
    ▼
Stage 4: Reviewer ───→ PR → Merge
```

State: `.pipeline-state/{issue_num}_stage` files containing JSON `{"issue":N,"stage":S,"updated_at":"...","error":...}`

### 2.2 This Plan Scope

This is a **pipeline finalization/cleanup** plan — no new features, no architectural changes.

---

## 3. Technical Approach

### 3.1 Build & Test Verification

```bash
cd /home/admin/.openclaw/workspace/openclaw-auto-dev
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Debug
make -j$(nproc)

# Run tests
ctest --output-on-failure
```

Expected: All 3 CTest tests pass:
- `spawn_order_test` — Stage sequence validation
- `pipeline_97_test` — Issue #97 state file handling
- `pipeline_83_test` — Notification pipeline test

### 3.2 State Directory Audit

State files in `.pipeline-state/` should only be `{issue_number}_stage` files. Any other files are garbage:

```bash
ls .pipeline-state/ | grep -vE '^[0-9]+_stage$'
```

If any garbage found → Developer removes it.

### 3.3 Push to origin/main

```bash
git push origin pipeline-0-final:main
```

Or if main is protected:
```bash
git push origin pipeline-0-final
# Then create PR via GitHub UI or gh pr create
```

---

## 4. Implementation Plan (Developer Stage)

| Step | Action | File(s) | Expected Outcome |
|------|--------|---------|------------------|
| 1 | Build project | `build/` | `make` succeeds without errors |
| 2 | Run CTest | — | All 3 tests pass |
| 3 | Audit state dir | `.pipeline-state/` | Only `{num}_stage` files remain |
| 4 | Fix any failures | src/*.cpp | All tests green |
| 5 | Push to origin | — | Branch pushed successfully |

---

## 5. Verification Criteria

Before marking Developer stage complete:
- [ ] `make` completes without errors
- [ ] `ctest --output-on-failure` shows all tests PASSED
- [ ] `.pipeline-state/` contains only valid `{issue_num}_stage` files
- [ ] No uncommitted changes (working tree clean)
- [ ] Branch pushed to `origin/main` or PR created

---

## 6. Files Summary

| File | Action |
|------|--------|
| `PLAN.md` | ✅ Committed by Architect |
| `ARCHITECTURE.md` | ✅ Committed by Architect |
| `src/CMakeLists.txt` | ✅ CTest already registered |
| `.pipeline-state/` | Audit + clean if needed |
| Build artifacts | Not tracked (in `.gitignore`) |

---

## 7. Notes for Developer

- **Do not modify** `ARCHITECTURE.md` or `PLAN.md` — these are Architect outputs
- **Do not modify** core pipeline logic (`pipeline_state.cpp`, `pipeline_notifier.cpp`, `spawn_order.cpp`) unless tests fail due to a genuine bug
- **If tests fail**, fix the minimum code needed to pass — no refactoring
- **Push directly to `origin/main`** if you have permissions, otherwise open a PR
