# Agents Directory - DEPRECATED

> **Deprecated**: 2026-04-26
> **Reason**: This directory contained static task files that are no longer used.
> The OpenClaw pipeline now uses dynamic task injection via skills.

## Historical Content

This directory previously contained:
- `agents/developer/task.txt` - Static developer task template
- `agents/tester/` - Empty directory (placeholder)
- `agents/README.md` - This file

## Current Pipeline

The actual pipeline logic is in:
- `~/.openclaw/workspace/skills/openclaw-pipeline/`
- `scripts/pipeline-runner.sh`

## Why This Change

The static task files were a legacy approach. The current OpenClaw multi-agent
pipeline injects tasks dynamically based on:
1. The current stage (0-4)
2. The issue being processed
3. The SPEC.md requirements from the Architect stage

This approach is more flexible and keeps task definitions close to the
pipeline execution logic rather than scattered in this directory.

---

*This file serves as documentation of the deprecation. The original task.txt
files have been removed to avoid confusion.*
