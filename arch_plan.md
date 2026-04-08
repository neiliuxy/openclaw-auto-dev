# arch_plan.md — openclaw-auto-dev 架构实现计划

> **项目**: neiliuxy/openclaw-auto-dev  
> **版本**: 1.0  
> **日期**: 2026-04-08  
> **作者**: Architect Agent  
> **用途**: 详细实施计划，指导 Developer Agent 执行

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
| 算法库 | ✅ 稳定 | `src/quick_sort.cpp`, `src/matrix.cpp`, etc. |
| CTest 测试套件 | ✅ 基本完整 | 7 个测试已注册 |
| SPEC.md | ✅ 完成 | 本文档前身 |

### 1.2 待完善项目

| 项目 | 优先级 | 描述 |
|------|--------|------|
| `pipeline_83_test` CTest 注册 | **P1** | 已在 CMakeLists.txt 中注册（PLAN.md 已提及） |
| 清理 `0_stage` 垃圾文件 | **P1** | `.pipeline-state/0_stage` 为无效文件 |
| 清理 `plan.json` 垃圾文件 | **P2** | `.pipeline-state/plan.json` 为无效文件 |
| `ARCHITECTURE.md` 未提交 | **P2** | 文件已创建但未 git commit |
| `Testing/` 目录未跟踪 | **P3** | 需检查内容并决定去留 |
| `cron-report.md` 更改未提交 | **P2** | 当前有 local modifications |
| `scan-result.json` 更改未提交 | **P2** | 当前有 local modifications |

---

## 2. 架构实现计划

### 2.1 第一阶段：环境清理（环境准备）

**目标**: 清理垃圾文件，确保 `.pipeline-state/` 目录干净

#### Step 1.1: 清理无效状态文件

```bash
# 删除无效的 0_stage 文件
rm -f .pipeline-state/0_stage

# 删除无效的 plan.json 文件
rm -f .pipeline-state/plan.json
```

**涉及文件**:
- 删除: `.pipeline-state/0_stage`
- 删除: `.pipeline-state/plan.json`

#### Step 1.2: 检查并处理 Testing/ 目录

```bash
ls -la Testing/
```

**决策**: 如果 `Testing/` 只包含临时构建产物，则删除；如果包含有效测试数据，则考虑提交。

#### Step 1.3: 提交清理结果

```bash
git add -A
git commit -m "chore: clean up spurious pipeline state files"
```

---

### 2.2 第二阶段：文档完善

**目标**: 确保 SPEC.md 和架构文档已正确提交

#### Step 2.1: 确保 SPEC.md 已提交

SPEC.md 已在本次 Architect 阶段更新。确保提交：

```bash
git add SPEC.md
git commit -m "docs: update SPEC.md with complete architecture specification"
```

#### Step 2.2: 检查 ARCHITECTURE.md

如果 `ARCHITECTURE.md` 存在且未提交：

```bash
git add ARCHITECTURE.md
git commit -m "docs: commit ARCHITECTURE.md from previous architect run"
```

---

### 2.3 第三阶段：构建与测试验证

**目标**: 确保所有测试通过

#### Step 3.1: 完整构建

```bash
cd build
cmake ..
make -j$(nproc)
```

#### Step 3.2: 运行所有测试

```bash
ctest --output-on-failure
```

**预期输出**: 7 个测试全部通过

| 测试名称 | 预期结果 |
|----------|----------|
| `spawn_order_test` | ✅ PASS |
| `pipeline_97_test` | ✅ PASS |
| `pipeline_83_test` | ✅ PASS |
| `pipeline_99_test` | ✅ PASS |
| `pipeline_102_test` | ✅ PASS |
| `pipeline_104_test` | ✅ PASS |
| `algorithm_test` | ✅ PASS |

#### Step 3.3: 处理测试失败

如果任何测试失败：
1. 分析失败原因
2. 修复对应源代码
3. 重新构建并测试
4. 记录修复到 TEST_REPORT.md

---

### 2.4 第四阶段：Git 提交与推送

**目标**: 将所有更改推送到 origin

#### Step 4.1: 检查当前 git 状态

```bash
git status --short
```

#### Step 4.2: 添加所有更改

```bash
git add -A
```

#### Step 4.3: 提交

```bash
git commit -m "feat(arch): initial architecture and spec"
```

#### Step 4.4: 推送

```bash
git push origin "$(git rev-parse --abbrev-ref HEAD)"
```

---

## 3. 文件清单

### 3.1 需要修改的文件

| 文件 | 修改内容 | 原因 |
|------|----------|------|
| `SPEC.md` | 内容更新 | 完善架构规格说明 |
| `.pipeline-state/0_stage` | 删除 | 无效状态文件 |
| `.pipeline-state/plan.json` | 删除 | 垃圾文件 |

### 3.2 需要新建的文件

| 文件 | 内容 | 原因 |
|------|------|------|
| `arch_plan.md` | 本文档 | 详细实施计划 |

### 3.3 需要提交的文件（已存在）

| 文件 | Git 操作 | 原因 |
|------|----------|------|
| `SPEC.md` | add + commit | 文档更新 |
| `ARCHITECTURE.md` | add + commit（如存在） | 未提交文档 |

### 3.4 需要删除的文件

| 文件 | 删除方式 |
|------|----------|
| `.pipeline-state/0_stage` | `git rm` |
| `.pipeline-state/plan.json` | `git rm` |
| `Testing/` | 检查后决定 `git rm` 或保留 |

---

## 4. 依赖关系

### 4.1 系统依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| CMake | ≥ 3.10 | 构建系统 |
| C++ 编译器 | C++17 | 代码编译 |
| Git | 任意 | 版本控制 |
| `gh` CLI | 最新 | GitHub API 调用（可选） |

### 4.2 内部依赖

```
CMakeLists.txt (顶层)
    │
    ├── src/CMakeLists.txt
    │     ├── pipeline_state.cpp ← pipeline_state.h
    │     ├── pipeline_notifier.cpp ← pipeline_notifier.h
    │     ├── spawn_order.cpp ← spawn_order.h
    │     ├── quick_sort.cpp ← quick_sort.h
    │     ├── matrix.cpp ← matrix.h
    │     └── ... 其他算法文件
    │
    └── tests/CMakeLists.txt
```

### 4.3 脚本依赖

```
pipeline-runner.sh
    ├── git
    ├── gh (可选)
    └── mkdir/cat/rm 等标准命令
```

---

## 5. 风险与注意事项

### 5.1 状态文件冲突

**风险**: 两个 pipeline 同时处理同一 Issue 导致状态文件冲突  
**缓解**: Issue 级别的锁机制（未来增强）  
**当前状态**: 单 Issue 处理，无并发风险

### 5.2 gh CLI 不可用

**风险**: `gh` 命令不存在时，GitHub 相关操作跳过  
**缓解**: `pipeline-runner.sh` 中 `has_gh()` 检查，不可用时优雅降级

### 5.3 测试失败处理

**风险**: CTest 测试失败但 pipeline 已推进  
**缓解**: Tester 阶段发现失败立即停止，不推进状态

---

## 6. 验证清单

实施完成后，确认以下条件：

- [ ] `.pipeline-state/` 只包含有效的 `<number>_stage` 文件
- [ ] 无 `0_stage`、`plan.json` 等垃圾文件
- [ ] `SPEC.md` 已更新并提交
- [ ] `arch_plan.md` 已创建并提交
- [ ] `ARCHITECTURE.md` 已提交（如果存在）
- [ ] `Testing/` 目录已处理（删除或提交）
- [ ] 所有 7 个 CTest 测试通过
- [ ] `make` 构建成功无警告
- [ ] `git push` 成功推送到 origin
- [ ] 当前分支包含 commit: `feat(arch): initial architecture and spec`

---

## 7. 后续增强建议

### 7.1 短期（1-2 周）

1. **Issue 锁机制**: 防止并发处理同一 Issue
2. **更详细的 TEST_REPORT.md**: 包含实际测试用例执行结果
3. **邮件/飞书通知增强**: 每个阶段完成时发送通知

### 7.2 中期（1-3 月）

1. **PR 评论机制**: Reviewer 阶段在 PR 下评论说明决策
2. **回退机制**: 失败时自动打回上一阶段重试
3. **多语言支持**: 扩展到 Python、Go 等语言

### 7.3 长期（3+ 月）

1. **并行处理**: 支持多个 Issue 同时处理
2. **AI 决策优化**: 基于历史数据优化合并决策
3. **可视化仪表盘**: Web 界面展示 pipeline 状态

---

## 8. 实施总结

| 阶段 | 步骤 | 负责 Agent |
|------|------|------------|
| Architect | 分析 + 设计 + 写 SPEC.md + arch_plan.md | **Architect** |
| 环境清理 | 删除垃圾文件 | Developer |
| 构建验证 | cmake + make + ctest | Developer |
| 测试验证 | 运行全部测试，生成报告 | Tester |
| 最终审查 | 代码审查 + PR 创建 | Reviewer |
| 合并 | PR 合并到 master | Reviewer |
