# SPEC.md — Issue #152: 测试覆盖率提升与代码质量改进

## 1. Overview

**Issue:** #152 — 测试覆盖率提升与代码质量改进  
**Type:** Enhancement / Code Quality  
**Status:** Stage 0 — Architect Analysis  
**Created:** 2026-04-18

### Summary

Improve code quality and test coverage across multiple utility modules:
1. Complete `string_utils.cpp` (implement `is_numeric`, fix `replace` boundary cases)
2. Implement `ini_parser.cpp::save()` method
3. Add unit tests for `file_finder.cpp`
4. Clean up `.pipeline-state/` directory
5. Enhance `pipeline-runner.sh` error handling
6. Improve `heartbeat-check.sh` logging

---

## 2. Architecture

### 2.1 Component Map

```
openclaw-auto-dev/
├── src/
│   ├── string_utils.cpp        # String utilities (ENHANCE)
│   ├── string_utils_test.cpp   # Tests for string_utils
│   ├── ini_parser.cpp          # INI file parser (ENHANCE)
│   ├── file_finder.cpp         # File finder utility
│   └── file_finder_test.cpp    # Tests for file_finder (NEW)
├── scripts/
│   ├── pipeline-runner.sh      # Pipeline runner (ENHANCE)
│   └── heartbeat-check.sh      # Heartbeat monitor (ENHANCE)
└── .pipeline-state/            # Pipeline state (CLEANUP)
```

### 2.2 Module Responsibilities

| Module | Responsibility |
|--------|----------------|
| `string_utils.cpp` | String manipulation utilities |
| `ini_parser.cpp` | INI file read/write parser |
| `file_finder.cpp` | Recursive file searching by pattern |
| `pipeline-runner.sh` | State-driven pipeline orchestration |
| `heartbeat-check.sh` | Periodic system health checks |

---

## 3. Data Flow

### 3.1 string_utils.cpp — `is_numeric` implementation

```
Input:  string s
Output: bool (true if s is purely numeric digits)

Algorithm:
  1. Trim whitespace from both ends
  2. If trimmed string is empty → return false
  3. Iterate each char; if any non-digit → return false
  4. All digits pass → return true
```

### 3.2 string_utils.cpp — `replace` boundary cases

```
Input:  string s, char old, char new
Edge cases to handle:
  1. old == new → return original (no-op)
  2. s is empty → return empty
  3. old not found → return original
  4. Contiguous old chars → replace all occurrences
```

### 3.3 ini_parser.cpp — `save()` implementation

```
Input:  string filename, const Parser& parser
Output: bool success

Algorithm:
  1. Open file for write (fail if not writable)
  2. For each section [name]:
     a. Write "[name]\n"
     b. For each key=val in section:
        - Write "key=val\n"
     c. Write blank line between sections
  3. Close file, return success
```

### 3.4 file_finder.cpp — Test coverage targets

```
Core file finding logic to test:
  1. Pattern matching (wildcard *, ?)
  2. Recursive directory traversal
  3. Hidden file handling (. prefix)
  4. Permission-denied graceful handling
  5. Empty result for non-matching pattern
  6. Symlink handling (optional)
```

### 3.5 .pipeline-state/ cleanup rules

```
Files to REMOVE:
  - 0_stage         (invalid naming, use {issue}_stage format)
  - plan.json       (obsolete pipeline planning file)

Files to KEEP:
  - {issue_number}_stage  (valid stage marker files)
  - _next_stage           (pipeline advance hint)
  - _notify_cache         (notification deduplication cache)
```

### 3.6 pipeline-runner.sh error handling

```
On stage failure:
  1. Write error message to stage file:
     {
       "stage": N,
       "status": "error",
       "error": "<error description>",
       "failed_at": "<ISO timestamp>"
     }
  2. Set non-zero exit code
  3. Do NOT advance to next stage
  4. Optionally notify via Feishu
```

---

## 4. Key Components

### 4.1 `is_numeric` function

```cpp
// src/string_utils.h
bool is_numeric(const std::string& s);

// src/string_utils.cpp
bool is_numeric(const std::string& s) {
    std::string t = trim(s);
    if (t.empty()) return false;
    for (char c : t) {
        if (!std::isdigit(static_cast<unsigned char>(c))) return false;
    }
    return true;
}
```

### 4.2 `replace` edge case fix

```cpp
// In replace function, add at start:
// if (old_char == new_char) return s;
// if (s.empty()) return s;
```

### 4.3 `ini_parser::save`

```cpp
// src/ini_parser.h
bool save(const std::string& filename) const;

// src/ini_parser.cpp
bool Parser::save(const std::string& filename) const {
    std::ofstream ofs(filename);
    if (!ofs) return false;
    for (const auto& section : data_) {
        ofs << "[" << section.first << "]\n";
        for (const auto& kv : section.second) {
            ofs << kv.first << "=" << kv.second << "\n";
        }
        ofs << "\n";
    }
    return true;
}
```

### 4.4 `file_finder_test.cpp` structure

```cpp
// Test cases:
TEST_CASE("pattern_match_asterisk")     // *.cpp
TEST_CASE("pattern_match_question")     // test?.cpp
TEST_CASE("recursive_search")          // **/*.h
TEST_CASE("hidden_files")              // .*
TEST_CASE("permission_denied")         // graceful handling
TEST_CASE("no_match_empty")            // nonexistent pattern
```

### 4.5 Pipeline state file format

```json
// .pipeline-state/{issue}_stage
{
  "stage": 2,
  "status": "error",
  "error": "test compilation failed",
  "failed_at": "2026-04-22T10:30:00+08:00"
}
```

---

## 5. Acceptance Criteria

- [ ] **AC1:** `is_numeric("123")` returns `true`, `is_numeric("12a")` returns `false`
- [ ] **AC2:** `is_numeric("")` returns `false`, `is_numeric("  ")` returns `false`
- [ ] **AC3:** `replace("hello", 'l', 'x')` returns `"hexxo"`
- [ ] **AC4:** `replace("aaa", 'a', 'b')` returns `"bbb"` (contiguous chars)
- [ ] **AC5:** `replace("same", 'x', 'y')` returns `"same"` (no-op, char not found)
- [ ] **AC6:** `ini_parser` can save and reload INI file without data loss
- [ ] **AC7:** `file_finder_test.cpp` compiles and passes all test cases
- [ ] **AC8:** `.pipeline-state/` contains only valid `{issue}_stage` files + `_next_stage` + `_notify_cache`
- [ ] **AC9:** `pipeline-runner.sh` writes `error` field on stage failure
- [ ] **AC10:** All existing tests still pass after changes

---

## 6. Dependencies

- C++17 compiler
- CMake 3.10+
- gtest (Google Test Framework)
- POSIX shell utilities (`date`, `jq` if available)

## 7. Files to Modify

| File | Action |
|------|--------|
| `src/string_utils.cpp` | Implement `is_numeric`, fix `replace` |
| `src/string_utils.h` | Declare `is_numeric` |
| `src/ini_parser.cpp` | Implement `save()` |
| `src/file_finder_test.cpp` | Create with test cases |
| `scripts/pipeline-runner.sh` | Add error field writing |
| `scripts/heartbeat-check.sh` | Add scan result logging |
| `.pipeline-state/0_stage` | Delete |
| `.pipeline-state/plan.json` | Delete |

## 8. Files to Create

| File | Purpose |
|------|---------|
| `src/string_utils_test.cpp` | Unit tests for `is_numeric`, existing `replace` |
| `openclaw/152_test_coverage/SPEC.md` | This document |

---

*Architect: OpenClaw Pipeline Stage 0 Agent*  
*Generated: 2026-04-22T21:50:00+08:00*
