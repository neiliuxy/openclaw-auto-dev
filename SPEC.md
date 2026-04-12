# SPEC: 栈的最小值 (MinStack) — Issue #73

## 1. 概述与目标

实现一个 **MinStack** 类，支持在 O(1) 时间复杂度内完成以下操作：

- `push(x)` — 将元素 x 压入栈
- `pop()` — 弹出栈顶元素
- `top()` — 获取栈顶元素
- `getMin()` — 获取栈中最小值

**核心约束：** 所有操作均需 O(1) 时间。

## 2. 实现方案

### 思路：双栈法（主栈 + 辅助最小值栈）

- `data_stack`：存储所有元素
- `min_stack`：存储当前栈中的最小值

**push(x)：**
- 将 x 压入 `data_stack`
- 如果 `min_stack` 为空，或 x <= `min_stack.top()`，则也将 x 压入 `min_stack`

**pop()：**
- 如果 `data_stack` 为空，直接返回
- 弹出 `data_stack` 栈顶元素 x
- 若 x == `min_stack.top()`，同步弹出 `min_stack`

**top()：** 返回 `data_stack.top()`，若为空栈则抛异常

**getMin()：** 返回 `min_stack.top()`，若为空栈则抛异常

### 关键细节

- 使用 `<=` 而非 `<`，确保重复的最小值也能正确弹出
- 空栈操作不崩溃，top/getMin 抛 `std::runtime_error`

## 3. 文件结构

```
src/
  min_stack.cpp          # 包含 MinStack 类完整实现（含 main 驱动测试）

tests/
  CMakeLists.txt         # 已包含 min_stack_test 目标，无需修改
  min_stack_test.cpp     # 独立测试文件，引用 min_stack.cpp 中的实现
```

**已有文件：**
- `src/min_stack.cpp` — 已存在，实现完整
- `src/min_stack_test.cpp` — 已存在，测试覆盖充分

## 4. 构建与测试

```bash
# 构建
cmake -B build && cmake --build build

# 运行单元测试
./min_stack_test

# 运行所有测试
ctest --test-dir build
```

## 5. 测试用例

| 用例 | 操作序列 | 期望结果 |
|------|----------|----------|
| 基础 | push(3), push(5), getMin | 3 |
| 弹出不改变最小值 | push(3), push(5), pop(), getMin | 3 |
| 重复最小值 | push(2), push(2), pop(), getMin | 2 |
| 递减序列 | push(5), push(3), push(7), push(3), getMin | 3 |
| 空栈 getMin | getMin() | 抛异常 |
| 空栈 top | top() | 抛异常 |
| 空栈 pop | pop() | 安全，不抛 |

## 6. 验收标准

- [x] MinStack 类实现于 `src/min_stack.cpp`
- [x] push、pop、top、getMin 均为 O(1)
- [x] 所有测试用例通过
- [x] 构建系统为 CMake，与现有项目一致
