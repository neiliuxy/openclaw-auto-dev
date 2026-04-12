# Multi-Agent Pipeline Design

> **Status**: Active — the current production design.  
> See also: [ARCHITECT.md](ARCHITECT.md) for the current Architect agent specification.

---

## Overview

`openclaw-auto-dev` uses a **4-agent sequential pipeline** to automate the full lifecycle from GitHub Issue to merged PR:

```
GitHub Issue (openclaw-new)
        │
        ▼
┌─────────────────┐
│   Architect     │  Stage 0 → 1
│  (Analysis)     │  Reads issue, produces SPEC.md
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Developer     │  Stage 1 → 2
│  (Implementation)│ Reads SPEC.md, writes code in src/
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Tester       │  Stage 2 → 3
│  (Verification) │  Builds code, runs tests, writes TEST_REPORT.md
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Reviewer      │  Stage 3 → 4
│  (Merge/Close)  │  Creates PR, merges if tests pass, deletes branch
└────────┬────────┘
         │
         ▼
  Pipeline Done (Stage 4)
  Issue closed, branch deleted
```

---

## Stage Definitions

| Stage | Value | Agent | Input | Output |
|-------|-------|-------|-------|--------|
| Initial | 0 | — | GitHub Issue label `openclaw-new` | — |
| Architect Done | 1 | Architect | Issue title + body | `openclaw/{issue}_{slug}/SPEC.md` |
| Developer Done | 2 | Developer | SPEC.md | `src/{slug}.cpp` (+ tests) |
| Tester Done | 3 | Tester | Source files | `openclaw/{issue}_{slug}/TEST_REPORT.md` |
| Pipeline Done | 4 | Reviewer | All artifacts | Merged PR, closed issue, deleted branch |

---

## State Management

### Source of Truth: `{issue}_stage` files

State is tracked via plain-text files in `.pipeline-state/`:

```
.pipeline-state/
├── 73_stage                  ← Current stage for issue #73 (JSON: {"stage": 2, ...})
├── 73_architect_output.md    ← Architect's detailed analysis for issue #73
└── pipeline_state.json       ← Global state mirror (kept in sync with {issue}_stage)
```

- **`{issue}_stage`** is the **canonical source of truth** for each issue's stage.
- **`pipeline_state.json`** is a mirror of the currently active issue's state. It is updated atomically whenever `{issue}_stage` advances (see `write_state()` in `scripts/pipeline-runner.sh`).
- On any inconsistency, trust `{issue}_stage` over `pipeline_state.json`.

### Stage File Format

```json
{"issue": 73, "stage": 2, "updated_at": "2026-04-12T22:25:00+0800", "error": null}
```

---

## Pipeline Runner

The pipeline is orchestrated by `scripts/pipeline-runner.sh`:

```bash
# Run all stages for a new issue
bash scripts/pipeline-runner.sh 73

# Resume from current stage (after interruption)
bash scripts/pipeline-runner.sh 73 --continue
```

Key behaviours:
- **Idempotent**: Each stage checks if its output already exists before re-running.
- **Atomic state sync**: Both `{issue}_stage` and `pipeline_state.json` are updated together on every stage transition.
- **Post-merge cleanup**: After the Reviewer stage merges a PR, the source branch (`openclaw/issue-<num>`) is deleted from the remote automatically.

---

## GitHub Labels

Labels communicate pipeline status on the GitHub Issue:

| Label | Meaning |
|-------|---------|
| `openclaw-new` | Queued for processing |
| `openclaw-architecting` | Stage 0 in progress |
| `openclaw-developing` | Stage 1 in progress |
| `openclaw-testing` | Stage 2 in progress |
| `openclaw-reviewing` | Stage 3 in progress |
| `openclaw-completed` | PR merged, issue closed |
| `openclaw-error` | Stage failed (check stage file for details) |

---

## CI Integration

GitHub Actions (`.github/workflows/ci.yml`) runs automatically on every PR and push to `main`:

```
cmake -B build → cmake --build build → ctest --test-dir build
```

This provides an automated quality gate before the Reviewer stage merges.

---

## File Layout

```
openclaw-auto-dev/
├── .github/
│   └── workflows/
│       └── ci.yml              ← CI: build + test on every PR
├── .pipeline-state/
│   ├── {issue}_stage           ← Per-issue stage (source of truth)
│   ├── {issue}_architect_output.md
│   └── pipeline_state.json     ← Global mirror
├── openclaw/
│   └── {issue}_{slug}/
│       ├── SPEC.md             ← Architect output
│       └── TEST_REPORT.md      ← Tester output
├── scripts/
│   └── pipeline-runner.sh      ← Main orchestrator
├── src/                        ← Production + test C++ code
│   └── CMakeLists.txt
├── ARCHITECT.md                ← Architect agent instructions
├── MULTI_AGENT_DESIGN.md       ← This file
└── README.md
```

---

*Last updated: 2026-04-12 by Pipeline Developer Agent (issue #73 system improvements)*
