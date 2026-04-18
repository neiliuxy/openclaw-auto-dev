# arch_plan.md — openclaw-auto-dev 架构实施计划

> **项目**: neiliuxy/openclaw-auto-dev
> **版本**: 2.0
> **日期**: 2026-04-18
> **作者**: Architect Agent (Stage 0)
> **用途**: 指导 Developer Agent 执行的详细实施计划

---

## 1. 当前架构评估

### 1.1 已完成的核心组件

| 组件 | 状态 | 文件 |
|------|------|------|
| 状态管理层 | ✅ 稳定 | `src/pipeline_state.h/cpp` |
| 通知管理层 | ✅ 稳定 | `src/pipeline_notifier.h/cpp` |
| 顺序验证层 | ✅ 稳定 | `src/spawn_order.h/cpp` |
| 流水线运行器 | ✅ 稳定 | `scripts/pipeline-runner.sh` |
| 心跳扫描脚本 | ✅ 稳定 | `scripts/heartbeat-check.sh` |
| GitHub Actions CI | ✅ 稳定 | `.github/workflows/*.yml` |
| CTest 测试套件 | ✅ 基本完整 | 12 个测试已注册 |
| SPEC.md | ✅ 完成 | 完整系统规格说明 |
| ARCHITECTURE.md | ✅ 完成 | 架构设计文档 |

### 1.2 待处理问题

| 项目 | 优先级 | 描述 |
|------|--------|------|
| `.pipeline-state/0_stage` 垃圾文件 | **P1** | 包含值 `0`，无效状态文件，需删除 |
| `cron-report.md` 未提交 | **P2** | 本地修改未提交 |
| `scan-result.json` 未提交 | **P2** | 本地修改未提交 |
| `.pipeline-state/97_stage` 已删除 | **P2** | Git 记录中已删除，需确认 |
| `.pipeline-state/stage.json` 已删除 | **P2** | Git 记录中已删除，需确认 |
| Issue #90 待处理 | **P1** | SPEC.md 已就绪，待 Developer 实现 |
| Issue #152 | ✅ 已完成 | Pipeline Done |

---

## 2. Issue 扫描结果

### 2.1 Issue #90 — C++ 单例模式模板类

- **阶段**: Stage 0 (Architect Done，SPEC.md 已生成)
- **状态**: 等待 Developer 实现
- **产出物**: `issues/90/SPEC.md`
- **实现要点**:
  - 双检锁线程安全单例模板类
  - `GetInstance()` / `DestroyInstance()`
  - 禁止拷贝构造和赋值运算符
  - 7 个测试用例覆盖

### 2.2 Issue #152 — Pipeline 质量改进

- **阶段**: Stage 4 (Pipeline Done)
- **状态**: ✅ 已完成
- **产出物**: `issues/152/PLAN.md`, `issues/152_architect_plan.md`
- **完成内容**: string_utils/ini_parser/file_finder 测试注册及重构

---

## 3. 实施计划

### 3.1 第一阶段：环境清理（P1）

**目标**: 清理垃圾文件，确保 `.pipeline-state/` 目录干净

#### Step 1.1: 删除无效状态文件

```bash
rm -f .pipeline-state/0_stage
```

**涉及文件**:
- 删除: `.pipeline-state/0_stage`（包含值 `0`，无效文件名）

#### Step 1.2: 提交清理结果

```bash
git add -A
git commit -m "chore: clean up spurious pipeline state files"
```

---

### 3.2 第二阶段：Issue #90 开发（P1）

**目标**: 实现 C++ 单例模式模板类

#### Step 2.1: 审查现有实现

- `src/singleton.h` — 模板类声明
- `src/singleton.inl` — 双检锁实现
- `src/singleton_test.cpp` — 测试文件

#### Step 2.2: 编译验证

```bash
g++ -std=c++17 -pthread src/singleton_test.cpp -o singleton_test && ./singleton_test
```

#### Step 2.3: 注册到 CMakeLists.txt（如果未注册）

检查 `src/CMakeLists.txt` 是否包含 `singleton_test`，如未注册则添加。

#### Step 2.4: CTest 验证

```bash
cd build && cmake .. && make -j$(nproc) && ctest --output-on-failure
```

---

### 3.3 第三阶段：文档整理（P2）

#### Step 3.1: 提交本地修改

```bash
git add cron-report.md scan-result.json
git commit -m "chore: update scan results and cron report"
```

#### Step 3.2: 推送所有更改

```bash
git push origin "$(git rev-parse --abbrev-ref HEAD)"
```

---

## 4. 文件变更清单

### 4.1 需要删除的文件

| 文件 | 原因 |
|------|------|
| `.pipeline-state/0_stage` | 无效文件名（0 不是有效 issue number） |

### 4.2 需要提交的文件

| 文件 | Git 操作 |
|------|----------|
| `cron-report.md` | add + commit |
| `scan-result.json` | add + commit |
| `.pipeline-state/97_stage` (deleted) | 已从文件系统删除，待 git commit |
| `.pipeline-state/stage.json` (deleted) | 已从文件系统删除，待 git commit |

---

## 5. 验证清单

完成实施后，确认以下条件：

- [ ] `.pipeline-state/` 只包含有效的 `<number>_stage` 文件
- [ ] 无 `0_stage`、`plan.json` 等垃圾文件
- [ ] `arch_plan.md` 已更新并提交
- [ ] Issue #90 进入 Developer 阶段
- [ ] 所有 12 个 CTest 测试通过
- [ ] `make` 构建成功无警告
- [ ] `git push` 成功推送到 origin

---

## 6. 风险与注意事项

### 6.1 状态文件冲突

**风险**: 两个 pipeline 同时处理同一 Issue  
**缓解**: 单 Issue 处理，无并发风险

### 6.2 测试注册遗漏

**风险**: 新增测试未注册到 CMakeLists.txt  
**缓解**: 检查所有 `*_test.cpp` 文件是否有对应 `add_test()`

---

## 7. 后续增强建议

### 7.1 短期

1. **Issue #90 完成后**: Reviewer 合并 PR，关闭 Issue
2. **清理更多垃圾文件**: `src/build_new/` 等遗留构建目录

### 7.2 中期

1. **PR 评论机制**: Reviewer 阶段在 PR 下评论说明决策
2. **回退机制**: 失败时自动打回上一阶段重试
3. **飞书通知增强**: 失败时也发送通知

---

*本文档由 Architect Agent 生成（Stage 0），用于指导 Developer 实现工作。*
