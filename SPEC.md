# openclaw-auto-dev 架构规格说明书

## 1. 项目概述

**项目**: neiliuxy/openclaw-auto-dev
**用途**: GitHub Issue → PR 全自动 AI 驱动开发流水线
**核心机制**: 状态驱动的四 Agent 协作（Architect → Developer → Tester → Reviewer）

## 2. 四阶段流水线

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

## 3. 状态文件规范

### 3.1 文件路径
- 路径格式: `.pipeline-state/<issue_number>_stage`
- 示例: `.pipeline-state/104_stage`

### 3.2 JSON 格式（标准）
```json
{
  "issue": 104,
  "stage": 2,
  "updated_at": "2026-03-31T20:20:00+08:00",
  "error": null
}
```

### 3.3 旧格式（兼容）
纯整数格式，如 `2`

## 4. 核心组件

### 4.1 状态管理库
- **文件**: `src/pipeline_state.cpp` / `src/pipeline_state.h`
- **功能**: 状态文件读写，支持 JSON 和纯整数格式

### 4.2 流水线运行器
- **文件**: `scripts/pipeline-runner.sh`
- **功能**: 协调四阶段执行，状态文件管理

### 4.3 状态值定义
| Stage | 值 | 描述 |
|-------|-----|------|
| NotStarted | 0 | 未开始 |
| ArchitectDone | 1 | Architect 完成 |
| DeveloperDone | 2 | Developer 完成 |
| TesterDone | 3 | Tester 完成 |
| PipelineDone | 4 | Pipeline 完成 |

## 5. 测试覆盖

| 测试文件 | 对应 Issue | 验证点 |
|----------|-----------|--------|
| pipeline_97_test.cpp | Issue #97 | 状态文件读写、阶段描述转换 |
| pipeline_99_test.cpp | Issue #99 | Developer 阶段状态读写 |
| pipeline_102_test.cpp | Issue #102 | 全流程完整性检查 |
| pipeline_104_test.cpp | Issue #104 | pipeline 全流程自动触发 |
| spawn_order_test.cpp | 通用 | 多进程生成顺序 |

## 6. 目录结构

```
openclaw-auto-dev/
├── .pipeline-state/        # 状态文件目录
│   └── <issue>_stage      # 状态文件
├── src/                   # 源代码
│   ├── pipeline_state.cpp # 状态读写实现
│   ├── pipeline_state.h   # 状态读写接口
│   └── *_test.cpp         # 测试文件
├── scripts/               # 脚本
│   └── pipeline-runner.sh # 流水线运行器
├── openclaw/              # Issue 工作目录
│   └── <num>_<slug>/     # 各 Issue 的工作区
│       ├── SPEC.md        # 需求规格
│       └── TEST_REPORT.md # 测试报告
└── build/                 # 构建目录
```

## 7. 已知问题修复 (2026-03-31)

### Issue 1: 状态文件格式不一致
- **问题**: shell 脚本与 C++ 代码格式不统一
- **修复**: `pipeline-runner.sh` 的 `write_stage()` 改为 JSON 格式输出

### Issue 2: 测试路径问题
- **问题**: 测试在 `build/` 运行但状态文件在项目根目录
- **修复**: CMakeLists.txt 设置 `WORKING_DIRECTORY` 为 `${CMAKE_SOURCE_DIR}`

### Issue 3: read_stage() JSON 解析回退
- **问题**: JSON 解析失败时回退逻辑不完善
- **修复**: 增强 `read_stage()` 的回退处理，添加流读取失败后的二次 JSON 解析
