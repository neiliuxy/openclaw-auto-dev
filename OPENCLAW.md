# OpenClaw Project Config

- repo: neiliuxy/openclaw-auto-dev
- default_branch: master
- src_dir: src
- build_cmd: mkdir -p build && cd build && cmake .. && make
- test_cmd: cd build && ctest
- languages: [cpp]

## Pipeline

Pipeline logic lives in `~/.openclaw/workspace/skills/openclaw-pipeline/`:
- `pipeline-runner.sh` — main orchestration
- `SKILL.md` — skill documentation
