# SPEC.md — Issue #152 测试覆盖率提升与代码质量改进

> **项目**: neiliuxy/openclaw-auto-dev
> **版本**: 1.0（Pipeline Stage 1 Architect 输出）
> **日期**: 2026-04-15
> **状态**: Stage 1 (ArchitectDone)
> **关联 Issue**: #152

---

## 1. Issue 概述

| 字段 | 值 |
|------|-----|
| Issue 编号 | #152 |
| 标题 | feat: 测试覆盖率提升与代码质量改进 |
| 阶段 | Stage 1 (ArchitectDone) |
| 目标 | 提升代码质量，完善测试覆盖，补全未实现功能 |

---

## 2. Issue 清单与处理策略

本 Issue 包含 6 个子任务，按优先级分组。

### 2.1 高优先级任务

#### Task 1: 完善 `src/string_utils.cpp`

**当前状态**: `is_numeric` 函数声明存在但未实现；`replace` 函数缺少边界情况处理。

**需要实现**:

```cpp
// src/string_utils.cpp — 缺失函数
bool is_numeric(const std::string& s) {
    if (s.empty()) return false;
    size_t start = 0;
    if (s[0] == '+' || s[0] == '-') start = 1;
    if (start == s.size()) return false;  // 只有符号
    for (size_t i = start; i < s.size(); ++i) {
        if (!std::isdigit(s[i])) return false;
    }
    return true;
}
```

**边界情况**:
- `"123"` → `true`
- `"-456"` → `true`
- `"+789"` → `true`
- `"12.34"` → `false`（不支持小数）
- `"12a"` → `false`
- `""` → `false`
- `"+"` → `false`
- `"-"` → `false`

**replace 函数的边界情况补充**:
- `replace("aaa", "a", "aaa")` → 不能产生无限循环
- `replace("", "a", "b")` → `""`
- `replace("hello", "", "x")` → `"hello"`（空字符串不替换）

**验收**: `src/string_utils_test.cpp` 所有测试通过，包括上述边界用例。

---

#### Task 2: 完成 `src/ini_parser.cpp` 的 `save()` 实现

**当前状态**: `Parser::save()` 方法在 `.cpp` 文件中没有实现体。

**需要实现**:

```cpp
bool Parser::save(const std::string& filepath) const {
    std::ofstream fout(filepath);
    if (!fout) return false;
    for (const auto& sec : data_) {
        fout << "[" << sec.first << "]\n";
        for (const auto& kv : sec.second.values) {
            fout << kv.first << "=" << kv.second << "\n";
        }
        fout << "\n";
    }
    return true;
}
```

**验收**: `src/ini_parser_test.cpp` 中的 `save() and reload` 测试通过。

---

#### Task 3: 添加 `src/file_finder_test.cpp` 单元测试

**当前状态**: `src/file_finder.cpp` 是可执行文件，缺少对应的 `_test.cpp`。

**核心功能需要测试**:

1. `match_pattern` — glob 到正则的转换
   - `match_pattern("test.cpp", "*.cpp")` → `true`
   - `match_pattern("test.h", "*.cpp")` → `false`
   - `match_pattern("test_file.cpp", "test_*.cpp")` → `true`

2. 文件递归查找（隔离的临时目录）

**建议测试结构**:

```cpp
// file_finder_test.cpp
void test_pattern_matching() {
    assert(match_pattern("test.cpp", "*.cpp") == true);
    assert(match_pattern("test.h", "*.cpp") == false);
    assert(match_pattern("abc.cpp", "a*.cpp") == true);
    std::cout << "test_pattern_matching passed\n";
}

int main() {
    test_pattern_matching();
    // 可选: 集成测试用临时目录
    std::cout << "All file_finder tests passed\n";
}
```

---

#### Task 4: 清理 `.pipeline-state/` 目录

**当前状态**: 存在无效文件 `0_stage`、`plan.json` 等非 Issue 编号命名的文件。

**处理策略**:

```bash
# 保留格式: {number}_stage (纯整数格式) 或 {number}_stage.json
# 删除: 0_stage, plan.json, 以及任何非 {数字}_stage 格式的文件

cd .pipeline-state
# 列出所有文件
ls -la
# 识别有效文件: ls | grep -E '^[0-9]+_stage(|.json)$'
# 删除无效文件
```

**验收**: `.pipeline-state/` 目录只包含 `{数字}_stage` 或 `{数字}_stage.json` 格式的文件。

---

### 2.2 中优先级任务

#### Task 5: 增强 `pipeline-runner.sh` 错误处理

**问题**: 当阶段失败时，未写入 `error` 字段到状态文件。

**修改点**:

```bash
# 在各阶段 run_* 函数返回非零时，调用:
write_state_with_error() {
    local issue=$1
    local stage=$2
    local error_msg=$3
    # 写入: {"issue":N,"stage":N,"updated_at":"...","error":"具体错误信息"}
}
```

**验收**: Agent 失败后，`.pipeline-state/{issue}_stage` 包含非 null 的 `error` 字段。

---

#### Task 6: 完善 `heartbeat-check.sh` 日志

**问题**: 扫描 `openclaw-new` 标签时，缺少结构化日志输出。

**修改点**:

```bash
# 在 heartbeat-check.sh 中添加:
log_scan_result() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local found_count=$1
    echo "[$timestamp] openclaw-new scan: found=$found_count" >> "$LOG_DIR/scan-$(date '+%Y-%m-%d').log"
}
```

**验收**: `logs/scan-YYYY-MM-DD.log` 包含扫描时间戳和结果。

---

## 3. 目录结构（变更后）

```
openclaw-auto-dev/
├── .pipeline-state/           # 清理后: 只有 {数字}_stage 文件
├── src/
│   ├── string_utils.cpp      # [Task 1] 补全 is_numeric + replace 边界
│   ├── string_utils_test.cpp  # [Task 1] 补充边界用例
│   ├── ini_parser.cpp         # [Task 2] 实现 save()
│   ├── file_finder_test.cpp   # [Task 3] 新增单元测试
│   └── ...其他文件
├── scripts/
│   ├── pipeline-runner.sh     # [Task 5] 增强错误处理
│   └── heartbeat-check.sh     # [Task 6] 添加扫描日志
└── openclaw/152_test_coverage_quality/
    └── SPEC.md                # 本文档
```

---

## 4. 验收标准汇总

| Task | 验收条件 | 优先级 |
|------|---------|--------|
| Task 1 | `string_utils_test` 所有用例通过（现有 + 边界） | 高 |
| Task 2 | `ini_parser_test` 中 `save()` 相关测试通过 | 高 |
| Task 3 | `file_finder_test` 覆盖 pattern matching 核心逻辑 | 高 |
| Task 4 | `.pipeline-state/` 不含无效文件 | 高 |
| Task 5 | 阶段失败时状态文件含 `error` 字段 | 中 |
| Task 6 | `logs/scan-YYYY-MM-DD.log` 含结构化扫描记录 | 中 |

---

## 5. 测试命令

```bash
# 构建并运行所有测试
cmake -B build && cmake --build build --parallel
ctest --test-dir build --output-on-failure

# 单独运行受影响模块的测试
./build/string_utils_test
./build/ini_parser_test
./build/file_finder_test
```

---

## 6. 注意事项

- Task 4（清理 `.pipeline-state/`）需要使用 `git rm` 而非普通 `rm`，并在 commit message 中说明
- Task 3 新建的 `file_finder_test.cpp` 需要在 `src/CMakeLists.txt` 中注册
- 建议按 Task 顺序实现，依次 commit，以保持可追溯性

---

*本文档由 Architect Agent 生成（Stage 1），用于指导 Developer 实现工作。*
