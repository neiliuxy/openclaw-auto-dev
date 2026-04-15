# Architectural Plan — openclaw-auto-dev

> **Project**: neiliuxy/openclaw-auto-dev
> **Stage**: 0 (Architect)
> **Date**: 2026-04-15
> **Author**: Pipeline Architect Agent

---

## 1. System Overview

openclaw-auto-dev is a **state-driven multi-agent GitHub Issue → PR automation pipeline** using four sequential stages: Architect → Developer → Tester → Reviewer.

- **State model**: Flat JSON files in `.pipeline-state/` (one file per issue)
- **Language mix**: Bash (orchestration) + C++ (core library: state, notifications, ordering)
- **Build system**: CMake + CTest
- **Trigger**: OpenClaw heartbeat / GitHub Actions cron every 30min

---

## 2. Current Architecture

### 2.1 Directory Structure

```
openclaw-auto-dev/
├── .pipeline-state/           # State files: {issue}_stage (JSON), pipeline_state.json
├── .github/workflows/         # CI: cmake-tests.yml, issue-check.yml, pr-merge.yml
├── agents/                    # [DEPRECATED] Static agent scripts (unused)
├── build/                     # CMake build output (git-ignored)
├── docs/                      # Architecture docs
├── logs/                      # Rolling scan logs
├── openclaw/{N}_{slug}/       # Per-issue workspace (SPEC.md, TEST_REPORT.md)
├── scripts/                   # Shell orchestration
│   ├── pipeline-runner.sh     # [CORE] 4-stage runner
│   ├── heartbeat-check.sh     # Scan for openclaw-new issues
│   ├── scan-issues.sh         # GitHub issue query
│   ├── notify-feishu.sh       # Feishu webhook
│   ├── cleanup-merged-branches.sh
│   ├── validate-changes.sh
│   ├── close-stale-prs.sh
│   └── check-conflicts.sh
├── src/                       # C++ core library
│   ├── pipeline_state.h/cpp    # [CORE] State read/write
│   ├── pipeline_stage.h        # [CORE] Stage/status enums
│   ├── pipeline_notifier.h/cpp # [CORE] 4-stage notification formatter
│   ├── spawn_order.h/cpp       # [CORE] Stage sequence validation
│   ├── logger.h/cpp            # Rolling file logger
│   ├── string_utils.h/cpp      # String helpers
│   ├── ini_parser.h/cpp        # INI read/write
│   ├── quick_sort.h/cpp        # Algorithm
│   ├── matrix.h/cpp            # Algorithm
│   ├── date_utils.h/cpp        # Date helpers
│   ├── file_finder.cpp         # File lookup
│   ├── min_stack.h/cpp         # Algorithm
│   ├── binary_tree.cpp         # Algorithm
│   ├── *_test.cpp              # Unit/integration tests
│   └── CMakeLists.txt
├── tests/                     # Extra test sources
├── CMakeLists.txt             # Top-level build config
├── OPENCLAW.md               # OpenClaw project metadata
├── SPEC.md                   # Full system specification
├── ARCHITECTURE.md           # Detailed architecture doc
├── ARCHITECT.md              # Previous architect notes
├── DESIGN.md                 # [LEGACY] Old design (obsolete)
├── MULTI_AGENT_DESIGN.md     # [EXISTS] 4-agent collaboration doc
├── README.md                 # Project overview
├── PLAN.md                   # Implementation plan
└── project.yaml              # LLM and build config
```

### 2.2 Four-Stage Pipeline

```
Stage 0: NotStarted
    ↓  (pipeline-runner.sh creates {N}_stage)
Stage 1: Architect
    └── Output: openclaw/{N}_{slug}/SPEC.md
    └── Labels: openclaw-new → openclaw-architecting
    ↓
Stage 2: Developer
    └── Output: src/{slug}.cpp (pushed to openclaw/issue-{N} branch)
    └── Labels: openclaw-architecting → openclaw-developing
    ↓
Stage 3: Tester
    └── Output: openclaw/{N}_{slug}/TEST_REPORT.md
    └── Labels: openclaw-developing → openclaw-testing
    ↓
Stage 4: Reviewer
    └── Output: PR merged, branch deleted
    └── Labels: openclaw-testing → openclaw-reviewing → openclaw-completed
    └── Cleanup: {N}_stage file removed
```

### 2.3 Core C++ Components

| Module | File | Responsibility |
|--------|------|----------------|
| **Stage enums** | `pipeline_stage.h` | `Stage` (None/Architect/Developer/Tester/Reviewer) and `StageStatus` (Pending/Running/Completed/Failed) enums with conversion helpers |
| **State I/O** | `pipeline_state.h/cpp` | **Two layers**: (1) legacy `read_stage`/`write_stage` functions using `{N}_stage` files; (2) new `PipelineStateManager` class using `pipeline.json` + `stage-{N}.json` per-stage files |
| **Notifier** | `pipeline_notifier.h/cpp` | `PipelineNotifier` class formats per-stage Feishu messages |
| **Order validator** | `spawn_order.h/cpp` | `validate_sequence()` ensures no stage-skipping |

### 2.4 State File Schema

**Legacy** (`{issue}_stage`):
```json
{"issue":104,"stage":2,"updated_at":"2026-04-09T20:20:00+0800","error":null}
```

**New multi-stage** (`pipeline.json`):
```json
{
  "pipeline_id": "pipeline_1234",
  "issue": "#104",
  "current_stage": 2,
  "status": "running",
  "stages": { ... }
}
```

**Per-stage** (`stage-{N}.json`):
```json
{
  "stage": 2,
  "name": "developer",
  "status": "completed",
  "session_id": "...",
  "started_at": 1234,
  "completed_at": 1235,
  "timeout_seconds": 3600,
  "last_heartbeat_at": 1234,
  "output": { "summary": "...", "files_created": ["src/foo.cpp"] },
  "error": null
}
```

---

## 3. Architectural Findings

### 3.1 Dual State Management Design (MILD CONCERN)

**Finding**: There are two parallel state management systems:

1. **Legacy**: `read_stage()`/`write_stage()` functions operating on `{N}_stage` JSON files — flat, single-value stage tracking. Used by `pipeline-runner.sh` and all `pipeline_*_test.cpp` files.

2. **New**: `PipelineStateManager` class using `pipeline.json` + `stage-{N}.json` files — tracks per-stage details (session_id, heartbeat, timeout, files_created). Full-featured but **not actually used by any consumer yet**.

The `PipelineStateManager` is implemented (Issue #90) but:
- `pipeline-runner.sh` still uses the legacy `{N}_stage` file only
- No test exercises `PipelineStateManager`
- `PipelineStateManager::load()` reads from `pipeline.json` (which `pipeline-runner.sh` also writes via `sync_pipeline_state_json()`) — the two write paths can diverge

**Architecture Decision Needed**: Either retire the legacy system and migrate fully to `PipelineStateManager`, or keep the legacy layer as a thin compatibility wrapper and let `PipelineStateManager` be the internal implementation detail.

### 3.2 Shell/C++ Boundary Is Clean

**Finding**: `pipeline-runner.sh` calls into C++ only indirectly (CMake build step in Tester stage). The C++ state library is primarily used by test binaries, not by the shell scripts. The shell script does all GitHub API calls directly. This is a reasonable design — shell handles external I/O, C++ handles structured logic.

### 3.3 Deprecation Flag: `agents/` Directory

**Finding**: `agents/` contains static shell scripts for architect/developer/reviewer/tester. These are **never invoked** — all pipeline logic flows through `pipeline-runner.sh`. The `agents/` directory is vestigial and creates confusion.

### 3.4 Label/State Dual Tracking

**Finding**: The pipeline tracks progress in two places simultaneously:
- **GitHub Labels** (`openclaw-new`, `openclaw-architecting`, etc.)
- **State files** (`{N}_stage`)

The shell script updates both on each stage transition. This is redundant — the state file is the authoritative source; labels are just a GitHub-UI convenience.

### 3.5 Test Coverage Assessment

| Test | What It Covers | Status |
|------|---------------|--------|
| `spawn_order_test` | Stage sequence validation | ✅ |
| `pipeline_97_test` | Legacy state read/write | ✅ |
| `pipeline_83_test` | `PipelineNotifier` formatting | ✅ |
| `pipeline_99_test` | Cron auto-processing | ✅ |
| `pipeline_102_test` | Full pipeline API roundtrip | ✅ |
| `pipeline_104_test` | Developer stage validation | ✅ |
| `pipeline_state_test` | State manager (16 test cases) | ✅ |
| `algorithm_test` | quick_sort, matrix, string_utils | ✅ |
| `min_stack_test` | MinStack algorithm | ✅ |

**Gap**: No end-to-end test that exercises `pipeline-runner.sh` with a real GitHub issue (requires `gh` CLI mocking).

### 3.6 Notification System

**Finding**: `PipelineNotifier` class exists and formats messages per stage, but the actual notification dispatch goes through `scripts/notify-feishu.sh`. The C++ notifier generates strings; the shell script sends them. This separation is fine.

### 3.7 Git History Branching Pattern

**Finding**: Each issue gets a branch `openclaw/issue-{N}`. The pipeline operates on the current branch. After PR merge, `cleanup-merged-branches.sh` cleans up stale branches. This pattern is clean.

---

## 4. Architectural Issues to Address

### P1: State Management Duality

The legacy `{N}_stage` file and new `PipelineStateManager` both exist. `pipeline-runner.sh` writes `{N}_stage` and a thin `pipeline.json`. `PipelineStateManager` reads `pipeline.json` + `stage-{N}.json` files that are never written by the shell.

**Recommendation**: Deprecate `PipelineStateManager`-style per-stage files in favor of the simpler flat `{N}_stage` model, OR wire `PipelineStateManager` fully into `pipeline-runner.sh` so it becomes the actual state layer.

### P2: `agents/` Directory Clutter

**Recommendation**: Move `agents/` contents to `agents/deprecated/` or delete entirely.

### P3: `pipeline_83_test` Missing CTest `set_tests_properties`

**File**: `src/CMakeLists.txt`
The `pipeline_83_test` is registered with `add_test()` but lacks `WORKING_DIRECTORY` property. Since `pipeline_83_test` doesn't use state files, this may not matter — but should be verified.

### P4: `SPEC.md` References Non-Existent `MULTI_AGENT_DESIGN.md`

The `SPEC.md` section 1.2 references `MULTI_AGENT_DESIGN.md` but the file **does exist** — confirmed present. However `DESIGN.md` is labeled obsolete. The relationship between these docs needs cleanup.

### P5: Multiple Out-of-Sync Architecture Docs

Three overlapping architecture documents exist:
- `ARCHITECT.md` — architect notes, dated 2026-04-06
- `ARCHITECTURE.md` — system overview + issues found, dated 2026-04-10
- `SPEC.md` — full specification, dated 2026-04-10

All three should be consolidated. `SPEC.md` is the authoritative spec. `ARCHITECTURE.md` has useful findings (Issue A-E). `ARCHITECT.md` is largely superseded.

---

## 5. Recommended Architectural Evolution

### 5.1 Short-term (next pipeline cycle)

1. **Resolve state duality**: Choose one state model. If `PipelineStateManager` is the future, wire it into `pipeline-runner.sh`. If it's over-engineered, remove it and keep the legacy layer.

2. **Clean up `agents/`**: Deprecate or delete.

3. **Register `pipeline_83_test` with proper `WORKING_DIRECTORY`**: Minor CMake fix.

### 5.2 Medium-term

4. **Add end-to-end pipeline test**: A shell test that simulates the full flow with a fake `gh` CLI or recorded responses.

5. **Unified architecture doc**: Merge `ARCHITECT.md` and `ARCHITECTURE.md` into a single `ARCHITECTURE.md` that complements `SPEC.md`.

6. **Branch cleanup automation**: Ensure `cleanup-merged-branches.sh` runs reliably post-merge.

### 5.3 Long-term

7. **Parallel issue processing**: Current model processes one issue at a time (enforced by single `openclaw-new` label check). If throughput matters, add locking + queue.

8. **Retry/backtrack mechanism**: Currently once a stage fails, it needs manual intervention. A retry mechanism (resetting a failed stage to Pending) would improve automation.

9. **Per-stage timeout enforcement**: `PipelineStateManager` has timeout fields but `pipeline-runner.sh` doesn't enforce them. Wire in heartbeat checks.

---

## 6. Key Design Principles Observed

1. **State files over DB**: Simple, git-auditable, no external dependency
2. **Shell for external I/O, C++ for logic**: Clean separation
3. **Single-file state per issue**: Easy to read, atomic via `mv`
4. **Label as UI affordance, state as truth**: Right priority
5. **CMake + CTest**: Standard, self-contained testing
6. **Git branch per issue**: Clean isolation

---

## 7. Files Modified in This Architect Cycle

| File | Change |
|------|--------|
| `.pipeline-state/pipeline_state.json` | Updated to stage=0, status=running |
| `arch_plan.md` (this file) | Created as architectural plan output |

---

*Architectural plan produced by Pipeline Architect Agent (Stage 0)*
