# PRD - Issue #97: 方案B自动Pipeline验证

## 文档信息

| 字段 | 值 |
|------|-----|
| Issue编号 | #97 |
| 标题 | test: 方案B自动pipeline验证 |
| 作者 | neiliuxy |
| 创建日期 | 2026-03-22 |
| 类型 | 集成测试 / Pipeline验证 |
| 状态 | CLOSED (Pipeline Completed) |
| 最终Stage | 4 (PipelineDone) |
| 本文档Stage | 0 (ArchitectDone) |

---

## 1. 需求分析

### 1.1 Issue背景

Issue #97 是一个**集成测试Issue**，用于验证 cron + pipeline agent 自动处理流程（方案B）的端到端正确性。

### 1.2 核心目标

| 目标 | 描述 |
|------|------|
| E2E验证 | 验证从 Issue 创建 → Architect → Developer → Tester → Reviewer → Done 的全自动化流水线 |
| 状态管理 | 验证 `.pipeline-state/{issue}_stage` 状态文件读写正确性 |
| 阶段流转 | 验证各Agent阶段按正确顺序执行 |
| 边界条件 | 验证无效输入的处理 |

### 1.3 验收标准

- [x] Pipeline各阶段按序执行 (Architect→Developer→Tester→Reviewer→Done)
- [x] Stage状态文件正确读写
- [x] GitHub Labels正确更新
- [x] 全部5个测试用例通过
- [x] Issue正确关闭

---

## 2. Pipeline架构

### 2.1 Pipeline阶段定义

```
Stage 0: Architect   → 技术设计文档 (ARCHITECT-*.md, PRDs/issue-*.md)
Stage 1: Developer   → 代码实现 (src/, tests/)
Stage 2: Tester      → 测试报告 (TEST_REPORT.md)
Stage 3: Reviewer    → PR创建与合并
Stage 4: Done        → Issue关闭，Labels: openclaw-completed + stage/4-done
```

### 2.2 核心组件

| 组件 | 路径 | 职责 |
|------|------|------|
| pipeline_state.cpp/h | src/ | 状态读写管理 |
| pipeline-runner.sh | scripts/ | 主流水线编排 |
| heartbeat-check.sh | scripts/ | 心跳检查 |
| scan-issues.sh | scripts/ | Issue扫描 |
| cron-heartbeat.sh | scripts/ | Cron触发 |
| notify-feishu.sh | scripts/ | 飞书通知 |
| {issue}_stage | .pipeline-state/ | JSON状态文件 |

### 2.3 状态文件格式

```json
{
  "issue": 97,
  "stage": <0-4>,
  "updated_at": "<ISO8601 timestamp>",
  "error": null
}
```

---

## 3. 技术实现方案

### 3.1 Stage状态管理

#### 3.1.1 状态定义

```cpp
enum PipelineStage {
    NotStarted    = -1,  // 初始状态
    ArchitectDone = 0,   // Architect完成
    DeveloperDone = 1,   // Developer完成
    TesterDone    = 2,   // Tester完成
    ReviewerDone  = 3,   // Reviewer完成
    PipelineDone  = 4   // Pipeline完成
};
```

#### 3.1.2 读写接口

```cpp
// 读取指定Issue的当前stage
int read_stage(int issue_number, const std::string& state_dir);

// 写入指定Issue的stage
int write_stage(int issue_number, int stage, const std::string& state_dir);

// stage值转换为可读描述
std::string stage_to_description(int stage);
```

### 3.2 测试用例设计

| 测试用例 | 描述 | 预期结果 |
|---------|------|----------|
| `test_97_initial_stage` | 验证初始状态为有效stage (1-4) | ✅ Pass |
| `test_97_write_and_read` | 验证write_stage和read_stage一致性 | ✅ Pass |
| `test_97_stage_descriptions` | 验证stage_to_description准确性 | ✅ Pass |
| `test_97_valid_stage_range` | 验证有效stage值范围 (1-4) | ✅ Pass |
| `test_97_nonexistent_issue` | 验证不存在的Issue返回-1 | ✅ Pass |

### 3.3 流水线执行流程

```
┌──────────────────────────────────────────────────────────────┐
│                    cron-heartbeat.sh                          │
│                         │                                     │
│                         ▼                                     │
│              scan-issues.sh (扫描待处理Issue)                  │
│                         │                                     │
│                         ▼                                     │
│              pipeline-runner.sh <issue_num>                   │
│                         │                                     │
│        ┌────────────────┼────────────────┐                   │
│        │                │                │                   │
│        ▼                ▼                ▼                   │
│   Architect         Developer         Tester                 │
│   (Stage 0)         (Stage 1)         (Stage 2)              │
│        │                │                │                   │
│        └────────────────┼────────────────┘                   │
│                         │                                     │
│                         ▼                                     │
│                    Reviewer                                   │
│                   (Stage 3)                                   │
│                         │                                     │
│                         ▼                                     │
│                      Done                                      │
│                   (Stage 4)                                   │
└──────────────────────────────────────────────────────────────┘
```

---

## 4. 实施计划

### 4.1 阶段任务

| 阶段 | 负责人 | 任务 | 产出物 |
|------|--------|------|--------|
| Stage 0 | Architect | 技术设计 | ARCHITECT-97.md, PRDs/issue-97.md |
| Stage 1 | Developer | 代码实现 | pipeline_97_test, src/pipeline_state |
| Stage 2 | Tester | 测试验证 | TEST_REPORT_97.md |
| Stage 3 | Reviewer | PR审核 | PR #171 |
| Stage 4 | Done | 关闭Issue | Labels: stage/4-done, openclaw-completed |

### 4.2 关键时间点

| 事件 | 时间 |
|------|------|
| Issue创建 | 2026-03-22 |
| Architect完成 | 2026-04-11 |
| Developer完成 | 2026-04-11 |
| Tester完成 | 2026-04-05 |
| PR合并 | 2026-04-11 |
| Issue关闭 | 2026-04-11 |

---

## 5. 测试结果

### 5.1 测试用例执行结果

| 测试 | 描述 | 结果 |
|------|------|------|
| test_97_initial_stage | 验证初始状态 | ✅ 通过 |
| test_97_write_and_read | 验证读写一致性 | ✅ 通过 |
| test_97_stage_descriptions | 验证描述转换 | ✅ 通过 |
| test_97_valid_stage_range | 验证有效范围 | ✅ 通过 |
| test_97_nonexistent_issue | 验证边界条件 | ✅ 通过 |

**总计**: 5/5 通过

### 5.2 编译验证

```
编译命令: cd build && make pipeline_97_test
结果: [100%] Built target pipeline_97_test ✅
```

---

## 6. 验证结论

### 6.1 Pipeline自动化验证

✅ **方案B自动Pipeline验证成功**

- Stage 0 (Architect): ✅ 完成
- Stage 1 (Developer): ✅ 完成
- Stage 2 (Tester): ✅ 完成
- Stage 3 (Reviewer): ✅ 完成
- Stage 4 (Done): ✅ 完成

### 6.2 Labels验证

| Label | 应用时间 | 状态 |
|-------|---------|------|
| stage/architect | Architect完成后 | ✅ |
| stage/3-tested | Tester完成后 | ✅ |
| stage/4-done | Pipeline完成后 | ✅ |
| openclaw-completed | Issue关闭时 | ✅ |

---

## 7. 经验总结

### 7.1 成功因素

1. **状态文件管理**: JSON格式状态文件为pipeline追踪提供了可靠基础
2. **阶段顺序验证**: 各Agent阶段按定义顺序执行
3. **Label传播**: GitHub Labels正确反映pipeline进度
4. **测试覆盖**: 状态管理单元测试有效覆盖核心功能

### 7.2 改进建议

1. **测试同步**: 测试代码需与Pipeline演进同步更新
2. **灵活验证**: 使用`stage >= 1 && stage <= 4`而非硬编码期望值
3. **阶段分离**: Stage 1测试和Stage 2+测试分开执行

---

## 8. 参考文档

- [ARCHITECT-97.md](../ARCHITECT-97.md) - Architect阶段分析文档
- [TEST_REPORT_97.md](../TEST_REPORT_97.md) - Tester阶段测试报告
- [SPEC.md](../SPEC.md) - 项目规格说明
- [ARCHITECTURE.md](../ARCHITECTURE.md) - 系统架构文档

---

*本文档由 Architect Agent 生成，Issue #97 Pipeline验证专用*
