# OpenClaw Auto Dev - Architecture Document

> **Status**: Stage 1 (Architect) Output  
> **Date**: 2026-04-06  
> **Author**: Architect Agent  

---

## 1. Current System Overview

### 1.1 What Is Built

The openclaw-auto-dev system is a **state-driven multi-agent CI/CD pipeline** that automates the GitHub Issue → PR workflow using 4 sequential stages:

```
Architect (Stage 1) → Developer (Stage 2) → Tester (Stage 3) → Reviewer (Stage 4)
```

**Core Components:**

| Component | File(s) | Status |
|-----------|---------|--------|
| State Management | `src/pipeline_state.h/cpp` | ✅ Complete |
| Notification Service | `src/pipeline_notifier.h/cpp` | ✅ Complete |
| Stage Sequencer | `src/spawn_order.h/cpp` | ✅ Complete |
| Pipeline Runner | `scripts/pipeline-runner.sh` | ✅ Complete |
| Issue Scanner | `scripts/scan-issues.sh` | ✅ Complete |
| Heartbeat Check | `scripts/heartbeat-check.sh` | ✅ Complete |
| Cron Heartbeat | `scripts/cron-heartbeat.sh` | ✅ Complete |
| Feishu Notifier | `scripts/notify-feishu.sh` | ✅ Complete |
| GitHub Actions | `.github/workflows/*.yml` | ✅ Complete |

### 1.2 State Model

Pipeline state is stored as flat-text files in `.pipeline-state/`:
- Filename: `{issue_number}_stage` (e.g., `97_stage`)
- Content: single integer (0-4) + newline
- Stage values: `0`=NotStarted, `1`=ArchitectDone, `2`=DeveloperDone, `3`=TesterDone, `4`=PipelineDone

### 1.3 Trigger Flow

```
GitHub Actions (cron 30min) 
    → scripts/cron-heartbeat.sh
    → scripts/scan-issues.sh (finds openclaw-new Issue)
    → skills/openclaw-pipeline/pipeline-runner.sh
    → 4-agent stages execute sequentially
    → Feishu notification after each stage
    → PR created + merged by Reviewer
```

---

## 2. Issues Found

### Issue A: `pipeline_83_test` Missing CTest Registration (Medium)

**File**: `src/CMakeLists.txt`

The `pipeline_83_test` executable is built but not registered with CTest. Only `spawn_order_test` and `pipeline_97_test` have `add_test()` calls.

**Fix**: Add to `src/CMakeLists.txt`:
```cmake
add_test(NAME pipeline_83_test COMMAND pipeline_83_test)
```

---

### Issue B: `0_stage` Contains Spurious Value (Low)

**File**: `.pipeline-state/0_stage`

The file `0_stage` contains `2` (a leftover test value). Stage files should only be `{issue_num}_stage`, not `0_stage`. The `0` in `0_stage` was likely confused with the stage value `0` (NotStarted).

**Impact**: Low — this file is not read by any code path.

**Fix**: Remove `0_stage` or rename it to a proper issue-numbered file if it was meant to track something specific.

---

### Issue C: `spawn_order_test` Not Registered with CTest (Medium)

**File**: `src/CMakeLists.txt`

`spring_order_test` IS registered with `add_test()`, but `pipeline_83_test` is NOT. This means `ctest` will not run the notification tests.

**Fix**: Add `add_test(NAME pipeline_83_test COMMAND pipeline_83_test)` to `src/CMakeLists.txt`.

---

### Issue D: `pipeline_83_test` Has No `add_test()` in CMake (Same as Issue A)

**File**: `src/CMakeLists.txt`

The executable is compiled but never registered. Also, there is no `set_tests_properties()` for `pipeline_83_test` (though it may not need a `WORKING_DIRECTORY` since it doesn't use state files).

---

### Issue E: No `MULTI_AGENT_DESIGN.md` (Documentation Gap)

**File**: `MULTI_AGENT_DESIGN.md` (referenced in SPEC.md but does not exist)

The SPEC.md references `MULTI_AGENT_DESIGN.md` as "(四 Agent 协作流程)" but this file was never created. The `DESIGN.md` exists but is labeled "已过时" (obsolete).

**Fix**: Either create `MULTI_AGENT_DESIGN.md` with the multi-agent architecture details, or update `SPEC.md` to remove this reference.

---

## 3. Recommended Implementation Fixes

### Priority 1: Fix CTest Registration

Update `src/CMakeLists.txt`:

```cmake
# Issue #83: pipeline notification test executable
add_executable(pipeline_83_test ${CMAKE_CURRENT_LIST_DIR}/pipeline_83_test.cpp ${CMAKE_CURRENT_LIST_DIR}/pipeline_notifier.cpp)
target_include_directories(pipeline_83_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
add_test(NAME pipeline_83_test COMMAND pipeline_83_test)  # ← ADD THIS
```

After this fix, `ctest` output should show all 3 tests:
- `spawn_order_test`
- `pipeline_97_test`
- `pipeline_83_test`

### Priority 2: Clean Up State Directory

```bash
# Remove spurious 0_stage
rm .pipeline-state/0_stage

# Keep 97_stage if intentional (it contains stage=2 for issue #97)
```

### Priority 3: Create `MULTI_AGENT_DESIGN.md`

Document the 4-agent pipeline architecture in a dedicated design doc.

---

## 4. Build & Test Verification

```bash
cd /home/admin/.openclaw/workspace/openclaw-auto-dev
mkdir -p build && cd build
cmake ..
make

# Run individual tests
./src/spawn_order_test
./src/pipeline_97_test
./src/pipeline_83_test

# Run via CTest (after fix)
ctest --output-on-failure
```

Expected CTest output after fixes:
```
spawn_order_test          Passed
pipeline_97_test          Passed
pipeline_83_test          Passed
```

---

## 5. Architecture Strengths

1. **Simple state model**: Plain text files, no DB, no external dependencies
2. **Crash-safe**: Resume from any stage by reading state file
3. **Single-Issue concurrency**: Enforced via GitHub labels (no lock file needed)
4. **Sequential validation**: `spawn_order` ensures no stage skipping
5. **Clean separation**: Each agent stage has distinct responsibilities and artifacts
6. **Notification after each stage**: Real-time visibility for operators

---

## 6. Files Summary

| Path | Purpose |
|------|---------|
| `src/pipeline_state.h/cpp` | State file read/write (core) |
| `src/pipeline_notifier.h/cpp` | 4-stage notification formatter |
| `src/spawn_order.h/cpp` | Stage sequence validator |
| `src/pipeline_97_test.cpp` | Tests for pipeline_state |
| `src/pipeline_83_test.cpp` | Tests for pipeline_notifier |
| `src/spawn_order_test.cpp` | Tests for spawn_order |
| `scripts/pipeline-runner.sh` | Main orchestration script |
| `scripts/scan-issues.sh` | GitHub Issue scanner |
| `scripts/heartbeat-check.sh` | OpenClaw heartbeat probe |
| `scripts/cron-heartbeat.sh` | Cron-triggered pipeline kickoff |
| `scripts/notify-feishu.sh` | Feishu webhook notifier |
| `.github/workflows/issue-check.yml` | GHA cron scanner |
| `.github/workflows/pr-merge.yml` | GHA PR merge handler |
| `OPENCLAW.md` | Project configuration |
| `SPEC.md` | Full system specification |
| `DESIGN.md` | Legacy design document (obsolete) |
| `AGENTS.md` | Agent role definitions |
| `HEARTBEAT.md` | Heartbeat configuration |
| `openclaw/{num}_{slug}/SPEC.md` | Per-issue specification |
| `openclaw/{num}_{slug}/TEST_REPORT.md` | Per-issue test report |

---

## 7. Next Steps (Developer Stage)

1. Apply Priority 1 fix to `src/CMakeLists.txt` (CTest registration)
2. Apply Priority 2 cleanup (remove spurious `0_stage`)
3. Optionally create `MULTI_AGENT_DESIGN.md` for documentation completeness
4. Run `ctest` to verify all 3 tests pass
5. End-to-end test: create a test Issue with `openclaw-new` label, run pipeline, verify PR creation
