# openclaw-auto-dev Architecture Document

> **Pipeline Stage**: 0 (Architect)
> **Branch**: `auto-dev`
> **Created**: 2026-03-31

---

## 1. Project Overview

### 1.1 Project Name
**openclaw-auto-dev** (`neiliuxy/openclaw-auto-dev`)

### 1.2 Purpose
AI-driven GitHub Issue → Pull Request automation pipeline using OpenClaw multi-agent orchestration. The system automatically processes GitHub Issues through a four-stage agent pipeline and creates merged PRs upon completion.

### 1.3 Core Workflow

```
Issue Created (label: openclaw-new)
    │
    ▼
[Stage 0] Architect Agent
    │  → Analyzes issue, writes SPEC.md
    │  → Creates/updates .pipeline-state/<num>_stage file
    │  → Advances stage to 1
    ▼
[Stage 1] Developer Agent
    │  → Implements code per SPEC.md
    │  → Advances stage to 2
    ▼
[Stage 2] Tester Agent
    │  → Validates implementation, writes TEST_REPORT.md
    │  → Advances stage to 3
    ▼
[Stage 3] Reviewer Agent
    │  → Creates PR, merges if all checks pass
    │  → Advances stage to 4
    ▼
PR Merged → Issue closed (label: openclaw-completed)
```

---

## 2. Architecture Decisions

### 2.1 State-Driven Pipeline

**Decision**: Use flat files in `.pipeline-state/` directory as pipeline state instead of GitHub Labels or external databases.

**Rationale**:
- Simple to read/write from both shell scripts and C++ code
- No external dependencies beyond the repo filesystem
- Atomic operations possible via `mv`/`rename`
- Lightweight compared to external state services

**State File Format**:
```
# JSON format (current standard)
{"issue": 102, "stage": 2, "status": "pending", "started_at": "2026-03-31T12:00:00+08:00", "completed_at": null}

// Legacy plain-integer format (still parsed for backward compatibility)
// e.g., content: "2"
```

**State File Naming**: `<issue_number>_stage` (e.g., `102_stage`)

### 2.2 Multi-Agent Coordination

**Decision**: Four distinct agent roles with explicit handoff via state files.

| Stage | Agent | Output | Next Stage |
|-------|-------|--------|------------|
| 0 | Architect | `openclaw/<num>_*/SPEC.md` | 1 |
| 1 | Developer | Code commits on `openclaw/issue-<num>` | 2 |
| 2 | Tester | `openclaw/<num>_*/TEST_REPORT.md` | 3 |
| 3 | Reviewer | Merged PR | 4 (done) |

**Rationale**: Separation of concerns allows each agent to focus. State file acts as explicit contract between stages.

### 2.3 Language & Tooling

| Component | Language/Tool | Rationale |
|-----------|---------------|------------|
| Pipeline Scripts | Bash | GitHub Actions compatibility, simplicity |
| State Library | C++ | Reusable across C++ test binaries |
| Tests | C++ assert framework | In-tree, no external test dependencies |
| Build System | CMake | Standard C++ build, multi-platform |

### 2.4 Branching Strategy

**Pattern**: Each issue gets a dedicated branch `openclaw/issue-<number>`

**Rationale**:
- Easy to identify which branch belongs to which issue
- Avoids conflicts with `main` branch protection
- Clear PR history linking issue → implementation

---

## 3. Module Breakdown

### 3.1 Core Pipeline Modules

#### `scripts/pipeline-runner.sh`
**Purpose**: Main pipeline orchestration script
**Location**: Project root or pipeline skill
**Functions**:
- Read current stage from state file
- Dispatch to appropriate agent based on stage
- Update state file after each stage completion
- Handle errors and recovery

#### `src/pipeline_state.cpp` / `src/pipeline_state.h`
**Purpose**: State file read/write utilities for C++ code
**Functions**:
- `read_stage(issue_number, state_dir)` → int (stage number or -1)
- `write_stage(issue_number, stage, state_dir)` → bool
- `write_stage_with_error(issue_number, stage, error, state_dir)` → bool
- `stage_to_description(stage)` → string

#### `scripts/heartbeat-check.sh`
**Purpose**: Periodic scan for new issues to process
**Trigger**: OpenClaw heartbeat (configurable interval)
**Logic**:
1. Check if any issue currently in progress (stage file exists, stage < 4)
2. If in-progress: skip (single-threaded processing)
3. If not: scan for `openclaw-new` labeled issues
4. Pick first new issue and trigger pipeline-runner

#### `scripts/scan-issues.sh`
**Purpose**: Query GitHub for issues by label/state
**Output**: JSON with issue number, title, labels

### 3.2 Agent-Specific Modules

#### Architect Agent
**Input**: GitHub Issue (openclaw-new label)
**Output**: `openclaw/<issue_num>_<slug>/SPEC.md`
**Key Sections**:
- Issue summary and acceptance criteria
- Functional decomposition
- Technical approach
- File changes summary
- Verification checklist

#### Developer Agent
**Input**: `SPEC.md` from Architect stage
**Output**: Code implementation committed to `openclaw/issue-<num>` branch
**Requirements**:
- Follow existing code style (C++98/11, header-inl pattern)
- Add tests in `src/<feature>_test.cpp`
- Update `CMakeLists.txt` if needed

#### Tester Agent
**Input**: Developer implementation
**Output**: `openclaw/<issue_num>_<slug>/TEST_REPORT.md`
**Verification**:
- Build success: `make`
- Tests pass: `make test`
- Manual validation checklist from SPEC.md

#### Reviewer Agent
**Input**: Tester report
**Actions**:
- Create PR from `openclaw/issue-<num>` → `main`
- Verify CI checks pass
- Auto-merge if all checks green
- Handle conflicts or request changes if needed

### 3.3 Supporting Modules

#### `src/CMakeLists.txt`
Build configuration for all C++ source files

#### `openclaw/<num>_<slug>/`
Per-issue workspace containing SPEC.md, TEST_REPORT.md, and any artifacts

#### `.github/workflows/`
GitHub Actions workflows for CI/CD

---

## 4. Current System Status

### 4.1 Working Components ✅

| Component | Status | Notes |
|-----------|--------|-------|
| Pipeline runner | ✅ Functional | Processes stages 0-3 correctly |
| State file I/O | ✅ Functional | JSON format, backward compat with plain int |
| CMake build | ✅ Functional | All sources compile |
| spawn_order_test | ✅ Passing | General pipeline flow test |
| heartbeat-check.sh | ✅ Functional | Scans for new issues |
| Issue completion flow | ✅ Working | Multiple issues merged (e.g., #64, #73, #99) |

### 4.2 Known Issues ⚠️

| Issue | Description | Impact |
|-------|-------------|--------|
| NO_STAGE_FILES logs | Frequent `NO_STAGE_FILES_*.log` entries in .pipeline-state/ | Normal - indicates no issues need processing |
| Stale branch cleanup | Old `openclaw/issue-*` branches not deleted after merge | Minor - accumulates stale branches |
| agents/ directory deprecated | Old static task files still present but ignored | Minor - legacy confusion |

### 4.3 Recent Activity

**Latest merged issues**: #64 (binary tree), #73 (min_stack CMake), #99, #102, #104
**Pipeline scan status**: Idle - no new issues to process

---

## 5. Implementation Plan

### Stage 0 Complete — Architect Output: ARCHITECT.md

### Stage 1 (Developer) — To Do

Based on the current codebase analysis, the following improvements are recommended:

#### Step 1: Clean up deprecated agents/ directory
- **Files**: `agents/README.md`, `agents/architect/task.txt`, `agents/developer/task.txt`
- **Action**: Move to `agents/README.deprecated.md` or delete if truly unused
- **Rationale**: These are legacy static task files; current pipeline uses dynamic injection

#### Step 2: Add branch cleanup to pipeline
- **Files**: `scripts/pipeline-runner.sh` or new `scripts/cleanup-branches.sh`
- **Action**: After PR merge, delete the feature branch
- **Command**: `git push origin --delete openclaw/issue-<num>`

#### Step 3: Document pipeline skill dependency
- **Files**: `OPENCLAW.md`, `README.md`
- **Action**: Clarify that the actual pipeline logic lives in `~/.openclaw/workspace/skills/openclaw-pipeline/`
- **Rationale**: Current docs don't clearly indicate where the pipeline skill is located

#### Step 4: Add automated build verification to PR checks
- **Files**: `.github/workflows/ci.yml` (create if missing)
- **Action**: Ensure `make && make test` runs on every PR

#### Step 5: Consider adding auto-dev branch automation
- **Observation**: `auto-dev` branch created for this pipeline run
- **Action**: If `auto-dev` is meant for continuous development, ensure it has CI configured

---

## 6. What the Developer Agent Should Do Next

### Primary Task: Address the 5 implementation steps above

**Priority Order**:
1. **Step 1** (Cleanup) — Lowest risk, immediate value
2. **Step 3** (Documentation) — Clarifies system understanding
3. **Step 2** (Branch cleanup) — Improves repo hygiene
4. **Step 4** (CI verification) — Quality gate
5. **Step 5** (auto-dev CI) — Only if auto-dev is a sustained branch

### Expected Deliverables

1. **Cleanup PR**: Delete/move deprecated agent files
2. **Enhancement PR**: Branch cleanup + docs update + CI improvements
3. **State**: After changes, commit with message following pipeline convention

### Files to Modify

- `agents/README.md` → deprecate or remove
- `agents/architect/` → deprecate or remove  
- `agents/developer/` → deprecate or remove
- `README.md` → update pipeline skill location
- `OPENCLAW.md` → already exists, review accuracy
- `.github/workflows/` → check/create `ci.yml`
- `scripts/` → add `cleanup-branches.sh` if needed

### Testing

- Ensure `make && make test` still passes after any changes
- Verify existing pipeline tests (`pipeline_*_test`) still work

---

## 7. Pipeline State Transitions

```
                    ┌─────────────────────────────────────────────────────┐
                    │                                             stage │
                    ▼                                                   │
openclaw-new ──[SCAN]──► 0 (Architect) ──────────────────► 1 (Developer)  │
                                                               │         │
                                                               ▼         │
                                    4 (PipelineDone) ◄──── 3 (Reviewer)  │
                                           ▲            │                │
                                           │            ▼                │
                                     PR merged    2 (Tester)             │
                                           ▲            │                │
                                           │            ▼                │
                                        [MERGE]     1 (Developer) ───────┘
                                                               ▲
                                                               │
                                                         0 (Architect)
```

---

## 8. Key Files Reference

| Path | Purpose |
|------|---------|
| `src/pipeline_state.cpp` | State file I/O |
| `src/pipeline_state.h` | Header |
| `scripts/pipeline-runner.sh` | Pipeline orchestration |
| `scripts/heartbeat-check.sh` | Issue scanner |
| `scripts/scan-issues.sh` | GitHub issue query |
| `openclaw/<num>_*/SPEC.md` | Per-issue specifications |
| `openclaw/<num>_*/TEST_REPORT.md` | Per-issue test reports |
| `.pipeline-state/<num>_stage` | Per-issue state file |
| `CMakeLists.txt` | Build config |
| `src/CMakeLists.txt` | Source build config |
| `OPENCLAW.md` | Project metadata |
| `project.yaml` | LLM and build config |

---

*Generated by Architect Agent — Pipeline v5, Stage 0*
