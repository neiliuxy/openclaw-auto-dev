# openclaw-auto-dev 架构规划

## 1. 项目概述

**项目**: openclaw-auto-dev (neiliuxy/openclaw-auto-dev)
**用途**: GitHub Issue → PR 全自动 AI 驱动开发流水线
**核心机制**: 状态驱动的四 Agent 协作（Architect → Developer → Tester → Reviewer）

### 四 Agent 流水线

```
Issue 创建 (openclaw-new)
    │
    ▼
[Stage 0] Architect ──→ SPEC.md 生成
    │                     状态文件更新: stage=1
    ▼
[Stage 1] Developer ──→ 代码实现
    │                     状态文件更新: stage=2
    ▼
[Stage 2] Tester ──────→ TEST_REPORT.md
    │                     状态文件更新: stage=3
    ▼
[Stage 3] Reviewer ────→ PR 创建 + 合并
    │                     状态文件更新: stage=4
    ▼
Issue closed (openclaw-completed)
```

---

## 2. 当前系统状态分析

### 2.1 已有组件

| 组件 | 路径 | 状态 |
|------|------|------|
| Pipeline Runner | `scripts/pipeline-runner.sh` | ✅ 已实现 |
| 状态读写库 | `src/pipeline_state.cpp/h` | ✅ 已实现 |
| 心跳检查 | `scripts/heartbeat-check.sh` | ✅ 已实现 |
| Issue 扫描 | `scripts/scan-issues.sh` | ✅ 已实现 |
| Cron 触发脚本 | `scripts/cron-heartbeat.sh` | ✅ 已实现 |
| 飞书通知 | `scripts/notify-feishu.sh` | ✅ 已实现 |
| GitHub Actions | `.github/workflows/` | ✅ 已实现 |
| 状态文件目录 | `.pipeline-state/` | ⚠️ 存在但为空 |

### 2.2 测试覆盖

| 测试文件 | 对应 Issue | 状态 |
|----------|-----------|------|
| `pipeline_97_test.cpp` | Issue #97 | ⚠️ 失败 |
| `pipeline_99_test.cpp` | Issue #99 | ⚠️ 失败 |
| `pipeline_102_test.cpp` | Issue #102 | ⚠️ 失败 |
| `spawn_order_test.cpp` | 通用 | ✅ 通过 |

### 2.3 已知问题

**问题1: 状态文件格式不一致**
- **现象**: `pipeline-runner.sh` 写入 JSON 格式 `{"issue_num":102,"stage":2}`，但 C++ 测试期望纯整数格式
- **影响**: `pipeline_97_test`、`pipeline_99_test`、`pipeline_102_test` 均失败
- **根因**: `pipeline_state.cpp` 尝试 JSON 解析但 `read_stage()` 对简单整数的回退读取逻辑被 JSON 检测阻断

**问题2: 状态文件未持久化**
- **现象**: `.pipeline-state/` 目录为空（除了 pipeline_104）
- **根因**: 测试在 build/ 目录运行，但状态文件写入的是项目根目录

**问题3: 测试文件 vs 源码不同步**
- **现象**: `pipeline_102_test.cpp` 期望状态文件存在，但实际不存在
- **根因**: 测试在 build/ 目录执行，期望相对于 build/ 的路径

---

## 3. 架构改进计划

### 3.1 修复项 1: 统一状态文件格式

**文件**: `src/pipeline_state.cpp`

**问题**: JSON 格式写入，但读取时对简单纯数字格式的回退逻辑有缺陷

**修复方案**: 保持 JSON 格式为标准，修复 `read_stage()` 的回退逻辑

```cpp
// 读取逻辑修复：
// 1. 先尝试 JSON 解析（检测到 { 字符）
// 2. 如果 JSON 解析失败，尝试纯整数（旧格式兼容）
// 3. 如果都不是，返回 -1
```

### 3.2 修复项 2: 解决测试路径问题

**问题**: 测试在 `build/` 目录运行，状态文件路径解析错误

**修复方案**:
- 选项A: 让 `pipeline_state.cpp` 支持相对路径归一化到项目根目录
- 选项B: 测试运行前设置 `STATE_DIR` 为绝对路径

**推荐方案**: 测试 CMakeLists.txt 添加 `add_definitions(-DSTATE_DIR=\"${CMAKE_SOURCE_DIR}/.pipeline-state\")`

### 3.3 修复项 3: 补全 pipeline_104 的状态文件

Issue #104 需要完整跑完所有阶段，目前缺少状态文件。

---

## 4. 文件清单

### 4.1 需要修改的文件

| 文件 | 修改内容 |
|------|----------|
| `src/pipeline_state.cpp` | 修复 `read_stage()` JSON 解析回退逻辑 |
| `src/CMakeLists.txt` | 添加 STATE_DIR 定义支持绝对路径测试 |
| `scripts/pipeline-runner.sh` | 确保写入绝对路径状态文件 |
| `SPEC.md` (根目录) | 更新为当前准确的架构说明 |

### 4.2 需要创建的文件

| 文件 | 用途 |
|------|------|
| `.pipeline-state/104_stage` | Issue #104 当前阶段状态文件 |
| `src/pipeline_104_test.cpp` | Issue #104 的测试（如果缺失） |

### 4.3 状态文件规范

**路径格式**: `.pipeline-state/<issue_number>_stage`
**JSON 格式**（标准）:
```json
{"issue_num": 102, "stage": 3}
```
**纯整数格式**（旧兼容）:
```
3
```

---

## 5. 核心状态流转逻辑

```
                    ┌─────────────────────────────────────────┐
                    │           .pipeline-state/              │
                    │                                         │
  openclaw-new ──→ │ stage=0 (NotStarted)                    │
                    │                                         │
  ┌─────────────────▼──────────────────────────────────────┐ │
  │ Stage 1: Architect                                     │ │
  │  - 读取 Issue 标题/描述                                │ │
  │  - 生成 openclaw/<num>_<slug>/SPEC.md                 │ │
  │  - 写入 stage=1                                        │ │
  │  - 添加标签 openclaw-architecting                       │ │
  └─────────────────┬──────────────────────────────────────┘ │
                    │                                         │
  ┌─────────────────▼──────────────────────────────────────┐ │
  │ Stage 2: Developer                                     │ │
  │  - 读取 SPEC.md                                        │ │
  │  - 实现代码到 src/<slug>.cpp                           │ │
  │  - 写入 stage=2                                        │ │
  │  - 添加标签 openclaw-developing                         │ │
  └─────────────────┬──────────────────────────────────────┘ │
                    │                                         │
  ┌─────────────────▼──────────────────────────────────────┐ │
  │ Stage 3: Tester                                        │ │
  │  - 编译验证 (make)                                     │ │
  │  - 生成 openclaw/<num>_<slug>/TEST_REPORT.md          │ │
  │  - 写入 stage=3                                        │ │
  │  - 添加标签 openclaw-testing                           │ │
  └─────────────────┬──────────────────────────────────────┘ │
                    │                                         │
  ┌─────────────────▼──────────────────────────────────────┐ │
  │ Stage 4: Reviewer                                      │ │
  │  - 创建 PR (gh pr create)                              │ │
  │  - 合并 PR (gh pr merge)                               │ │
  │  - 写入 stage=4                                        │ │
  │  - 添加标签 openclaw-reviewing → openclaw-completed    │ │
  └─────────────────┬──────────────────────────────────────┘ │
                    │                                         │
                    │ stage=4 (PipelineDone)                   │
                    └─────────────────────────────────────────┘
```

---

## 6. 实施步骤

### Step 1: 修复 pipeline_state.cpp 的 JSON 回退逻辑
- 修改 `read_stage()` 函数，确保 JSON 检测失败时正确回退到纯整数读取

### Step 2: 修复测试 CMakeLists.txt 的路径问题
- 为测试添加正确的 STATE_DIR 绝对路径定义

### Step 3: 补全 Issue #104 状态文件
- 创建 `.pipeline-state/104_stage` 文件

### Step 4: 更新根目录 SPEC.md
- 同步为最新架构说明

### Step 5: 重新编译并运行测试验证
- `make clean && make -C build`
- 运行 `ctest` 验证修复结果

---

## 7. 测试验证矩阵

| 测试 | 验证点 | 期望结果 |
|------|--------|----------|
| pipeline_97_test | 状态文件读写 + 阶段描述转换 | 全部通过 |
| pipeline_99_test | Developer 阶段状态读写 | 全部通过 |
| pipeline_102_test | 全流程完整性检查 | 全部通过 |
| spawn_order_test | 多进程生成顺序 | 全部通过 |

---

## 8. 依赖关系图

```
scripts/pipeline-runner.sh
    │
    ├── reads: OPENCLAW.md (repo config)
    ├── reads: .pipeline-state/<issue>_stage
    ├── writes: .pipeline-state/<issue>_stage (JSON format)
    ├── creates: openclaw/<num>_<slug>/SPEC.md
    ├── creates: src/<slug>.cpp
    ├── creates: openclaw/<num>_<slug>/TEST_REPORT.md
    │
    └── calls:
            ├── src/pipeline_state.cpp (via compiled binary)
            ├── git (branch management)
            └── gh (GitHub API)

src/pipeline_state.cpp (C++ library)
    │
    ├── reads: .pipeline-state/<issue>_stage
    ├── writes: .pipeline-state/<issue>_stage
    └── formats: JSON {issue_num, stage}

tests/*.cpp
    │
    ├── use: src/pipeline_state.cpp
    └── run from: build/tests/
```
