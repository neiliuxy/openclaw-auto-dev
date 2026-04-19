# Architect Plan - Issue #152

## 问题分析

### 1. string_utils.cpp — 单元测试覆盖不足

**现状**:
- `string_utils.cpp` 所有函数均已实现：`trim`, `split`, `join`, `to_lower`, `to_upper`, `starts_with`, `ends_with`, `replace`, `is_numeric`
- `string_utils_test.cpp` 存在，包含 9 个测试函数，覆盖基本功能
- **问题**: 测试文件未在 `CMakeLists.txt` 中注册，`ctest` 不会运行这些测试
- **边界情况遗漏**: `replace` 未测试"替换源等于空字符串"、"连续重复替换"、"to_lower/to_upper 处理空字符串"等边界场景

### 2. ini_parser.cpp — save() 已实现，测试未注册

**现状**:
- `Parser::save()` 方法**已有实现**（写 `[section]` 头和 `key = value` 行）
- `ini_parser_test.cpp` 存在，测试 load/save/get/get_int/get_bool/sections/默认值
- **问题**: 测试文件未在 CMakeLists.txt 中注册
- `save()` 实现细节：空 section 时写 `[sectionname]\n\n`，无缩进，无注释保留，引号处理简单

### 3. file_finder.cpp — 无库封装，测试未注册

**现状**:
- `file_finder.cpp` 是**独立的 CLI 程序**（包含 `main()`），不是库文件
- 辅助函数 `match_pattern()` 和 `format_size()` 作用域为文件内部，不可在外部调用
- `file_finder_test.cpp` 存在，测试 `match_pattern` 和 `format_size` 的辅助函数（复制实现）
- **问题**: 无法对 `file_finder.cpp` 本身的功能做集成测试（CLI 参数解析、目录遍历）
- 测试未在 CMakeLists.txt 注册

### 4. .pipeline-state/ 目录 — 当前干净

**现状**:
- 检查时目录内只有 `stage.json`
- **需确认**: 若历史垃圾文件存在，需清理脚本

### 5. pipeline-runner.sh 错误处理

**现状**:
- `pipeline_state.cpp` 提供了 `write_stage_with_error()` 函数，支持写入 error 字段
- `pipeline-runner.sh` 在各阶段成功时调用 `write_state`，但**阶段失败时未写入 error 字段**，也未添加 `openclaw-error` 标签
- 需要在失败分支显式调用 `write_state_with_error` 并打标签

### 6. heartbeat-check.sh 日志

**现状**: 日志功能存在但记录不完整，仅打印到 stdout，未写入 `logs/scan-YYYY-MM-DD.log`

---

## 解决方案

### Solution 1: 注册 string_utils_test 到 CMakeLists.txt

在 `src/CMakeLists.txt` 添加：
```cmake
add_executable(string_utils_test ${CMAKE_CURRENT_LIST_DIR}/string_utils_test.cpp)
target_link_libraries(string_utils_test PRIVATE algorithms)
target_include_directories(string_utils_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
add_test(NAME string_utils_test COMMAND string_utils_test)
```

### Solution 2: 完善 string_utils.cpp 边界测试

新增测试用例覆盖：
- `replace("", "a", "b")` → 空字符串输入
- `replace("aaa", "a", "aa")` → 替换后变长（防止死循环）
- `replace("aba", "a", "c")` → 连续可替换字符
- `to_lower("")` → 空字符串
- `to_upper("")` → 空字符串
- `split("a,,b", ',')` → 空段处理

### Solution 3: 注册 ini_parser_test 到 CMakeLists.txt

在 `src/CMakeLists.txt` 添加：
```cmake
add_executable(ini_parser_test ${CMAKE_CURRENT_LIST_DIR}/ini_parser_test.cpp)
target_link_libraries(ini_parser_test PRIVATE algorithms)
target_include_directories(ini_parser_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
add_test(NAME ini_parser_test COMMAND ini_parser_test)
```

### Solution 4: file_finder 重构为可测试库 + 注册测试

**核心问题**: `file_finder.cpp` 是 CLI 程序，其核心逻辑（match_pattern、format_size）在 main 作用域内，无法被测试程序调用。

**方案**: 
1. 创建 `file_finder_lib.h` 和 `file_finder_lib.cpp`，提取 `match_pattern`、`format_size`、`find_files` 为库函数
2. `file_finder.cpp` 改为调用 `file_finder_lib`
3. `file_finder_test.cpp` 改为测试 `file_finder_lib`
4. 在 CMakeLists.txt 注册 `file_finder_test`

### Solution 5: 清理 .pipeline-state/ 垃圾文件

添加清理逻辑到 pipeline-runner.sh 或独立脚本：
```bash
# 删除无效状态文件（非数字命名的stage文件）
find .pipeline-state/ -maxdepth 1 -name "*_stage" ! -name "[0-9]*_stage" -delete
```

### Solution 6: pipeline-runner.sh 错误处理增强

在失败分支添加：
```bash
# 失败时写入 error 字段
write_state_with_error() {
    local issue=$1 stage=$2 error=$3
    # 调用 pipeline_state 的 write_stage_with_error
}
# 添加 openclaw-error 标签
gh issue edit $issue --add-label "openclaw-error"
```

### Solution 7: heartbeat-check.sh 日志完善

```bash
LOG_FILE="logs/scan-$(date +%Y-%m-%d).log"
echo "[$(date)] Scanning openclaw-new issues..." >> "$LOG_FILE"
# ... 扫描逻辑 ...
echo "[$(date)] Found $count new issues" >> "$LOG_FILE"
```

---

## 实施计划

### Phase 1: 测试注册（Priority: High，2个子任务，并行）

1. **T1.1**: 将 `string_utils_test` 注册到 `src/CMakeLists.txt`，运行 `ctest` 验证通过
2. **T1.2**: 将 `ini_parser_test` 注册到 `src/CMakeLists.txt`，运行 `ctest` 验证通过

### Phase 2: 边界测试补充（Priority: High，2个子任务，并行）

3. **T2.1**: 在 `string_utils_test.cpp` 新增边界测试用例（空字符串、连续替换、to_lower/upper 空串等）
4. **T2.2**: 在 `ini_parser_test.cpp` 新增边界测试（空 section 名、引号嵌套、特殊字符 key）

### Phase 3: file_finder 重构（Priority: High）

5. **T3.1**: 创建 `file_finder_lib.h` 和 `file_finder_lib.cpp`，提取 `match_pattern`、`format_size`、`find_files` 为库函数
6. **T3.2**: 重构 `file_finder.cpp` 调用 `file_finder_lib`，保持 CLI 功能不变
7. **T3.3**: 将 `file_finder_test.cpp` 改为测试 `file_finder_lib`，在 CMakeLists.txt 注册
8. **T3.4**: 运行 `ctest` 验证 file_finder 测试通过

### Phase 4: .pipeline-state/ 清理（Priority: Medium）

9. **T4.1**: 在 `pipeline-runner.sh` 开头添加清理逻辑（删除无效文件）
10. **T4.2**: 手动执行清理

### Phase 5: 错误处理增强（Priority: Medium）

11. **T5.1**: 在 `pipeline-runner.sh` 各阶段失败分支添加 `write_stage_with_error` 调用
12. **T5.2**: 在失败分支添加 `openclaw-error` 标签

### Phase 6: heartbeat 日志（Priority: Low）

13. **T6.1**: 在 `heartbeat-check.sh` 添加日志写入逻辑（`logs/scan-YYYY-MM-DD.log`）

---

## 风险评估

| 风险 | 影响 | 应对 |
|------|------|------|
| file_finder 重构破坏现有 CLI | 高 | 重构前后均运行测试，保持 main 函数接口不变 |
| .pipeline-state/ 清理误删有效文件 | 中 | 先列出待删除文件，人工确认后再删除；只删除明确的无害文件 |
| 测试注册后 ctest 并行冲突 | 低 | CTest 默认串行执行，若有冲突用 `ctest --sequential` |
| ini_parser save() 引号处理与 load() 不完全对称 | 低 | 现有测试已覆盖读写往返，保持当前行为不变 |

---

## 文件变更清单

```
src/CMakeLists.txt                    # 新增 3 个测试注册
src/string_utils_test.cpp             # 新增边界测试用例
src/ini_parser_test.cpp               # 新增边界测试用例
src/file_finder_lib.h                 # [新增] 库头文件
src/file_finder_lib.cpp               # [新增] 库实现
src/file_finder.cpp                   # 重构为调用 file_finder_lib
src/file_finder_test.cpp              # 改为测试 file_finder_lib
scripts/pipeline-runner.sh            # 错误处理 + .pipeline-state 清理
scripts/heartbeat-check.sh           # 日志完善
```
