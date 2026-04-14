# SPEC-issue-73.md — Min Stack 需求规格说明书

> **Issue**: #73 — feat: 栈的最小值
> **Architect**: Pipeline Architect Agent
> **日期**: 2026-04-15
> **状态**: Stage 1 (ArchitectDone)

---

## 1. Issue 概述

| 字段 | 值 |
|------|-----|
| Issue 编号 | #73 |
| 标题 | feat: 栈的最小值 |
| 描述 | 实现 `src/min_stack.cpp`，包含支持 O(1) 获取最小值的栈 |
| 目标文件 | `src/min_stack.cpp` |
| 测试文件 | `src/min_stack_test.cpp` |

---

## 2. 功能需求

### 2.1 核心功能

实现一个 **MinStack** 类，支持以下操作，且每个操作的时间复杂度均为 **O(1)**：

| 操作 | 描述 | 参数 | 返回值 | 复杂度 |
|------|------|------|--------|--------|
| `MinStack()` | 构造函数，初始化空栈 | 无 | 无 | O(1) |
| `push(int x)` | 将元素 x 入栈 | x: int | 无 | O(1) |
| `pop()` | 弹出栈顶元素 | 无 | 无 | O(1) |
| `top()` | 获取栈顶元素（不移除） | 无 | int | O(1) |
| `getMin()` | 获取栈中的最小元素 | 无 | int | O(1) |

### 2.2 设计思路

使用**双栈**实现：
- `data_stack`: 存储所有元素
- `min_stack`: 存储当前历史最小值

**push 策略**：当 `x <= min_stack.top()`（或 min_stack 为空）时，将 x 同时推入 min_stack
**pop 策略**：当 data_stack 弹出的元素等于 min_stack.top() 时，同时弹出 min_stack
**getMin 策略**：返回 min_stack.top()

### 2.3 边界条件处理

| 场景 | 期望行为 |
|------|----------|
| 空栈调用 `top()` | 抛出 `std::runtime_error("Stack is empty")` |
| 空栈调用 `getMin()` | 抛出 `std::runtime_error("Stack is empty")` |
| 空栈调用 `pop()` | 直接返回，不抛异常 |
| 重复最小值入栈 | 每次 `<=` 都入 min_stack，pop 时精确匹配才出 |
| 连续相同值入栈 | `<=` 确保第二个相同值也入 min_stack |

---

## 3. 算法规格

### 3.1 时间复杂度

| 操作 | 时间复杂度 |
|------|-----------|
| push | O(1) |
| pop | O(1) |
| top | O(1) |
| getMin | O(1) |

### 3.2 空间复杂度

最坏情况 O(n)：当元素严格递减时，min_stack 与 data_stack 等大。

### 3.3 伪代码

```
class MinStack:
    data_stack: stack[int]
    min_stack: stack[int]

    function push(x):
        data_stack.push(x)
        if min_stack.empty() or x <= min_stack.top():
            min_stack.push(x)

    function pop():
        if data_stack.empty(): return
        x = data_stack.top()
        data_stack.pop()
        if not min_stack.empty() and x == min_stack.top():
            min_stack.pop()

    function top():
        if data_stack.empty():
            throw runtime_error("Stack is empty")
        return data_stack.top()

    function getMin():
        if min_stack.empty():
            throw runtime_error("Stack is empty")
        return min_stack.top()
```

---

## 4. 测试用例

### 4.1 单元测试用例

| # | 操作序列 | 预期 getMin | 预期 top | 说明 |
|---|---------|-------------|----------|------|
| T1 | push(3), push(5) | 3 | 5 | 基础：最小值在栈底 |
| T2 | push(3), push(5), pop() | 3 | 3 | 弹出不影响最小值 |
| T3 | push(2), push(2), pop() | 2 | 2 | 重复最小值精确出栈 |
| T4 | push(5), push(3), push(7), push(3) | 3 | 3 | 递减回升场景 |
| T5 | push(1), push(2), push(1), pop(), getMin | 1 | 2 | 弹出一个 1 后最小值仍为 1 |
| T6 | 空栈 top | 抛异常 | — | 错误处理 |
| T7 | 空栈 getMin | 抛异常 | — | 错误处理 |
| T8 | 空栈 pop | 无异常 | — | 空栈安全处理 |
| T9 | push(-1), push(-3), pop(), getMin | -1 | -1 | 负数场景 |
| T10 | push(0), push(-1), push(0), pop(), getMin | -1 | -1 | 混合零和负 |

### 4.2 验证方式

```bash
# 编译并运行
g++ -std=c++11 -o min_stack_test src/min_stack.cpp
./min_stack_test

# CMake 测试
cd build && make min_stack_test && ./min_stack_test
```

---

## 5. 文件清单

| 文件路径 | 状态 | 说明 |
|---------|------|------|
| `src/min_stack.cpp` | 存在（需确认实现完整） | 主实现文件 |
| `src/min_stack.h` | 不存在 | 如需头文件分离则创建 |
| `src/min_stack_test.cpp` | 存在 | 单元测试 |
| `openclaw/73_min_stack/SPEC.md` | 存在 | Architect 规格文档 |
| `openclaw/73_min_stack/TEST_REPORT.md` | 存在 | Tester 测试报告 |

---

## 6. 验收标准

- [ ] `MinStack` 类正确定义，四个方法签名符合规格
- [ ] `push`、`pop`、`top`、`getMin` 均为 O(1)
- [ ] 重复最小值处理正确（`<=` 入栈条件）
- [ ] 空栈调用 `top()`/`getMin()` 抛出 `std::runtime_error`
- [ ] 空栈调用 `pop()` 安全返回
- [ ] `src/min_stack.cpp` 编译通过（g++ -std=c++11）
- [ ] `src/min_stack_test.cpp` 测试全部通过
- [ ] CMake 构建系统包含 min_stack 相关目标

---

## 7. 参考资料

- LeetCode 155 — Min Stack
- 项目现有实现：`src/min_stack.cpp`（基于双栈方案）

---

*本文档由 Architect Agent 生成（Stage 1），指导 Developer 实现工作。*
