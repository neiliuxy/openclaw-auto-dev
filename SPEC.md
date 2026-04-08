# SPEC.md — openclaw-auto-dev 架构规格说明书

> **项目**: neiliuxy/openclaw-auto-dev
> **版本**: 2.0
> **更新日期**: 2026-04-09
> **状态**: 架构已完成，等待 Developer 实现

---

## 1. 项目概述

### 1.1 项目定位

openclaw-auto-dev 是一个**状态驱动的多 Agent 全自动开发流水线**，实现从 GitHub Issue 创建到 PR 合并的端到端自动化。系统由四个专门的 Agent 角色协作完成软件开发的完整生命周期。

### 1.2 核心目标

1. **全自动化**: Issue 创建 → PR 合并，全程无需人工干预
2. **状态可追踪**: 每个阶段的状态持久化到文件系统
3. **可审计**: 所有变更都有 Git 历史记录
4. **可复用**: 四阶段架构可适配不同类型的软件项目

### 1.3 端到端流程

```
用户创建 Issue + 添加 openclaw-new 标签
         │
         ▼
  ┌─────────────────────┐
  │  Heartbeat Scanner  │  (cron 或手动触发)
  └─────────────────────┘
         │
         ▼
  ┌──────────────┐   Stage 0    ┌──────────────┐
  │   Architect  │─────────────→│  SPEC.md     │
  │   (需求分析)   │              │  (需求规格)   │
  └──────────────┘              └──────────────┘
         │
         ▼  Stage 1
  ┌──────────────┐              ┌──────────────┐
  │   Developer  │─────────────→│  源代码实现   │
  │   (代码实现)   │              │  src/*.cpp   │
  └──────────────┘              └──────────────┘
         │
         ▼  Stage 2
  ┌──────────────┐              ┌──────────────┐
  │    Tester    │─────────────→│ TEST_REPORT  │
  │   (测试验证)   │              │  *.md        │
  └──────────────┘              └──────────────┘
         │
         ▼  Stage 3
  ┌──────────────┐              ┌──────────────┐
  │   Reviewer   │─────────────→│  PR Merged   │
  │   (合并决策)   │              │  + Issue CL  │
  └──────────────┘              └──────────────┘
```

---

## 2. 四阶段流水线

### 2.1 阶段定义

| Stage | Agent | 产出物 | 状态值 |
|-------|-------|--------|--------|
| 0 | NotStarted | 初始状态文件创建 | 0 |
| 1 | ArchitectDone | `openclaw/{num}_{slug}/SPEC.md` | 1 |
| 2 | DeveloperDone | `src/{slug}.{h,cpp}` + push | 2 |
| 3 | TesterDone | `openclaw/{num}_{slug}/TEST_REPORT.md` | 3 |
| 4 | PipelineDone | PR 已合并 | 4 |

### 2.2 状态转换规则

```
NotStarted(0)
    │ 创建 .pipeline-state/{issue}_stage，内容: {"issue":N,"stage":0,...}
    ▼
ArchitectDone(1)
    │ Architect Agent 分析 Issue，生成 SPEC.md，push 到远程分支
    │ 状态更新: stage=1
    ▼
DeveloperDone(2)
    │ Developer Agent 读取 SPEC.md，实现所有功能点
    │ 状态更新: stage=2
    ▼
TesterDone(3)
    │ Tester Agent 逐条验证 SPEC.md 中的功能点
    │ 状态更新: stage=3
    ▼
PipelineDone(4)
    │ Reviewer Agent 创建 PR 并合并
    │ 清理 .pipeline-state/{issue}_stage
    │ 标签更新: openclaw-completed
    ▼
    Issue closed
```

### 2.3 触发方式

1. **手动触发**: `bash scripts/pipeline-runner.sh <issue_number>`
2. **断点续跑**: `bash scripts/pipeline-runner.sh <issue_number> --continue`
3. **心跳自动触发**: `scripts/heartbeat-check.sh` 扫描 `openclaw-new` 标签的 Issue
4. **GitHub Actions cron**: `.github/workflows/issue-check.yml` 每 30 分钟触发

---

## 3. 状态文件规范

### 3.1 文件路径

```
.pipeline-state/{issue_number}_stage
```

示例: `.pipeline-state/104_stage`

### 3.2 JSON 格式（标准）

```json
{
  "issue": 104,
  "stage": 2,
  "updated_at": "2026-03-31T20:20:00+0800",
  "error": null
}
```

### 3.3 旧格式兼容

纯整数格式（如 `2`）仍可读取，写入统一为 JSON 格式。

### 3.4 无效文件（应删除）

| 文件 | 说明 |
|------|------|
| `0_stage` | 无效文件，issue 编号不能为 0 |
| `plan.json` | 垃圾文件，应删除 |

---

## 4. 核心组件

### 4.1 状态管理层 (`src/pipeline_state.h/cpp`)

**职责**: 状态文件读写，支持 JSON 和纯整数格式兼容

**主要接口**:
```cpp
namespace pipeline {
    enum class PipelineStage {
        NotStarted = 0,
        ArchitectDone = 1,
        DeveloperDone = 2,
        TesterDone = 3,
        PipelineDone = 4
    };

    struct PipelineState {
        int issue;
        int stage;
        std::string updated_at;
        std::string error;
    };

    // 读取 stage 值（0-4）
    int read_stage(int issue_number, const std::string& state_dir = ".pipeline-state");

    // 写入 stage 值（JSON 格式）
    bool write_stage(int issue_number, int stage, const std::string& state_dir = ".pipeline-state");

    // 写入 stage 值（带错误信息）
    bool write_stage_with_error(int issue_number, int stage, const std::string& error,
                                 const std::string& state_dir = ".pipeline-state");

    // 读取完整状态对象
    PipelineState read_state(int issue_number, const std::string& state_dir = ".pipeline-state");

    // stage 值转人类可读描述
    std::string stage_to_description(int stage);
}
```

**文件格式**:
- 读取: 优先尝试 JSON 解析，失败则回退到纯整数
- 写入: 统一 JSON 格式 `{ "issue": N, "stage": N, "updated_at": "...", "error": null }`

### 4.2 通知管理层 (`src/pipeline_notifier.h/cpp`)

**职责**: 四阶段通知消息格式化（用于 Feishu 飞书通知）

**主要接口**:
```cpp
namespace pipeline {
    enum class Stage { Architect, Developer, Tester, Reviewer };

    class PipelineNotifier {
    public:
        explicit PipelineNotifier(int issue_number);
        std::string notify_architect(const std::string& artifact);
        std::string notify_developer(const std::string& artifact);
        std::string notify_tester(const std::string& artifact);
        std::string notify_reviewer(const std::string& artifact);
    };
}
```

### 4.3 顺序验证层 (`src/spawn_order.h/cpp`)

**职责**: 验证 pipeline 阶段的执行顺序正确性，防止跳跃或回退

**主要接口**:
```cpp
namespace spawn_order {
    // 验证 current_stage → next_stage 是否合法
    bool validate_sequence(int current_stage, int next_stage);

    // 获取 stage 对应的人类可读名称
    std::string get_stage_name(int stage);
}
```

**合法转换**:
```
0 → 1  (NotStarted → ArchitectDone)
1 → 2  (ArchitectDone → DeveloperDone)
2 → 3  (DeveloperDone → TesterDone)
3 → 4  (TesterDone → PipelineDone)
4 → 4  (PipelineDone → PipelineDone, 幂等)
```

**非法转换**（抛出错误）:
- 0 → 2, 0 → 3, 0 → 4（跳过 Architect）
- 1 → 3, 1 → 4（跳过 Developer）
- 2 → 4（跳过 Tester）
- 任何回退（如 3 → 2）

### 4.4 流水线运行器 (`scripts/pipeline-runner.sh`)

**职责**: 协调四阶段执行，状态文件管理，GitHub API 调用

**主要函数**:
```bash
run_pipeline <issue_num> [continue_mode]
```

**流程**:
1. 读取当前 stage
2. 根据 stage 调用对应 Agent
3. Agent 完成后更新状态文件
4. 发送飞书通知
5. 推送分支到 origin

### 4.5 心跳扫描 (`scripts/heartbeat-check.sh`)

**职责**: 检测 `openclaw-new` 标签的 Issue，自动触发 pipeline

```bash
# 检测逻辑
gh issue list --label "openclaw-new" --state open
# 对每个找到的 Issue:
#   1. 检查是否已有状态文件
#   2. 如果没有，运行 pipeline-runner.sh
```

---

## 5. 目录结构

```
openclaw-auto-dev/
├── .github/workflows/          # GitHub Actions
│   ├── cmake-tests.yml        # CMake + CTest CI
│   ├── issue-check.yml        # Issue 状态检查（cron）
│   └── pr-merge.yml           # PR 自动合并
├── .pipeline-state/            # 状态文件目录
│   └── {issue}_stage          # 状态文件（JSON 格式）
├── .validation/               # Issue 验证配置
│   └── issue-*.conf           # 各 Issue 的验证配置
├── agents/                    # [已废弃] 静态 Agent 任务目录
├── build/                     # CMake 构建目录（不提交）
├── docs/                      # 文档
│   └── setup.md               # 安装配置说明
├── logs/                      # 日志目录
├── openclaw/                  # Issue 工作目录
│   └── {num}_{slug}/
│       ├── SPEC.md            # 需求规格说明书
│       └── TEST_REPORT.md     # 测试验证报告
├── scripts/                   # Shell 脚本
│   ├── pipeline-runner.sh    # 流水线运行器
│   ├── heartbeat-check.sh     # 心跳扫描
│   ├── cron-check.sh          # Cron 定时检查
│   ├── scan-issues.sh         # Issue 扫描
│   ├── notify-feishu.sh       # 飞书通知
│   ├── validate-changes.sh    # 变更验证
│   ├── check-conflicts.sh     # 冲突检查
│   ├── cron-heartbeat.sh      # 心跳定时任务
│   └── update-status.sh       # 状态更新
├── src/                       # C++ 源代码
│   ├── pipeline_state.h/cpp   # 状态管理
│   ├── pipeline_notifier.h/cpp# 通知管理
│   ├── spawn_order.h/cpp      # 顺序验证
│   ├── algorithm_test.cpp     # 算法单元测试
│   ├── pipeline_*_test.cpp    # Pipeline 集成测试
│   ├── quick_sort.h/cpp       # 快速排序
│   ├── matrix.h/cpp           # 矩阵运算
│   ├── min_stack.h/cpp        # 最小栈
│   ├── binary_tree.h/cpp      # 二叉树
│   ├── string_utils.h/cpp     # 字符串工具
│   ├── ini_parser.h/cpp       # INI 解析器
│   ├── logger.h/cpp           # 日志工具
│   ├── date_utils.h/cpp       # 日期工具
│   ├── file_finder.h/cpp      # 文件查找
│   ├── singleton.h            # 单例模式
│   └── CMakeLists.txt        # 构建配置
├── tests/                     # 额外测试
│   └── CMakeLists.txt
├── CMakeLists.txt             # 顶层 CMake 配置
├── project.yaml               # 项目配置
├── OPENCLAW.md              # OpenClaw 项目元数据
├── AGENTS.md                 # Agent 说明文档
├── HEARTBEAT.md              # 心跳机制说明
├── SPEC.md                   # 本文档（架构规格）
├── ARCHITECTURE.md            # 架构设计文档
├── README.md                 # 项目主文档
└── DESIGN.md                 # [已过时] 旧设计文档
```

---

## 6. 构建与测试

### 6.1 构建

```bash
mkdir -p build && cd build
cmake ..
make -j$(nproc)
```

### 6.2 测试

```bash
ctest --output-on-failure
```

### 6.3 CTest 注册的测试

| 测试名称 | 对应功能 | 验证内容 |
|----------|---------|---------|
| `spawn_order_test` | spawn_order | 阶段顺序验证 |
| `pipeline_97_test` | pipeline_state | 状态文件读写 |
| `pipeline_83_test` | pipeline_notifier | 通知消息格式化 |
| `pipeline_99_test` | pipeline state | Developer 阶段状态 |
| `pipeline_102_test` | 全流程 | 端到端完整性 |
| `pipeline_104_test` | 自动触发 | pipeline 全自动触发 |
| `algorithm_test` | 算法库 | 基础算法单元测试 |

---

## 7. GitHub Labels

| 标签 | 含义 | 阶段 |
|------|------|------|
| `openclaw-new` | 新 Issue，等待处理 | 入口 |
| `openclaw-architecting` | Stage 1 进行中 | Architect |
| `openclaw-developing` | Stage 2 进行中 | Developer |
| `openclaw-testing` | Stage 3 进行中 | Tester |
| `openclaw-reviewing` | Stage 4 进行中 | Reviewer |
| `openclaw-completed` | 已合并 | 出口 |
| `openclaw-error` | 失败 | 错误状态 |

---

## 8. API 规范

### 8.1 状态文件 API

#### 读取状态
```bash
# 方式1: 读取纯 stage 值
cat .pipeline-state/{issue}_stage | grep -o '"stage":[0-9]' | cut -d: -f2

# 方式2: 读取完整 JSON
cat .pipeline-state/{issue}_stage
```

#### 写入状态
```bash
# JSON 格式
echo '{"issue":104,"stage":2,"updated_at":"2026-04-09T00:00:00+0800","error":null}' \
  > .pipeline-state/104_stage
```

### 8.2 GitHub API

```bash
# 列出 openclaw-new 标签的 Issue
gh issue list --label "openclaw-new" --state open --json number,title

# 添加标签
gh issue edit {issue_num} --add-label "openclaw-architecting"

# 移除标签
gh issue edit {issue_num} --remove-label "openclaw-new"

# 创建 PR
gh pr create --title "fix: ..." --body "..." --base master --head {branch}

# 合并 PR
gh pr merge {pr_num} --squash --delete-branch
```

---

## 9. 已知问题

### Issue 1: `0_stage` 和 `plan.json` 垃圾文件
- **问题**: `.pipeline-state/` 目录中存在无效文件
- **状态**: 待清理

### Issue 2: PR #11, #125, #132 未合并
- **问题**: 存在 3 个 open PRs 长时间未处理
- **状态**: 待 Reviewer 处理

### Issue 3: Issue #90 和 #73 状态异常
- **问题**: Issue #90 标记为 `openclaw-completed` 但 Issue #73 仍处于 `stage/3-reviewed, stage/4-done`
- **状态**: 待调查

---

## 10. 测试策略

### 10.1 单元测试（CTest）

每个核心组件（pipeline_state, pipeline_notifier, spawn_order）都有对应的 `*_test.cpp` 文件，通过 CTest 统一管理。

### 10.2 集成测试（Pipeline Tests）

`pipeline_*_test.cpp` 系列测试模拟完整的 pipeline 执行流程：
- `pipeline_97_test`: 状态文件读写
- `pipeline_102_test`: 端到端 pipeline
- `pipeline_104_test`: 自动触发验证

### 10.3 验收测试

每个 Issue 完成后，Tester Agent 生成 `TEST_REPORT.md`，包含：
- SPEC.md 中每条功能点的验证结果
- 测试用例执行记录
- 最终结论（通过/失败）

---

## 11. 设计决策

### 11.1 为什么用状态文件而非数据库？

- **简单性**: 文件系统天然支持幂等操作，无需额外服务
- **可审计性**: 每个状态变更都有 git 历史
- **可移植性**: 无平台依赖

### 11.2 为什么 JSON 格式？

- **可读性**: 人工可读可改
- **扩展性**: 可添加字段（error, updated_at）而不破坏兼容性
- **兼容性**: 保留纯整数回退读取

### 11.3 为什么四阶段？

- **职责分离**: 需求、实现、验证、合并决策各自独立
- **可干预**: 每个阶段可人工介入，打回重做
- **可观测**: 阶段粒度的进度追踪

### 11.4 为什么 C++？

- 项目主要处理系统级任务（文件 I/O、进程管理）
- CMake + CTest 提供成熟的 C++ 测试生态
- 性能和跨平台支持良好

---

## 12. 未来增强方向

### 12.1 短期（1-2 周）

1. **Issue 锁机制**: 防止并发处理同一 Issue
2. **更详细的 TEST_REPORT.md**: 包含实际测试用例执行结果
3. **邮件/飞书通知增强**: 每个阶段完成时发送通知

### 12.2 中期（1-3 月）

1. **PR 评论机制**: Reviewer 阶段在 PR 下评论说明决策
2. **回退机制**: 失败时自动打回上一阶段重试
3. **多语言支持**: 扩展到 Python、Go 等语言

### 12.3 长期（3+ 月）

1. **并行处理**: 支持多个 Issue 同时处理
2. **AI 决策优化**: 基于历史数据优化合并决策
3. **可视化仪表盘**: Web 界面展示 pipeline 状态
