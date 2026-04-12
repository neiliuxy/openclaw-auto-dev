# SPEC.md — openclaw-auto-dev 架构规格说明书

> **项目**: neiliuxy/openclaw-auto-dev
> **版本**: 3.0（Pipeline Stage 0 Architect 输出）
> **日期**: 2026-04-10
> **状态**: 待 Developer 实现

---

## 1. 项目概述

### 1.1 项目定位

openclaw-auto-dev 是一个**状态驱动的多 Agent 全自动开发流水线**，实现从 GitHub Issue 创建到 PR 合并的端到端自动化。系统由四个专门的 Agent 角色（Architect、Developer、Tester、Reviewer）协作完成软件开发的完整生命周期。

### 1.2 核心目标

1. **全自动化**: Issue 创建 → PR 合并，全程无需人工干预
2. **状态可追踪**: 每个阶段的状态持久化到文件系统（`.pipeline-state/`）
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
         ▼  Stage 0→1
  ┌──────────────┐              ┌──────────────────────────┐
  │  Architect   │─────────────→│  openclaw/{N}_{slug}/   │
  │  (需求分析)   │              │  SPEC.md                │
  └──────────────┘              └──────────────────────────┘
         │
         ▼  Stage 1→2
  ┌──────────────┐              ┌──────────────────────────┐
  │  Developer   │─────────────→│  src/{slug}.cpp         │
  │  (代码实现)   │              │  (push 到远程分支)        │
  └──────────────┘              └──────────────────────────┘
         │
         ▼  Stage 2→3
  ┌──────────────┐              ┌──────────────────────────┐
  │   Tester     │─────────────→│  openclaw/{N}_{slug}/   │
  │  (测试验证)   │              │  TEST_REPORT.md          │
  └──────────────┘              └──────────────────────────┘
         │
         ▼  Stage 3→4
  ┌──────────────┐              ┌──────────────────────────┐
  │  Reviewer    │─────────────→│  PR 已合并                │
  │  (合并决策)   │              │  Issue 已关闭            │
  └──────────────┘              └──────────────────────────┘
```

---

## 2. 四阶段流水线详解

### 2.1 阶段定义

| Stage | Agent | 产出物 | 状态文件值 |
|-------|-------|--------|-----------|
| 0 | NotStarted | 初始状态文件创建 | 0 |
| 1 | ArchitectDone | `openclaw/{num}_{slug}/SPEC.md` | 1 |
| 2 | DeveloperDone | `src/{slug}.cpp` + 已 push | 2 |
| 3 | TesterDone | `openclaw/{num}_{slug}/TEST_REPORT.md` | 3 |
| 4 | PipelineDone | PR 已合并，状态文件清除 | 4 |

### 2.2 状态转换规则

```
0 (NotStarted)
    │ pipeline-runner.sh 创建 .pipeline-state/{issue}_stage，内容: {"issue":N,"stage":0,...}
    ▼
1 (ArchitectDone)
    │ Architect 分析 Issue，生成 SPEC.md，push 到远程分支
    │ 状态更新: stage=1，标签: openclaw-new → openclaw-architecting
    ▼
2 (DeveloperDone)
    │ Developer 读取 SPEC.md，实现所有功能点，push 代码
    │ 状态更新: stage=2，标签: openclaw-architecting → openclaw-developing
    ▼
3 (TesterDone)
    │ Tester 逐条验证 SPEC.md 中的功能点，生成 TEST_REPORT.md
    │ 状态更新: stage=3，标签: openclaw-developing → openclaw-testing
    ▼
4 (PipelineDone)
    │ Reviewer 创建 PR 并合并
    │ 清理 .pipeline-state/{issue}_stage，标签: openclaw-testing → openclaw-reviewing → openclaw-completed
    ▼
    Issue closed
```

**非法转换（会导致错误）**:
- 跳过阶段（如 0→2, 1→3）
- 回退（如 3→2）

### 2.3 触发方式

| 方式 | 命令 | 说明 |
|------|------|------|
| 手动触发 | `bash scripts/pipeline-runner.sh <issue_number>` | 从当前状态继续 |
| 断点续跑 | `bash scripts/pipeline-runner.sh <issue_number> --continue` | 强制从 0 开始 |
| 心跳自动 | `scripts/heartbeat-check.sh` | 扫描 `openclaw-new` 标签的 Issue |
| GitHub Actions | `.github/workflows/issue-check.yml` | 每 30 分钟触发 |

---

## 3. 核心模块

### 3.1 状态管理层 — `src/pipeline_state.h/cpp`

**职责**: 读写 `.pipeline-state/{issue}_stage` 文件，支持 JSON 和纯整数格式兼容

**文件格式**:
```json
{
  "issue": 104,
  "stage": 2,
  "updated_at": "2026-04-09T20:20:00+0800",
  "error": null
}
```

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
        std::string error;  // "null" 表示无错误
    };

    // 读取 stage 值（不存在返回 -1）
    int read_stage(int issue_number, const std::string& state_dir = ".pipeline-state");

    // 写入 stage（JSON 格式）
    bool write_stage(int issue_number, int stage, const std::string& state_dir = ".pipeline-state");

    // 写入 stage（带错误信息）
    bool write_stage_with_error(int issue_number, int stage, const std::string& error,
                                 const std::string& state_dir = ".pipeline-state");

    // 读取完整状态对象
    PipelineState read_state(int issue_number, const std::string& state_dir = ".pipeline-state");

    // stage 值转人类可读描述
    std::string stage_to_description(int stage);
}
```

**读写规则**:
- 读取: 优先 JSON 解析，失败则回退到纯整数（旧格式兼容）
- 写入: 统一 JSON 格式
- error 字段: `null` 表示无错误，非 null 时为错误消息字符串

### 3.2 顺序验证层 — `src/spawn_order.h/cpp`

**职责**: 验证 pipeline 阶段的执行顺序正确性

```cpp
namespace spawn_order {
    // 验证 current_stage → next_stage 是否合法
    bool validate_sequence(int current_stage, int next_stage);

    std::string get_stage_name(int stage);
}
```

**合法转换**:
```
0 → 1, 1 → 2, 2 → 3, 3 → 4, 4 → 4（幂等）
```

**非法转换（抛出错误或返回 false）**:
- 0 → 2, 0 → 3, 0 → 4（跳过 Architect）
- 1 → 3, 1 → 4（跳过 Developer）
- 2 → 4（跳过 Tester）
- 任何回退（如 3 → 2, 2 → 1）

### 3.3 通知管理层 — `src/pipeline_notifier.h/cpp`

**职责**: 四阶段通知消息格式化（用于飞书等通知渠道）

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
        const Notification& last_notification() const;
        void reset();
    };
}
```

### 3.4 日志工具 — `src/logger.h/cpp`

**职责**: 文件滚动日志，支持多级别（DEBUG/INFO/WARN/ERROR/FATAL）

```cpp
namespace logger {
    enum class Level { DEBUG=0, INFO=1, WARN=2, ERROR=3, FATAL=4 };

    class Logger {
    public:
        Logger(const std::string& filepath, Level min_level = Level::INFO);
        ~Logger();
        void debug(const char* fmt, ...);
        void info(const char* fmt, ...);
        void warn(const char* fmt, ...);
        void error(const char* fmt, ...);
        void fatal(const char* fmt, ...);
        void set_level(Level level);
        void flush();
    };
}
```

**特性**:
- 滚动大小: 10MB
- 控制台 + 文件双输出
- 线程安全（mutex）
- 时间戳格式: `YYYY-MM-DD HH:MM:SS`

### 3.5 字符串工具 — `src/string_utils.h/cpp`

提供标准字符串操作（待完善，具体见源码）。

### 3.6 INI 解析器 — `src/ini_parser.h/cpp`

提供 INI 文件读写能力（待完善，具体见源码）。

---

## 4. Shell 脚本

### 4.1 `scripts/pipeline-runner.sh` — 主流水线运行器

**职责**: 协调四阶段执行、状态文件管理、GitHub API 调用

**核心函数**:
```bash
run_pipeline <issue_num> [continue_mode]
```

**流程**:
1. 读取当前 stage（`get_stage`）
2. 根据 stage 调用对应 Agent
3. 每个 Agent 完成后更新状态文件（`write_state`）
4. 更新 GitHub Labels（`update_labels`）
5. Git add/commit/push

**续跑逻辑**:
- Stage 4 已完成: 跳过
- Stage 0: 从 Architect 开始
- Stage 1: 从 Developer 开始（跳过 Architect）
- Stage 2: 从 Tester 开始（跳过 Architect/Developer）
- Stage 3: 从 Reviewer 开始

### 4.2 `scripts/heartbeat-check.sh` — 心跳扫描

检测 `openclaw-new` 标签的 Issue，自动触发 pipeline。

### 4.3 `scripts/notify-feishu.sh` — 飞书通知

发送流水线阶段变更通知到飞书。

### 4.4 `scripts/update-status.sh` — 状态更新

更新 GitHub Issue 状态标签。

---

## 5. 目录结构

```
openclaw-auto-dev/
├── .github/workflows/
│   ├── cmake-tests.yml        # CMake + CTest CI
│   ├── issue-check.yml        # Issue 状态检查（cron）
│   └── pr-merge.yml           # PR 自动合并
├── .pipeline-state/            # 状态文件目录（核心）
│   └── {issue}_stage          # JSON 格式状态文件
├── .validation/               # Issue 验证配置
├── agents/                    # [已废弃] 静态 Agent 目录
├── build/                     # CMake 构建目录（不提交 Git）
├── docs/                      # 文档
├── logs/                      # 日志目录
│   └── scan-YYYY-MM-DD.log   # 扫描日志
├── openclaw/                  # Issue 工作目录
│   └── {num}_{slug}/
│       ├── SPEC.md            # 需求规格说明书（Architect 输出）
│       └── TEST_REPORT.md     # 测试验证报告（Tester 输出）
├── scripts/                   # Shell 脚本
│   ├── pipeline-runner.sh    # [核心] 流水线运行器
│   ├── heartbeat-check.sh     # 心跳扫描
│   ├── scan-issues.sh         # Issue 扫描
│   ├── notify-feishu.sh       # 飞书通知
│   ├── validate-changes.sh    # 变更验证
│   ├── check-conflicts.sh     # 冲突检查
│   ├── cron-check.sh          # Cron 定时检查
│   ├── cron-heartbeat.sh      # 心跳定时任务
│   └── update-status.sh       # 状态更新
├── src/                       # C++ 源代码
│   ├── pipeline_state.h/cpp   # [核心] 状态管理
│   ├── pipeline_notifier.h/cpp# [核心] 通知管理
│   ├── spawn_order.h/cpp      # [核心] 顺序验证
│   ├── logger.h/cpp           # [核心] 日志工具
│   ├── string_utils.h/cpp    # 字符串工具
│   ├── ini_parser.h/cpp      # INI 解析器
│   ├── date_utils.h/cpp       # 日期工具
│   ├── file_finder.cpp        # 文件查找
│   ├── quick_sort.h/cpp       # 快速排序
│   ├── matrix.h/cpp           # 矩阵运算
│   ├── min_stack.h/cpp        # 最小栈
│   ├── binary_tree.cpp        # 二叉树
│   ├── pipeline_*_test.cpp    # Pipeline 集成测试
│   ├── algorithm_test.cpp     # 算法单元测试
│   ├── CMakeLists.txt        # 构建配置
│   └── singleton.h/inl        # 单例模式
├── tests/                     # 额外测试
│   ├── CMakeLists.txt
│   └── hello_test.cpp
├── CMakeLists.txt             # 顶层 CMake 配置
├── project.yaml               # 项目配置
├── OPENCLAW.md               # OpenClaw 项目元数据
├── AGENTS.md                 # Agent 说明文档
├── HEARTBEAT.md              # 心跳机制说明
├── README.md                 # 项目主文档
├── SPEC.md                   # 本文档
├── ARCHITECTURE.md            # 架构设计文档（详细）
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
| `spawn_order_test` | spawn_order | 阶段顺序验证（0→1→2→3→4 合法，其他非法） |
| `pipeline_97_test` | pipeline_state | 状态文件读写基本功能 |
| `pipeline_83_test` | pipeline_notifier | 通知消息格式化 |
| `pipeline_99_test` | pipeline cron | 自动处理验证 |
| `pipeline_102_test` | 全流程 | 端到端 pipeline 完整性 |
| `pipeline_104_test` | Developer stage | Stage 2 状态转换验证 |
| `pipeline_state_test` | pipeline_state | 核心函数覆盖率补全（16 个测试用例） |
| `algorithm_test` | 算法库 | quick_sort, matrix, string_utils 单元测试 |
| `min_stack_test` | min_stack | 最小栈算法 |

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

```bash
# 读取状态
cat .pipeline-state/{issue}_stage
# 输出: {"issue":104,"stage":2,"updated_at":"2026-04-09T20:20:00+0800","error":null}

# 写入状态
echo '{"issue":104,"stage":2,"updated_at":"2026-04-09T20:20:00+0800","error":null}' \
  > .pipeline-state/104_stage
```

### 8.2 GitHub CLI API

```bash
# 列出 openclaw-new 标签的 Issue
gh issue list --label "openclaw-new" --state open --json number,title

# 查看 Issue 详情
gh issue view {issue_num} --repo {owner}/{repo} --json title,body

# 添加/移除标签
gh issue edit {issue_num} --add-label "openclaw-architecting" --remove-label "openclaw-new"

# 创建 PR
gh pr create --title "fix: ..." --body "Closes #{issue_num}" --base master --head {branch}

# 合并 PR
gh pr merge {pr_num} --squash --delete-branch
```

---

## 9. 已知问题与待办

| # | 问题 | 状态 | 优先级 |
|---|------|------|--------|
| 1 | `0_stage` 和 `plan.json` 垃圾文件存在于 `.pipeline-state/` | 待清理 | 中 |
| 2 | PR #11, #125, #132 长时间未合并 | 待 Reviewer | 中 |
| 3 | Issue #90 标记 `openclaw-completed` 但 #73 状态异常 | 待调查 | 低 |
| 4 | `src/string_utils.cpp` 功能待完善 | 待实现 | 中 |
| 5 | `src/ini_parser.cpp` 功能待完善 | 待实现 | 中 |
| 6 | `src/file_finder.cpp` 功能待完善 | 待实现 | 低 |

---

## 10. 设计决策

### 10.1 为什么用状态文件而非数据库？

- **简单性**: 文件系统天然支持幂等操作，无需额外服务
- **可审计性**: 每个状态变更都有 git 历史
- **可移植性**: 无平台依赖，跨机器共享

### 10.2 为什么 JSON 格式？

- **可读性**: 人工可读可改，调试方便
- **扩展性**: 可添加字段（error, updated_at）而不破坏兼容性
- **兼容性**: 保留纯整数回退读取，支持旧文件

### 10.3 为什么四阶段？

- **职责分离**: 需求、实现、验证、合并决策各自独立
- **可干预**: 每个阶段可人工介入，打回重做
- **可观测**: 阶段粒度的进度追踪

### 10.4 为什么 C++？

- 项目主要处理系统级任务（文件 I/O、进程管理）
- CMake + CTest 提供成熟的 C++ 测试生态
- 性能和跨平台支持良好
- 算法题目（如 min_stack, quick_sort）天然适合 C++

### 10.5 为什么 Shell + C++ 混合？

- **Shell**: 流程控制、Git 操作、系统调用（`pipeline-runner.sh`）
- **C++**: 核心逻辑、状态管理、算法实现（`src/`）
- 两者各取所长，避免在 Shell 中写复杂业务逻辑

---

## 11. Developer 下一阶段任务

> 以下是 Architect 建议的待实现功能，Developer 应按优先级实现。

### 高优先级

1. **完善 `src/string_utils.cpp`**: 实现所有声明的字符串处理函数，并添加单元测试
2. **完善 `src/ini_parser.cpp`**: 实现完整的 INI 解析器，支持读写操作
3. **清理 `.pipeline-state/` 目录**: 删除 `0_stage` 和 `plan.json` 等无效文件
4. **添加 `src/file_finder.cpp` 单元测试**: 验证文件查找功能

### 中优先级

5. **增强 `scripts/pipeline-runner.sh` 错误处理**: 当任意阶段失败时，写入 error 字段并添加 `openclaw-error` 标签
6. **完善 `scripts/heartbeat-check.sh`**: 添加日志输出，记录每次扫描结果
7. **添加飞书通知集成**: 在 `pipeline-runner.sh` 各阶段完成后调用 `notify-feishu.sh`

### 低优先级

8. **PR #11, #125, #132 处理**: Reviewer 手动合并或关闭这些长期未处理的 PR
9. **Issue #73 状态调查**: 检查并修复 Issue #73 的异常状态
10. **添加更多算法测试用例**: 扩展 `algorithm_test.cpp` 的覆盖率

---

## 12. 关键文件索引

| 文件 | 作用 | 关键函数/类 |
|------|------|------------|
| `src/pipeline_state.cpp` | 状态文件读写 | `read_stage`, `write_stage`, `read_state` |
| `src/spawn_order.cpp` | 阶段顺序验证 | `validate_sequence`, `get_stage_name` |
| `src/pipeline_notifier.cpp` | 通知格式化 | `PipelineNotifier::notify_*` |
| `src/logger.cpp` | 日志输出 | `Logger::info`, `Logger::error` |
| `scripts/pipeline-runner.sh` | 主流程控制 | `run_pipeline`, `run_architect`, `run_developer`, `run_tester`, `run_reviewer` |
| `scripts/heartbeat-check.sh` | 心跳扫描 | 检测 `openclaw-new` Issue |
| `scripts/notify-feishu.sh` | 飞书通知 | 发送阶段变更通知 |

---

*本文档由 Architect Agent 生成（Stage 0），用于指导 Developer 实现工作。*
*如需更新规格，请提交新的 Issue 并触发完整的 Pipeline 流程。*
