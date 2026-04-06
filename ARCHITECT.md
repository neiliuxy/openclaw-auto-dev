# OpenClaw Auto Dev — Architecture

> **Status**: Current (updated by Architect Agent, 2026-04-06)  
> **Repo**: neiliuxy/openclaw-auto-dev  
> **Purpose**: State-driven multi-agent CI/CD pipeline: GitHub Issue → PR

---

## 1. Overview

openclaw-auto-dev is a **state-driven, four-agent CI/CD pipeline** that automates the full lifecycle of a GitHub Issue from creation through code implementation, testing, and PR merge.

### 1.1 The Four-Agent Pipeline

```
openclaw-new Issue
    │
    ▼
[Stage 1] Architect ──→ openclaw/{num}_{slug}/SPEC.md
    │                  (requirements analysis, no code)
    │                  writes .pipeline-state/{issue}_stage → stage=1
    ▼
[Stage 2] Developer ──→ src/{slug}.cpp (implementation)
    │                  writes .pipeline-state/{issue}_stage → stage=2
    ▼
[Stage 3] Tester ─────→ openclaw/{num}_{slug}/TEST_REPORT.md
    │                  (compilation check, verification)
    │                  writes .pipeline-state/{issue}_stage → stage=3
    ▼
[Stage 4] Reviewer ───→ PR created → PR merged
                         writes .pipeline-state/{issue}_stage → stage=4
                         removes state file on completion
```

### 1.2 Trigger Flow

```
GitHub Actions (cron: 0,30 * * * *)
    │
    ▼
scripts/cron-heartbeat.sh
    │
    ▼
scripts/scan-issues.sh ──→ queries GitHub for "openclaw-new" label
    │                       (checks no issue is currently processing)
    │
    ▼ (if new issue found)
pipeline-runner.sh (from openclaw-pipeline skill)
    │
    ▼
Sequential 4-stage pipeline (Architect → Developer → Tester → Reviewer)
    │
    ▼
PR merged to master → pr-merge.yml workflow fires
    │
    ▼
Issue labeled openclaw-completed
```

### 1.3 State Model

**Location**: `.pipeline-state/{issue_number}_stage`

**Format** (JSON, as of current):
```json
{
  "issue": 97,
  "stage": 2,
  "updated_at": "2026-04-06T10:30:00+08:00",
  "error": null
}
```

**Stage values**:
| Value | Name | Meaning |
|-------|------|---------|
| 0 | NotStarted | Pipeline not yet started (or cleared on completion) |
| 1 | ArchitectDone | SPEC.md created |
| 2 | DeveloperDone | Code implemented |
| 3 | TesterDone | TEST_REPORT.md written |
| 4 | PipelineDone | PR created and merged |

State files are **deleted** after stage 4 completes. The pipeline is **crash-safe**: any stage can be re-entered by resuming from the saved state.

### 1.4 GitHub Labels (Issue State)

| Label | Stage | Meaning |
|-------|-------|---------|
| `openclaw-new` | — | New issue, waiting for pipeline |
| `openclaw-architecting` | 1 | Architect agent running |
| `openclaw-developing` | 2 | Developer agent running |
| `openclaw-testing` | 3 | Tester agent running |
| `openclaw-reviewing` | 4 | Reviewer agent running |
| `openclaw-completed` | — | PR merged, done |
| `openclaw-error` | — | Pipeline failed |

Concurrency control: only one issue processes at a time. `scan-issues.sh` checks all stage labels before picking up a new issue.

---

## 2. Key Components

### 2.1 C++ Library (`src/`)

#### `pipeline_state.h / .cpp`
Core state management. Handles read/write of `.pipeline-state/{issue}_stage` files.

**Key functions**:
- `read_stage(int issue_number)` → returns stage (0–4) or -1 if file absent
- `write_stage(int issue_number, int stage)` → writes JSON format state file
- `read_state(int issue_number)` → returns full `PipelineState` struct (issue, stage, updated_at, error)
- `stage_to_description(int stage)` → human-readable stage name

State file path: `{state_dir}/{issue_number}_stage`

#### `pipeline_notifier.h / .cpp`
Formats Feishu notification messages for each pipeline stage.

**Key class**: `PipelineNotifier`
- `notify_architect(artifact)` → formats Architect completion message
- `notify_developer(artifact)` → Developer completion message
- `notify_tester(artifact)` → Tester completion message
- `notify_reviewer(artifact)` → Reviewer completion message

#### `spawn_order.h / .cpp`
Validates sequential stage ordering (used by tests).

**Key functions**:
- `validate_sequence(current_stage, next_stage)` → returns `true` if `next_stage == current_stage + 1`
- `get_stage_name(int stage)` → human-readable name

### 2.2 Shell Scripts (`scripts/`)

| Script | Purpose |
|--------|---------|
| `pipeline-runner.sh` | **Main orchestrator**. Reads config, fetches issue, runs all 4 stages sequentially. State-driven resume via `--continue`. |
| `scan-issues.sh` | Queries GitHub for `openclaw-new` issues. Enforces single-issue concurrency. Outputs to `scan-result.json`. |
| `cron-heartbeat.sh` | Top-level cron wrapper. Performs log rotation, calls `scan-issues.sh`, triggers `pipeline-runner.sh` if new issue found. |
| `heartbeat-check.sh` | OpenClaw heartbeat probe (checks if pipeline is responsive). |
| `notify-feishu.sh` | Sends Feishu webhook notifications. |
| `check-conflicts.sh` | Detects branch conflicts before merge. |
| `validate-changes.sh` | Validates staged changes before commit. |
| `update-status.sh` | Updates GitHub issue labels. |

### 2.3 GitHub Actions (`.github/workflows/`)

#### `issue-check.yml`
Cron-triggered (every 30 min). Checks for `openclaw-new` issues and (optionally) notifies OpenClaw via webhook.

#### `pr-merge.yml`
Fires on PR closed+merged. Extracts issue number from branch name, removes processing labels, adds `openclaw-completed`, posts a completion comment.

### 2.4 Build System (`src/CMakeLists.txt`)

CTest-managed test suite. Registered tests:

| Test | Binary | Purpose |
|------|--------|---------|
| `spawn_order_test` | `spawn_order_test` | Stage sequence validation |
| `pipeline_97_test` | `pipeline_97_test` | State file R/W API |
| `pipeline_99_test` | `pipeline_99_test` | Cron auto-processing |
| `pipeline_102_test` | `pipeline_102_test` | Pipeline scheme B |
| `pipeline_104_test` | `pipeline_104_test` | Full auto trigger |
| `pipeline_83_test` | `pipeline_83_test` | 4-stage notification formatter |
| `algorithm_test` | `algorithm_test` | Algorithm library (quick_sort, matrix, string_utils) |

Algorithm library (`algorithms` CMake target) provides: `quick_sort`, `matrix`, `date_utils`, `string_utils`, `ini_parser`, `logger`, `file_finder`.

### 2.5 Per-Issue Artifacts (`openclaw/{num}_{slug}/`)

Each processed issue gets its own directory:
- `SPEC.md` — Architect's requirements specification
- `TEST_REPORT.md` — Tester's verification report

### 2.6 Configuration Files

| File | Purpose |
|------|---------|
| `OPENCLAW.md` | Project config: repo, default_branch, src_dir, build_cmd, test_cmd |
| `project.yaml` | OpenClaw workspace-level project metadata |
| `AGENTS.md` | Agent role definitions |
| `HEARTBEAT.md` | Heartbeat/task frequency config |
| `HEARTBEAT-MECHANISM.md` | Heartbeat mechanism documentation |
| `PLAN.md` | Current sprint plan (from Architect agent) |

---

## 3. Data Flow

### 3.1 Pipeline Start (Issue → Stage 1)

```
1. cron-heartbeat.sh (every 30 min via GitHub Actions)
   │
2. scan-issues.sh
   ├── gh issue list --label "openclaw-new"   (find waiting issues)
   ├── gh issue list --label "*openclaw-*"    (ensure no issue is processing)
   └── writes scan-result.json
   │
3. pipeline-runner.sh <issue_number>
   ├── read OPENCLAW.md → repo, branch config
   ├── gh issue view <n> --json title,body   (fetch issue details)
   ├── prepare_branch() → git checkout -b openclaw/issue-<n>
   └── run_pipeline()
```

### 3.2 Stage Execution (pipeline-runner.sh)

Each stage:
1. Updates GitHub labels (removes prior stage label, adds current stage label)
2. Performs its task (creates files, writes code, etc.)
3. Writes state file via `write_stage()`
4. Commits and pushes to the feature branch

**Stage 1 — Architect**:
- Creates `openclaw/{num}_{slug}/SPEC.md` with requirements analysis
- Artifact: SPEC.md

**Stage 2 — Developer**:
- Creates `src/{slug}.cpp` with code implementation
- Attempts `make` build
- Artifact: source file

**Stage 3 — Tester**:
- Runs `make` compilation check
- Creates `openclaw/{num}_{slug}/TEST_REPORT.md`
- Artifact: TEST_REPORT.md

**Stage 4 — Reviewer**:
- Creates PR via `gh pr create`
- Merges via `gh pr merge --squash`
- Removes state file (pipeline done)

### 3.3 State File Lifecycle

```
Pipeline starts
    │
    ▼
write_stage(issue, 1)  ──→ .pipeline-state/{issue}_stage = {"stage": 1, ...}
    │
    ▼
write_stage(issue, 2)  ──→ .pipeline-state/{issue}_stage = {"stage": 2, ...}
    │
    ▼
write_stage(issue, 3)  ──→ .pipeline-state/{issue}_stage = {"stage": 3, ...}
    │
    ▼
write_stage(issue, 4)  ──→ .pipeline-state/{issue}_stage = {"stage": 4, ...}
    │
    ▼
Pipeline done
    │
    ▼
rm .pipeline-state/{issue}_stage  (cleanup on completion)
```

Resume: `pipeline-runner.sh` reads current stage and skips to the appropriate step.

### 3.4 Notification Flow

```
After each stage completes:
    │
    ▼
pipeline_notifier.cpp → formats notification message
    │
    ▼
notify-feishu.sh → POST to Feishu webhook
    │
    ▼
Feishu message delivered to configured channel
```

---

## 4. Design Decisions & Rationale

### 4.1 State File Storage (vs Database)

**Decision**: Plain text files in `.pipeline-state/` directory, not a database.

**Rationale**:
- Zero infrastructure dependencies — just filesystem I/O
- Git-native — state files can be committed, reviewed, audited
- Crash-safe — any intermediate state survives process kill
- Simple — no schema migrations, no connection pooling

**Trade-off**: No atomic multi-key transactions. Concurrent writes to the same issue's state file would corrupt it. Mitigated by single-issue concurrency enforcement in `scan-issues.sh`.

### 4.2 JSON State Format (vs Plain Integer)

**Decision**: JSON format `{"issue": N, "stage": X, "updated_at": "...", "error": null}` instead of plain integer.

**Rationale**:
- Supports future fields (error messages, timestamps, metadata) without format migration
- `updated_at` enables debugging of stale stuck pipelines
- `error` field allows structured error reporting
- Backward compatible with plain integer read via `read_stage()` fallback

### 4.3 Single-Issue Concurrency (vs Parallel)

**Decision**: Only one issue processes at a time, enforced by label checking before pickup.

**Rationale**:
- Avoids branch name collisions (`openclaw/issue-{n}`)
- Avoids concurrent modification of shared build artifacts
- Simpler mental model for operators
- GitHub API rate limit is shared across operations anyway

### 4.4 Sequential Stages (vs Parallel Agents)

**Decision**: Four stages run sequentially, not in parallel.

**Rationale**:
- Each stage's output is the next stage's input (SPEC.md → code → test report → PR)
- Parallel execution would require additional synchronization
- Pipeline duration is bounded by AI response time, not throughput
- Single-issue throughput is not a bottleneck for most projects

### 4.5 Crash-Safe Resume

**Decision**: Pipeline is fully resumable from any stage via state file.

**Rationale**:
- AI agents take time; a crash mid-stage should not lose progress
- State file is updated *after* each stage completes, not before
- Resume is transparent to the operator

### 4.6 Label-Based State (vs Dedicated State Machine)

**Decision**: GitHub issue labels for UI state, state files for pipeline state.

**Rationale**:
- Labels are visible to humans in the GitHub UI without additional tools
- State files are machine-readable, git-auditable, not human-visible
- Dual representation: labels for GitHub UI, files for pipeline integrity

### 4.7 Shell Orchestration (vs C++-Only)

**Decision**: `pipeline-runner.sh` is a bash script, not a compiled binary.

**Rationale**:
- Git operations (`git add`, `commit`, `push`, `branch`) are native shell commands
- `gh` CLI is a shell tool — natural fit
- Easy to edit, debug, and trace without recompilation
- Skill integration (openclaw-pipeline) is also shell-based

### 4.8 CTest for Unit Tests

**Decision**: Use CMake/CTest for the C++ test suite, not a custom test runner.

**Rationale**:
- Standard CMake ecosystem, familiar to C++ developers
- `ctest` provides `WORKING_DIRECTORY`, test filtering, XML output
- GitHub Actions has native CTest support
- Already integrated into `CMakeLists.txt`

---

## 5. Directory Structure

```
openclaw-auto-dev/
├── .github/workflows/
│   ├── issue-check.yml        # Cron → scan issues
│   └── pr-merge.yml           # PR closed → update issue
├── agents/                    # Deprecated (dynamic routing now)
├── docs/
│   └── setup.md
├── logs/
│   └── pipeline-YYYY-MM-DD.log
├── openclaw/                  # Per-issue artifacts
│   └── {num}_{slug}/
│       ├── SPEC.md
│       └── TEST_REPORT.md
├── .pipeline-state/           # Pipeline state files
│   └── {issue}_stage          # JSON, deleted on completion
├── scripts/
│   ├── pipeline-runner.sh     # Main 4-stage orchestrator
│   ├── scan-issues.sh         # GitHub issue scanner
│   ├── cron-heartbeat.sh      # Cron wrapper + log rotation
│   ├── heartbeat-check.sh     # OpenClaw heartbeat probe
│   ├── notify-feishu.sh       # Feishu webhook notifier
│   ├── update-status.sh      # GitHub label updater
│   ├── check-conflicts.sh     # Branch conflict detector
│   └── validate-changes.sh   # Pre-commit validator
├── src/                       # C++ source & tests
│   ├── pipeline_state.h/.cpp  # State file R/W
│   ├── pipeline_notifier.h/.cpp # Notification formatter
│   ├── spawn_order.h/.cpp     # Stage sequence validator
│   ├── CMakeLists.txt         # Build + CTest config
│   ├── algorithm_test.cpp     # Algorithm lib tests
│   ├── pipeline_83_test.cpp   # Notifier tests
│   ├── pipeline_97_test.cpp   # State API tests
│   ├── pipeline_99_test.cpp   # Cron auto-process tests
│   ├── pipeline_102_test.cpp  # Scheme B tests
│   ├── pipeline_104_test.cpp  # Full auto trigger tests
│   ├── spawn_order_test.cpp   # Spawn order tests
│   └── [algorithm libs]       # quick_sort, matrix, etc.
├── Testing/                   # CMake test output (temp)
├── ARCHITECT.md               # This document
├── DESIGN.md                  # Legacy design (obsolete)
├── PLAN.md                    # Current sprint plan
├── README.md                  # Project overview
├── OPENCLAW.md                # Project config
├── AGENTS.md                  # Agent role definitions
├── HEARTBEAT.md               # Heartbeat config
├── HEARTBEAT-MECHANISM.md     # Heartbeat docs
└── project.yaml              # OpenClaw workspace metadata
```

---

## 6. Known Issues & Technical Debt

### 6.1 `pipeline_83_test` CTest Registration (Open)
`pipeline_83_test` executable exists but `add_test()` may be missing in some CMake configurations. Verify with `ctest --output-on-failure`.

### 6.2 `spawn_order_test` vs `spawn_order` Naming Inconsistency
The header/source file is `spawn_order` but the test is `spawn_order_test`. CMake target is `spawn_order_test`. Minor naming inconsistency.

### 6.3 `Testing/` Directory Untracked
CMake CTest generates `Testing/` directory with XML test results. Should be in `.gitignore` (currently is).

### 6.4 `0_stage` Spurious File
A file `.pipeline-state/0_stage` was left behind from testing (contains value `2`). Should be removed.

### 6.5 `DESIGN.md` Marked Obsolete
`DESIGN.md` is explicitly labeled "已过时" (obsolete). The current architecture lives in `ARCHITECT.md` and `PLAN.md`. DESIGN.md should be archived/deleted to avoid confusion.

### 6.6 `MULTI_AGENT_DESIGN.md` Referenced but Missing
`SPEC.md` (per-issue) references `MULTI_AGENT_DESIGN.md` which does not exist. Either create it or update the reference.

### 6.7 `ARCHITECTURE.md` vs `ARCHITECT.md`
Two naming conventions exist: `ARCHITECTURE.md` (root) and `ARCHITECT.md` (root). The correct canonical file appears to be `ARCHITECT.md`. The `ARCHITECTURE.md` was likely created by a previous Architect agent run and should be consolidated.

---

## 7. Dependencies

| Dependency | Purpose | Source |
|-----------|---------|--------|
| `gh` CLI | GitHub API (issues, PRs, labels) | External |
| `cmake` + `make` | C++ build | System |
| `ctest` | Test runner | CMake |
| `jq` | JSON parsing in shell scripts | System |
| `git` | Branch management, commits | System |
| OpenClaw | Agent orchestration | External skill |
| Feishu webhook | Notifications | External |

---

## 8. Revision History

| Date | Author | Change |
|------|--------|--------|
| 2026-04-06 | Architect Agent | Full rewrite — consolidated from ARCHITECTURE.md + PLAN.md + source analysis |
| 2026-04-06 | Architect Agent (prior) | Initial ARCHITECTURE.md created (later superseded) |
