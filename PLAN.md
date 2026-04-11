# Plan — openclaw-auto-dev

**Date:** 2026-04-06  
**Stage:** 0 (Architect)  
**Author:** Architect Agent  

---

## 1. Requirements Analysis

### 1.1 What Is Already Built

The openclaw-auto-dev repo is a **mature, partially-deployed** state-driven multi-agent CI/CD pipeline. The core system is functional:

| Component | Status | Location |
|-----------|--------|----------|
| `pipeline_state` (state file R/W) | ✅ Complete | `src/pipeline_state.h/cpp` |
| `pipeline_notifier` (4-stage Feishu msgs) | ✅ Complete | `src/pipeline_notifier.h/cpp` |
| `spawn_order` (stage sequence validator) | ✅ Complete | `src/spawn_order.h/cpp` |
| `pipeline-runner.sh` (orchestration) | ✅ Complete | `scripts/pipeline-runner.sh` |
| Scan scripts (heartbeat/cron) | ✅ Complete | `scripts/*.sh` |
| GitHub Actions workflows | ✅ Complete | `.github/workflows/` |
| Algorithm library (quick_sort, matrix, etc.) | ✅ Complete | `src/*.h/cpp` |
| Per-issue SPEC.md + TEST_REPORT.md | ✅ Complete | `openclaw/{num}_{slug}/` |
| CTest test suite | ⚠️ Partial | `pipeline_83_test` not registered |

### 1.2 Outstanding Issues (From ARCHITECTURE.md)

| Priority | Issue | Description |
|----------|-------|-------------|
| **P1** | `pipeline_83_test` not CTest-registered | `add_executable` exists but no `add_test()` in `src/CMakeLists.txt`. `ctest` skips this test. |
| **P1** | `0_stage` spurious file | Contains value `2\n`; not a valid issue-numbered state file. Should be removed. |
| **P2** | `plan.json` untracked | `.pipeline-state/plan.json` is untracked garbage — should be removed. |
| **P2** | `ARCHITECTURE.md` not committed | Created by previous Architect agent but never committed. |
| **P2** | `Testing/` directory untracked | Should be reviewed and either committed or removed. |
| **P3** | `SPEC.md` references missing `MULTI_AGENT_DESIGN.md` | Design doc not created; either create it or remove the reference. |

### 1.3 What This Plan Covers

This plan addresses the outstanding issues and ensures the pipeline is production-ready:
1. Fix `pipeline_83_test` CTest registration
2. Clean up spurious files in `.pipeline-state/`
3. Commit `ARCHITECTURE.md`
4. Run final build + test verification
5. Push to origin

---

## 2. Architecture Design

### 2.1 System Architecture (Existing, Unchanged)

The system is a 4-stage sequential pipeline triggered by heartbeat/cron:

```
openclaw-new Issue
    │
    ▼
Stage 1: Architect ──→ SPEC.md
    │                    (requirements analysis)
    ▼
Stage 2: Developer ──→ Code (src/{slug}.cpp)
    │                    (implementation)
    ▼
Stage 3: Tester ────→ TEST_REPORT.md
    │                    (verification)
    ▼
Stage 4: Reviewer ───→ PR → Merge
                         (code review + merge)
```

State is stored as `.pipeline-state/{issue_num}_stage` containing integer 0–4.

### 2.2 Fix Architecture

No structural changes — this is a **maintenance and cleanup** plan.

---

## 3. Technical Approach

### 3.1 Fix `pipeline_83_test` CTest Registration

**File:** `src/CMakeLists.txt`

Add after existing `add_test()` calls:
```cmake
add_test(NAME pipeline_83_test COMMAND pipeline_83_test)
```

After this, `ctest --output-on-failure` will run all 3 tests:
- `spawn_order_test`
- `pipeline_97_test`
- `pipeline_83_test`

### 3.2 Clean Up State Directory

Remove spurious files:
```bash
rm .pipeline-state/0_stage
rm .pipeline-state/plan.json
```

### 3.3 Commit ARCHITECTURE.md

Stage and commit `ARCHITECTURE.md` (created by previous Architect run, currently untracked).

### 3.4 Review `Testing/` Directory

Inspect `Testing/` and either integrate or remove it.

---

## 4. Implementation Plan

### Step-by-Step

| Step | Action | File(s) | Developer |
|------|--------|---------|-----------|
| 1 | Add `add_test(NAME pipeline_83_test ...)` to CMakeLists | `src/CMakeLists.txt` | Developer |
| 2 | Remove spurious `.pipeline-state/0_stage` | `.pipeline-state/0_stage` | Developer |
| 3 | Remove spurious `.pipeline-state/plan.json` | `.pipeline-state/plan.json` | Developer |
| 4 | Commit `ARCHITECTURE.md` | `ARCHITECTURE.md` | Developer |
| 5 | Review/remove `Testing/` directory | `Testing/` | Developer |
| 6 | Build: `cd build && cmake .. && make` | build artifacts | Developer |
| 7 | Test: `ctest --output-on-failure` | — | Tester |
| 8 | If failures → bug fixes | src/*.cpp | Developer |
| 9 | Final review | all | Reviewer |
| 10 | Push to origin | — | Reviewer |

### Files to Modify

| File | Change |
|------|--------|
| `src/CMakeLists.txt` | Add `add_test(NAME pipeline_83_test ...)` |
| `.pipeline-state/0_stage` | Delete |
| `.pipeline-state/plan.json` | Delete |

### Files to Stage/Commit

| File | Git Action |
|------|-----------|
| `ARCHITECTURE.md` | `git add ARCHITECTURE.md && git commit` |
| `.pipeline-state/0_stage` | `git rm .pipeline-state/0_stage` |
| `.pipeline-state/plan.json` | `git rm .pipeline-state/plan.json` |
| `src/CMakeLists.txt` | `git add src/CMakeLists.txt && git commit` |

### Files to Review/Remove

| File | Decision |
|------|----------|
| `Testing/` | Inspect; likely remove if contains only temp artifacts |

---

## 5. Verification Criteria

After Developer stage:
- [ ] `ctest --output-on-failure` shows all 3 tests pass (`spawn_order_test`, `pipeline_97_test`, `pipeline_83_test`)
- [ ] `.pipeline-state/` contains only valid `{issue_num}_stage` files (no `0_stage`, no `plan.json`)
- [ ] `ARCHITECTURE.md` is committed on current branch
- [ ] `make` completes without errors
- [ ] No untracked garbage files in repo root or `.pipeline-state/`

After Tester stage:
- [ ] All CTest tests pass
- [ ] Build is clean
- [ ] TEST_REPORT.md updated with test results

After Reviewer stage:
- [ ] PR created for the branch
- [ ] PR merged to `origin/master`
- [ ] All pipeline state files updated correctly

---

## 6. Execution Order for Pipeline

```
Architect (this stage)
    ↓ Creates PLAN.md, commits to origin/main
Developer (stage 1)
    ↓ Applies fixes: CMakeLists.txt, cleanup, build
Tester (stage 2)
    ↓ Runs ctest, fixes failures, writes TEST_REPORT.md
Reviewer (stage 3)
    ↓ Reviews, merges PR
```
