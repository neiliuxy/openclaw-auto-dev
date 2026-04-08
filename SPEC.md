# SPEC.md — openclaw-auto-dev 架构规格说明书

> **项目**: neiliuxy/openclaw-auto-dev  
> **版本**: 1.0  
> **更新日期**: 2026-04-08  
> **状态**: ✅ 核心架构已完成，详见本文档

---

## 1. 项目概述

### 1.1 项目定位

openclaw-auto-dev 是一个**状态驱动的多 Agent 全自动开发流水线**，实现从 GitHub Issue 创建到 PR 合并的端到端自动化。

### 1.2 核心机制

```
Issue 创建 → 四角色 Agent 协作 → PR 合并 → 状态更新
        ↓
  Architect（需求分析）→ Developer（代码实现）
  → Tester（测试验证）→ Reviewer（合并决策）
```

### 1.3 技术栈

| 组件 | 技术选型 |
|------|----------|
| Pipeline | openclaw-pipeline skill |
| GitHub 集成 | GitHub CLI (`gh`) |
| 定时任务 | OpenClaw heartbeat |
| 状态管理 | 状态文件 (`.pipeline-state/`) |
| 语言 | C++17 |
| 构建系统 | CMake + CTest |
| 通知 | Feishu (飞书) |

---

## 2. 四阶段流水线

### 2.1 流水线阶段

| Stage | 值 | Agent | 产出物 |
|-------|-----|-------|--------|
| 0 | NotStarted | — | 初始状态 |
| 1 | ArchitectDone | Architect | `openclaw/{num}_{slug}/SPEC.md` |
| 2 | DeveloperDone | Developer | `src/{slug}.cpp` |
| 3 | TesterDone | Tester | `openclaw/{num}_{slug}/TEST_REPORT.md` |
| 4 | PipelineDone | Reviewer | PR 已合并 |

### 2.2 流水线状态图

```
Issue 创建 (label: openclaw-new)
    │
    ▼
[Stage 0] Architect ──→ SPEC.md 生成 + push
    │                     状态更新: stage=1
    │                     标签: openclaw-architecting
    ▼
[Stage 1] Developer ──→ 代码实现 + push
    │                     状态更新: stage=2
    │                     标签: openclaw-developing
    ▼
[Stage 2] Tester ──────→ TEST_REPORT.md + push
    │                     状态更新: stage=3
    │                     标签: openclaw-testing
    ▼
[Stage 3] Reviewer ────→ PR 创建 + 合并
    │                     状态更新: stage=4
    │                     标签: openclaw-reviewing
    ▼
Pipeline 清理 ──→ 状态文件删除
    │
    ▼
Issue closed (label: openclaw-completed)
```

### 2.3 触发方式

1. **手动触发**: `bash scripts/pipeline-runner.sh <issue_number>`
2. **断点续跑**: `bash scripts/pipeline-runner.sh <issue_number> --continue`
3. **心跳自动触发**: `scripts/heartbeat-check.sh` 扫描 `openclaw-new` 标签的 Issue

---

## 3. 状态文件规范

### 3.1 文件路径

```
.pipeline-state/<issue_number>_stage
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

### 3.3 兼容旧格式

纯整数格式（如 `2`）仍可读取，写入统一为 JSON 格式。

### 3.4 特殊状态文件

| 文件 | 含义 |
|------|------|
| `<issue>_stage` | 有效状态文件 |
| `0_stage` | **应删除** — 无效文件 |
| `plan.json` | **应删除** — 垃圾文件 |

---

## 4. 核心组件

### 4.1 状态管理层 (`src/pipeline_state.h/cpp`)

**职责**: 状态文件读写，支持 JSON 和纯整数格式兼容

**主要接口**:
```cpp
namespace pipeline {
    enum class PipelineStage { NotStarted=0, ArchitectDone=1, DeveloperDone=2, TesterDone=3, PipelineDone=4 };

    struct PipelineState { int issue; int stage; std::string updated_at; std::string error; };

    int  read_stage(int issue_number, const std::string& state_dir = ".pipeline-state");
    bool write_stage(int issue_number, int stage, const std::string& state_dir = ".pipeline-state");
    bool write_stage_with_error(int issue_number, int stage, const std::string& error, const std::string& state_dir);
    PipelineState read_state(int issue_number, const std::string& state_dir = ".pipeline-state");
    std::string stage_to_description(int stage);
}
```

### 4.2 通知管理层 (`src/pipeline_notifier.h/cpp`)

**职责**: 四阶段通知消息格式化（Feishu）

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

**职责**: 验证 pipeline 阶段的执行顺序正确性

**主要接口**:
```cpp
namespace spawn_order {
    bool validate_sequence(int current_stage, int next_stage);
    std::string get_stage_name(int stage);
}
```

### 4.4 流水线运行器 (`scripts/pipeline-runner.sh`)

**职责**: 协调四阶段执行，状态文件管理，GitHub API 调用

**入口函数**: `run_pipeline <issue_num> [continue_mode]`

### 4.5 心跳扫描 (`scripts/heartbeat-check.sh`)

**职责**: 检测 `openclaw-new` 标签的 Issue，自动触发 pipeline

---

## 5. 目录结构

```
openclaw-auto-dev/
├── .github/workflows/          # GitHub Actions
│   ├── cmake-tests.yml        # CMake + CTest CI
│   ├── issue-check.yml        # Issue 状态检查
│   └── pr-merge.yml           # PR 自动合并
├── .pipeline-state/           # 状态文件目录
│   └── <issue>_stage          # 状态文件
├── .validation/               # Issue 验证配置
│   └── issue-*.conf           # 各 Issue 的验证配置
├── agents/                    # [已废弃] 静态 Agent 任务目录
├── build/                     # CMake 构建目录
├── docs/                      # 文档
│   └── setup.md               # 安装配置说明
├── logs/                      # 日志目录
├── openclaw/                  # Issue 工作目录
│   └── <num>_<slug>/
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
│   ├── pipeline_*_test.cpp    # 各 Issue 对应的 Pipeline 测试
│   ├── quick_sort.h/cpp       # 快速排序
│   ├── matrix.h/cpp           # 矩阵运算
│   ├── min_stack.h/cpp        # 最小栈
│   ├── binary_tree.h/cpp      # 二叉树
│   ├── string_utils.h/cpp     # 字符串工具
│   ├── ini_parser.h/cpp       # INI 解析器
│   ├── logger.h/cpp          # 日志工具
│   ├── date_utils.h/cpp       # 日期工具
│   ├── file_finder.h/cpp      # 文件查找
│   └── singleton.h            # 单例模式
├── tests/                     # 额外测试
│   └── CMakeLists.txt
├── CMakeLists.txt            # 顶层 CMake 配置
├── project.yaml               # 项目配置
├── OPENCLAW.md              # OpenClaw 项目元数据
├── AGENTS.md                 # Agent 说明文档
├── HEARTBEAT.md              # 心跳机制说明
└── README.md                 # 项目主文档
```

---

## 6. 构建与测试

### 6.1 构建

```bash
mkdir -p build && cd build
cmake ..
make
```

### 6.2 测试

```bash
ctest --output-on-failure
```

### 6.3 CTest 注册的测试

| 测试名称 | 对应 Issue | 验证内容 |
|----------|-----------|----------|
| `spawn_order_test` | Issue #95 | spawn 阶段顺序验证 |
| `pipeline_97_test` | Issue #97 | 状态文件读写、阶段描述转换 |
| `pipeline_83_test` | Issue #83 | 4-session pipeline 通知验证 |
| `pipeline_99_test` | Issue #99 | Developer 阶段状态读写 |
| `pipeline_102_test` | Issue #102 | 全流程完整性检查 |
| `pipeline_104_test` | Issue #104 | pipeline 全流程自动触发 |
| `algorithm_test` | Issue #112 | 算法库单元测试 |

---

## 7. GitHub Labels

| 标签 | 含义 |
|------|------|
| `openclaw-new` | 新 Issue，等待处理 |
| `openclaw-architecting` | Stage 1 进行中 |
| `openclaw-developing` | Stage 2 进行中 |
| `openclaw-testing` | Stage 3 进行中 |
| `openclaw-reviewing` | Stage 4 进行中 |
| `openclaw-completed` | 已合并 |
| `openclaw-error` | 失败 |

---

## 8. 已知问题与修复历史

### Issue 1: 状态文件格式不一致 (2026-03-31)
- **问题**: shell 脚本与 C++ 代码格式不统一
- **修复**: `pipeline-runner.sh` 的 `write_state()` 统一为 JSON 格式

### Issue 2: 测试路径问题 (2026-03-31)
- **问题**: 测试在 `build/` 运行但状态文件在项目根目录
- **修复**: `CMakeLists.txt` 设置 `WORKING_DIRECTORY` 为 `${CMAKE_SOURCE_DIR}`

### Issue 3: read_stage() JSON 解析回退 (2026-03-31)
- **问题**: JSON 解析失败时回退逻辑不完善
- **修复**: 增强 `read_stage()` 的回退处理，添加流读取失败后的二次 JSON 解析

### Issue 4: pipeline_83_test 未注册 CTest
- **问题**: `add_executable` 存在但无 `add_test()`
- **修复**: 在 `src/CMakeLists.txt` 中添加 `add_test(NAME pipeline_83_test ...)`

---

## 9. 设计决策

### 9.1 为什么用状态文件而非数据库？

- **简单性**: 文件系统天然支持幂等操作，无需额外服务
- **可审计性**: 每个状态变更都有 git 历史
- **可移植性**: 无平台依赖

### 9.2 为什么 JSON 格式？

- **可读性**: 人工可读可改
- **扩展性**: 可添加字段（error, updated_at）而不破坏兼容性
- **兼容性**: 保留纯整数回退读取

### 9.3 为什么四阶段？

- **职责分离**: 需求、实现、验证、合并决策各自独立
- **可干预**: 每个阶段可人工介入，打回重做
- **可观测**: 阶段粒度的进度追踪
