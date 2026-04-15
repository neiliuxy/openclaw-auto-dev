# SPEC.md - Issue #73: 栈的最小值

## 1. 概述

- **Issue**: #73 feat: 栈的最小值
- **实现文件**: `src/min_stack.cpp`
- **测试文件**: `src/min_stack_test.cpp`
- **功能**: 实现一个支持 O(1) 获取最小值的栈

## 2. 技术规格

### 2.1 设计思路

使用两个栈实现：
- `data_stack`: 存储所有元素
- `min_stack`: 存储当前最小值

**push 策略**：当 `x <= min_stack.top()`（或 min_stack 为空）时，将 x 同时推入 min_stack
**pop 策略**：当 data_stack 弹出的元素等于 min_stack.top() 时，同时弹出 min_stack
**getMin 策略**：返回 min_stack.top()，时间复杂度 O(1)

### 2.2 核心函数

| 函数名 | 描述 | 参数 | 返回值 | 复杂度 |
|--------|------|------|--------|--------|
| `MinStack()` | 构造函数，初始化空栈 | 无 | 无 | O(1) |
| `push(int x)` | 将元素 x 入栈 | x: int | 无 | O(1) |
| `pop()` | 弹出栈顶元素 | 无 | 无 | O(1) |
| `top()` | 获取栈顶元素 | 无 | int | O(1) |
| `getMin()` | 获取最小值 | 无 | int | O(1) |

### 2.3 边界条件

| 场景 | 期望行为 |
|------|----------|
| 空栈调用 `top()` | 抛出 `std::runtime_error("Stack is empty")` |
| 空栈调用 `getMin()` | 抛出 `std::runtime_error("Stack is empty")` |
| 空栈调用 `pop()` | 直接返回，不抛异常 |
| 重复最小值 | `<=` 入栈条件，确保相同最小值也入 min_stack |

### 2.4 算法复杂度

| 操作 | 时间复杂度 | 空间复杂度 |
|------|------------|------------|
| push | O(1) | O(1) |
| pop | O(1) | O(1) |
| top | O(1) | O(1) |
| getMin | O(1) | O(n) 最坏情况 |

## 3. 测试用例

| 用例 | 操作序列 | 预期 getMin | 说明 |
|------|----------|-------------|------|
| 基础用例 | push(3), push(5), getMin | 3 | 最小值在栈底 |
| 最小值弹出 | push(3), push(5), pop(), getMin | 3 | 弹出不影响最小值 |
| 重复最小值 | push(2), push(2), pop(), getMin | 2 | 精确出栈 |
| 递减序列 | push(5), push(3), push(7), push(3), getMin | 3 | 递减回升 |
| 混合零负 | push(1), push(2), push(1), pop(), getMin | 1 | 弹出一个1后最小值仍为1 |
| 空栈 top | 空栈 top() | 抛异常 | 错误处理 |
| 空栈 getMin | 空栈 getMin() | 抛异常 | 错误处理 |
| 空栈 pop | 空栈 pop() | 无异常 | 安全处理 |

## 4. 验收标准

- [ ] MinStack 类正确定义
- [ ] push/pop/top/getMin 均为 O(1)
- [ ] 正确处理重复最小值（`<=` 入栈条件）
- [ ] 空栈 top()/getMin() 抛出 std::runtime_error
- [ ] 空栈 pop() 安全返回
- [ ] main 函数包含测试用例验证
- [ ] 编译通过 (g++ -std=c++11)

## 5. 依赖

- C++11 标准库
- `<stack>`, `<iostream>`, `<stdexcept>`

## 6. 文件清单

| 文件 | 说明 |
|------|------|
| `src/min_stack.cpp` | 主实现（含 main 测试） |
| `src/min_stack_test.cpp` | 独立测试文件 |
| `openclaw/73_min_stack/SPEC.md` | 本规格文档 |
| `openclaw/73_min_stack/TEST_REPORT.md` | 测试报告 |

---

*本文档由 Architect Agent 生成（Stage 1）*
