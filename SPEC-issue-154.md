# SPEC-issue-154.md — 测试覆盖率提升与代码质量改进

> **项目**: neiliuxy/openclaw-auto-dev  
> **Issue**: #154 — feat(#152): 测试覆盖率提升与代码质量改进  
> **分支**: openclaw/issue-154  
> **阶段**: Stage 0 — Architect 输出  
> **日期**: 2026-04-16  
> **状态**: 已分析，规划完成

---

## 1. 概述

本 Issue 聚焦于提升代码质量与测试覆盖率，基于 Issue #152 的实现。主要涉及三个模块的改进：

1. **string_utils.cpp** — 增强 `replace()` 函数的边界情况处理
2. **ini_parser.cpp** — 完善 `save()` 方法并确保 INI 读写循环正常工作
3. **file_finder_test.cpp** — 补充文件搜索核心逻辑的单元测试覆盖

---

## 2. 现有代码分析

### 2.1 string_utils.cpp — ✅ 已实现，边缘情况已处理

当前 `replace()` 实现已包含边界情况处理：
- 空 pattern → 返回原字符串
- 空 source → 返回空字符串
- 防止无限循环（当 replacement 包含被替换字符串时）

`is_numeric()` 已实现，支持带符号整数检测。

### 2.2 ini_parser.cpp — ✅ save() 已实现

当前 `save()` 实现：
```cpp
bool Parser::save(const std::string& filepath) const {
    std::ofstream fout(filepath);
    if (!fout) return false;
    for (const auto& sec : data_) {
        fout << "[" << sec.first << "]\n";
        for (const auto& kv : sec.second.values) {
            fout << kv.first << " = " << kv.second << "\n";
        }
        fout << "\n";
    }
    return true;
}
```

**待验证**: save() 后再 load() 能否恢复完整数据（引号处理、注释保留需检查）。

### 2.3 file_finder_test.cpp — ✅ 已实现

当前测试覆盖：
- 精确匹配、星号通配符、问号通配符
- 扩展名匹配
- 大小写不敏感匹配
- 复杂 pattern（如 `test_*.cpp`）
- size formatting (B/KB/MB)

---

## 3. 实现计划

### 3.1 string_utils — 无需额外实现

`replace()` 和 `is_numeric()` 已满足验收标准。

**验证步骤**:
```bash
cd /home/admin/.openclaw/workspace/openclaw-auto-dev
g++ -o string_utils_test src/string_utils.cpp src/string_utils_test.cpp && ./string_utils_test
```

### 3.2 ini_parser — 需增加 round-trip 测试

**现状**: `save()` 和 `load()` 各自独立工作正常，但未验证 save→load 循环的数据完整性。

**Developer 任务**:
- 在 `ini_parser_test.cpp` 中增加 `test_save_load_roundtrip()` 测试用例
- 覆盖：含空格的值、含引号的值、中文 key/value、多行 section

**验证步骤**:
```bash
g++ -o ini_parser_test src/ini_parser.cpp src/ini_parser_test.cpp && ./ini_parser_test
```

### 3.3 file_finder_test — 编译并验证

**Developer 任务**:
- 编译并运行 file_finder_test.cpp，验证所有测试通过

**验证步骤**:
```bash
g++ -o file_finder_test src/file_finder.cpp src/file_finder_test.cpp -std=c++17 && ./file_finder_test
```

### 3.4 .pipeline-state 目录清理

**Developer 任务**:
- 扫描 `.pipeline-state/` 目录
- 确保只包含 `{issue_number}_stage` 格式的文件
- 移除任何临时文件或遗留文件

---

## 4. 验收标准

| 编号 | 标准 | 状态 |
|------|------|------|
| AC-1 | string_utils 所有函数（含 is_numeric）单元测试通过 | ✅ |
| AC-2 | ini_parser save() 可正常保存并加载 INI 文件 | 🔄 需 round-trip 测试 |
| AC-3 | file_finder_test.cpp 覆盖核心文件搜索逻辑 | ✅ 需编译验证 |
| AC-4 | .pipeline-state/ 目录仅含有效的 {issue}_stage 文件 | 🔄 需扫描清理 |

---

## 5. 涉及的源文件

| 文件 | 状态 | 说明 |
|------|------|------|
| `src/string_utils.cpp` | ✅ 已完成 | replace 边界情况已处理 |
| `src/string_utils_test.cpp` | ✅ 已完成 | 边缘测试已覆盖 |
| `src/ini_parser.cpp` | ✅ 已完成 | save() 已实现 |
| `src/ini_parser_test.cpp` | 🔄 需补完 | 需 round-trip 测试 |
| `src/file_finder.cpp` | ✅ | 无改动 |
| `src/file_finder_test.cpp` | ✅ 已完成 | 单元测试已编写 |
| `.pipeline-state/` | 🔄 需清理 | 需验证文件有效性 |

---

## 6. 后续阶段

- **Stage 1 (Developer)**: 补全 ini_parser round-trip 测试，编译验证，清理 .pipeline-state/
- **Stage 2 (Tester)**: 运行所有相关测试，确认通过率 100%
- **Stage 3 (Reviewer)**: 代码审查，确认质量标准达成，合并 PR
