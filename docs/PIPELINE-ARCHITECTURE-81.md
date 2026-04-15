# Issue #81 Architecture: 4-Session Pipeline Verification

## 1. 整体流程图（文字版）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CRON TRIGGER (主会话)                                  │
│                     openclaw cron --test-pipeline                            │
│                              │                                               │
│                              ▼                                               │
│                    sessions_spawn(                                           │
│                      runtime="agent",                                         │
│                      agent="pipeline-agent"     ← Pipeline Agent (Stage 0)   │
│                    )                                                         │
│                              │                                               │
│              ┌───────────────┼───────────────┬───────────────┐               │
│              ▼               ▼               ▼               ▼               │
│         [State OK?]      [State OK?]      [State OK?]      [State OK?]       │
│              │               │               │               │               │
│              ▼               ▼               ▼               ▼               │
│       Stage 1:          Stage 2:         Stage 3:       Stage 4:           │
│       Architect         Developer        Tester         Reviewer            │
│       sessions_         sessions_        sessions_       sessions_           │
│        spawn(developer)  spawn(tester)    spawn(reviewer) spawn(merge)       │
│              │               │               │               │               │
│              ▼               ▼               ▼               ▼               │
│     .pipeline-state/   .pipeline-state/ .pipeline-state/ .pipeline-state/    │
│     stage-1.json       stage-2.json      stage-3.json     stage-4.json      │
│              │               │               │               │               │
│              └───────────────┴───────────────┴───────────────┘               │
│                                        │                                      │
│                                        ▼                                      │
│                              状态持久化 + 标签更新                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

**触发链路:**
```
cron → 主会话 → sessions_spawn(Pipeline Agent)
                          │
                          ├── sessions_spawn(Architect) ──→ .pipeline-state/stage-1.json
                          │                                      ↓
                          │                               sessions_spawn(Developer) ──→ .pipeline-state/stage-2.json
                          │                                                        ↓
                          │                                                 sessions_spawn(Tester) ──→ .pipeline-state/stage-3.json
                          │                                                                  ↓
                          │                                                            sessions_spawn(Reviewer) ──→ .pipeline-state/stage-4.json
                          │                                                                               ↓
                          │                                                                        PR 合并 + label 更新
                          ▼
                     pipeline 完成
```

---

## 2. 各 Stage 职责

### Stage 1: Architect
- **触发条件**: Pipeline Agent 检查 `.pipeline-state/` 发现无完成记录
- **输入**: `agents/architect/task.txt`（若不存在则自动生成默认任务）
- **输出**: 
  - 生成设计文档 `agents/architect/design.md`
  - 写入 `.pipeline-state/stage-1.json`（status=completed）
- **session 配置**: `runtime="agent"`, `agent="architect"`, `timeout=300s`

### Stage 2: Developer
- **触发条件**: Stage 1 完成，读取 `.pipeline-state/stage-1.json` 确认 `status=completed`
- **输入**: `agents/developer/task.txt` + `agents/architect/design.md`
- **输出**:
  - 生成的代码文件
  - 写入 `.pipeline-state/stage-2.json`
- **session 配置**: `runtime="agent"`, `agent="developer"`, `timeout=600s`

### Stage 3: Tester
- **触发条件**: Stage 2 完成，读取 `.pipeline-state/stage-2.json` 确认
- **输入**: Stage 2 输出的代码 + `agents/tester/task.txt`
- **输出**:
  - 测试报告 `TEST_REPORT.md`
  - 写入 `.pipeline-state/stage-3.json`
- **session 配置**: `runtime="agent"`, `agent="tester"`, `timeout=300s`

### Stage 4: Reviewer
- **触发条件**: Stage 3 完成
- **输入**: 全部 pipeline 产物
- **输出**:
  - PR 合并（通过 `gh pr merge`）
  - 更新 Issue #81 标签（`gh issue add-labels`）
  - 写入 `.pipeline-state/stage-4.json`
- **session 配置**: `runtime="agent"`, `agent="reviewer"`, `timeout=180s`

---

## 3. 状态文件格式

### 全局 Pipeline 状态
**文件**: `.pipeline-state/pipeline.json`

```json
{
  "pipeline_id": "pipeline_1744697100",
  "issue": "#81",
  "started_at": 1744697100,
  "completed_at": null,
  "current_stage": 1,
  "status": "running",
  "stages": {
    "1": { "status": "completed", "session_id": "sess_xxx", "completed_at": 1744697110 },
    "2": { "status": "completed", "session_id": "sess_yyy", "completed_at": 1744697200 },
    "3": { "status": "running",   "session_id": "sess_zzz", "started_at":  1744697300 },
    "4": { "status": "pending",   "session_id": null }
  }
}
```

### Stage 级别状态文件

**`.pipeline-state/stage-1.json` (Architect)**
```json
{
  "stage": 1,
  "name": "architect",
  "status": "completed",
  "session_id": "sess_architect_81",
  "started_at": 1744697105,
  "completed_at": 1744697140,
  "output": {
    "design_doc": "agents/architect/design.md",
    "summary": "完成 Issue #81 的架构设计，输出 4-stage pipeline 方案"
  },
  "error": null
}
```

**`.pipeline-state/stage-2.json` (Developer)**
```json
{
  "stage": 2,
  "name": "developer",
  "status": "completed",
  "session_id": "sess_developer_81",
  "started_at": 1744697145,
  "completed_at": 1744697250,
  "output": {
    "files_created": ["src/pipeline_test.cpp", "tests/pipeline_test.cpp"],
    "summary": "实现 pipeline 测试代码，共 2 个文件"
  },
  "error": null
}
```

**`.pipeline-state/stage-3.json` (Tester)**
```json
{
  "stage": 3,
  "name": "tester",
  "status": "completed",
  "session_id": "sess_tester_81",
  "started_at": 1744697255,
  "completed_at": 1744697350,
  "output": {
    "test_report": "TEST_REPORT.md",
    "tests_passed": 10,
    "tests_failed": 0,
    "summary": "全部测试通过"
  },
  "error": null
}
```

**`.pipeline-state/stage-4.json` (Reviewer)**
```json
{
  "stage": 4,
  "name": "reviewer",
  "status": "completed",
  "session_id": "sess_reviewer_81",
  "started_at": 1744697355,
  "completed_at": 1744697450,
  "output": {
    "pr_merged": true,
    "pr_url": "https://github.com/xxx/pull/82",
    "labels_added": ["test-passed", "ready-to-merge"],
    "issue_labels_updated": ["verified"],
    "summary": "PR 已合并，Issue #81 标签已更新"
  },
  "error": null
}
```

### 当前 Stage 指示器
**文件**: `.pipeline-state/current_stage`
```
2
```
（表示当前正在执行 Stage 2）

---

## 4. 关键实现要点

### 4.1 Cron 触发器配置
```yaml
# .github/cron-pipeline.yml 或 openclaw cron 配置
cron:
  - name: pipeline-81-verification
    schedule: "0 12 * * *"  # 每天中午触发，或按需配置
    command: |
      sessions_spawn(
        runtime="agent",
        agent="pipeline-agent",
        labels=["pipeline", "issue-81"],
        metadata={issue: "81", test: "sessions_spawn_verification"}
      )
```

### 4.2 Pipeline Agent 主循环（伪代码）
```python
# Pipeline Agent (Stage 0) - 在主会话的 subagent 内运行
def pipeline_agent():
    pipeline_id = f"pipeline_{int(time.time())}"
    state_dir = f".pipeline-state/{pipeline_id}"
    os.makedirs(state_dir, exist_ok=True)
    
    # 初始化 pipeline.json
    write_state(f"{state_dir}/pipeline.json", {
        "pipeline_id": pipeline_id,
        "status": "running",
        "current_stage": 1
    })
    
    # 按顺序执行 4 个 stage
    stages = ["architect", "developer", "tester", "reviewer"]
    for idx, stage_name in enumerate(stages, start=1):
        # 写入 current_stage 指示器
        write_file(f"{state_dir}/current_stage", str(idx))
        
        # 检查前置 stage 是否完成（stage 1 跳过）
        if idx > 1:
            prev_state = read_json(f"{state_dir}/stage-{idx-1}.json")
            if prev_state.get("status") != "completed":
                raise RuntimeError(f"Stage {idx-1} 未完成，pipeline 中止")
        
        # sessions_spawn 创建子会话
        session = sessions_spawn(
            runtime="agent",
            agent=stage_name,
            parent_session=curr_session_id,  # 建立父子关系
            timeout=TIMEOUTS[stage_name],
            metadata={
                "pipeline_id": pipeline_id,
                "stage": idx,
                "state_dir": state_dir
            }
        )
        
        # 等待子会话完成
        result = wait_for_session(session)
        
        # 保存 stage 结果
        write_json(f"{state_dir}/stage-{idx}.json", {
            "stage": idx,
            "name": stage_name,
            "status": "completed",
            "session_id": session.id,
            "output": result.output,
            "completed_at": int(time.time())
        })
    
    # 所有 stage 完成，更新 pipeline.json
    write_json(f"{state_dir}/pipeline.json", {
        "status": "completed",
        "completed_at": int(time.time())
    })
    
    return f"Pipeline {pipeline_id} 完成"
```

### 4.3 状态依赖检查
```python
def check_stage_ready(state_dir: str, required_stage: int) -> bool:
    """检查前置 stage 是否完成"""
    if required_stage == 1:
        return True  # Stage 1 无前置依赖
    prev_file = Path(state_dir) / f"stage-{required_stage - 1}.json"
    if not prev_file.exists():
        return False
    data = json.loads(prev_file.read_text())
    return data.get("status") == "completed"
```

### 4.4 每个 Stage Agent 的标准接口
```python
# agents/<stage>/SKILL.md 或 task.txt
STAGE_PROMPT = """
你是 {stage_name} Agent，负责 Pipeline Stage {stage}。
读取 {state_dir}/stage-{prev}.json 获取前置 stage 输出。
完成后：
1. 将结果写入 {state_dir}/stage-{current}.json
2. 报告完成状态
"""
```

### 4.5 目录结构
```
openclaw-auto-dev/
├── .pipeline-state/                 # Pipeline 状态目录
│   ├── current_stage               # 当前执行阶段（1/2/3/4）
│   ├── pipeline_{timestamp}/        # 单次 pipeline 运行目录
│   │   ├── pipeline.json            # 全局状态
│   │   ├── stage-1.json             # Architect 结果
│   │   ├── stage-2.json             # Developer 结果
│   │   ├── stage-3.json             # Tester 结果
│   │   └── stage-4.json             # Reviewer 结果
│   └── latest -> pipeline_{xxx}    # 符号链接，指向最新一次运行
├── agents/
│   ├── architect/
│   │   ├── SKILL.md                 # Architect Agent 指引
│   │   ├── task.txt                 # Architect 任务描述
│   │   └── design.md                # 输出：设计文档
│   ├── developer/
│   │   ├── SKILL.md
│   │   ├── task.txt
│   │   └── ...                      # 输出：代码文件
│   ├── tester/
│   │   ├── SKILL.md
│   │   ├── task.txt
│   │   └── ...                      # 输出：测试报告
│   └── reviewer/
│       ├── SKILL.md
│       ├── task.txt
│       └── ...                      # 输出：PR/标签
└── scripts/
    └── pipeline_runner.sh           # 可选：命令行快速测试脚本
```

### 4.6 验证 sessions_spawn 在 subagent 内工作的关键点

| 验证点 | 实现方式 |
|--------|----------|
| **subagent 内 spawn** | Pipeline Agent 在 subagent 内运行，直接调用 `sessions_spawn` |
| **父子 session 关系** | `parent_session` 参数建立层级关系 |
| **状态隔离** | 每个子会话通过 `state_dir` + `pipeline_id` 隔离 |
| **超时控制** | 各 stage 配置独立 `timeout`，防止单 stage 阻塞 |
| **错误恢复** | 读取前置 stage 状态，若失败则 pipeline 中止 |
| **幂等性** | 可通过 `current_stage` 指示器实现断点续跑 |

---

## 5. 测试用例设计（Issue #81 验证目标）

| 测试项 | 预期结果 | 验证方法 |
|--------|----------|----------|
| cron → 主会话 spawn | 主会话成功创建 Pipeline Agent | cron log + pipeline.json |
| Pipeline Agent → Architect spawn | Architect session 创建成功 | stage-1.json session_id 非空 |
| Architect → Developer spawn | Developer session 创建成功 | stage-2.json 存在 |
| Developer → Tester spawn | Tester session 创建成功 | stage-3.json 存在 |
| Tester → Reviewer spawn | Reviewer session 创建成功 | stage-4.json 存在 |
| Reviewer → PR merge | PR 合并成功 | gh pr view --state=merged |
| Reviewer → label update | Issue #81 标签更新 | gh issue view --labels |
| 状态持久化 | 所有 stage 状态写入 .pipeline-state/ | 文件内容完整性检查 |
| 错误恢复 | 中断后从 current_stage 续跑 | 人为中断 + 续跑验证 |

---

## 6. 工作目录

- **项目根目录**: `/home/admin/.openclaw/workspace/openclaw-auto-dev`
- **Pipeline 状态**: `/home/admin/.openclaw/workspace/openclaw-auto-dev/.pipeline-state/`
- **Agent 定义**: `/home/admin/.openclaw/workspace/openclaw-auto-dev/agents/`
