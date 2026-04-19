# TEST_REPORT.md - Issue #99

## Issue Information
- **Issue**: #99
- **Title**: (unknown - no SPEC.md found for issue #99)
- **Test Date**: 2026-04-05 18:07 GMT+8
- **Tester Stage**: Stage 2 → Stage 3
- **Branch**: openclaw/issue-97 (current HEAD)

---

## Test Summary

**Overall Status**: ❌ FAIL

The pipeline_99_test binary **FAILS** due to state file format incompatibility with `read_stage()` function.

---

## Test Execution

### Build Status
```
Build completed successfully.
spawn_order_test: Built ✅
pipeline_97_test: Built ✅
pipeline_99_test: Prebuilt binary (no source in current branch)
```

### CMake Registered Tests (ctest)
```
Test #1: spawn_order_test ....... ✅ PASSED
Test #2: pipeline_97_test ........ ❌ FAILED (97_stage file missing)
```

### Direct Binary Execution
```
./src/pipeline_99_test: ❌ FAILED
  Assertion `stage >= 1 && stage <= 4' failed.
  Exit code: 134 (Aborted)
```

---

## State File Analysis

### Issue #99 State File (`.pipeline-state/99_stage`)
```
issue_num=99
stage=2
```

**Format**: Key=value format (not plain integer, not JSON)

### Issue #97 State File
- **Status**: Missing (deleted)
- **Impact**: pipeline_97_test fails

---

## Root Cause Analysis

### Issue 1: State File Format Incompatibility (CRITICAL)

**Description**: The state file `.pipeline-state/99_stage` contains key=value format:
```
issue_num=99
stage=2
```

But `read_stage()` in `pipeline_state.cpp` only handles plain integer format:
```cpp
int read_stage(int issue_number, const std::string& state_dir) {
    std::ifstream fin(path.str());
    if (!fin.is_open()) {
        return -1;
    }
    int stage = -1;
    fin >> stage;  // Parses first token as integer - FAILS on "issue_num=99"
    fin.close();
    return stage;
}
```

**Impact**: `read_stage(99, ".pipeline-state")` returns `-1` (parse failure) instead of actual stage `2`.

### Issue 2: Stale State File (Local vs Remote mismatch)

**Local** (current branch):
```
issue_num=99
stage=2
```

**Remote** (`origin/openclaw/issue-99`):
```
2
```

The local state file format differs from the remote, suggesting manual editing or corruption.

### Issue 3: Test Assertion Too Strict

The pipeline_99_test binary (prebuilt) asserts:
```cpp
assert(stage >= 1 && stage <= 4);
```

This fails when `read_stage()` returns `-1` (parse failure).

---

## Detailed Test Results

| Test | Description | Expected | Actual | Status |
|------|-------------|----------|--------|--------|
| spawn_order_test | Stage sequence validation | All 21 tests pass | 21/21 passed | ✅ PASS |
| pipeline_97_test | Issue #97 state validation | stage 1-4 | 97_stage missing | ❌ FAIL |
| pipeline_99_test | Issue #99 state validation | stage 1-4 | read_stage returns -1 | ❌ FAIL |

---

## Files Involved

### Source Files
- `src/pipeline_state.cpp` - `read_stage()` cannot parse key=value format
- `src/pipeline_97_test.cpp` - Test for issue #97
- `src/pipeline_99_test` - Prebuilt binary (source not in current branch)

### State Files
- `.pipeline-state/99_stage` - Contains `issue_num=99\nstage=2` (wrong format)
- `.pipeline-state/97_stage` - Missing

---

## Recommendations

### For Developer (Immediate Fix Required)

1. **Fix `pipeline_state.cpp`**: Update `read_stage()` to handle three formats:
   - JSON format: `{"issue_num":N,"stage":S}`
   - Key=value format: `issue_num=N\nstage=S`
   - Plain integer format: `S`

2. **Restore state file**: The 99_stage file format should be fixed to match what `read_stage()` expects

3. **Fix 97_stage**: Create the missing state file for issue #97

---

## Conclusion

The test fails due to **format incompatibility** between the state file (key=value format) and the parser (plain integer only). The `read_stage()` function was never updated to handle the key=value or JSON formats that state files now use.

**Test Status**: ❌ FAIL - Requires Developer intervention to fix `read_stage()` format parsing

**Recommendation**: The Developer should update `pipeline_state.cpp` to handle all three state file formats before testing can proceed.
