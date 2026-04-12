# Test Report — Issue #87

- **Issue**: 87
- **Slug**: test: pipeline-runner.sh 状态驱动验证
- **Test Date**: 2026-04-05T11:13:55+0800
- **Build Status**: PASS

## Build Verification

```
N/A - This is a shell script test, not a build test.
Pipeline runner script exists and is executable.
```

## Test Cases

| Test Case | Status | Notes |
|-----------|--------|-------|
| TC-5: stage=4 跳过验证 | ✅ PASS | stage=4 时无 Git 操作，跳过输出正确 |
| TC-6: JSON 格式验证 | ✅ PASS | stage=0~4 全部通过，issue/stage/error 字段正确 |
| TC-1: 全流程验证 | ⏭️ SKIP | 需要真实 GitHub Issue，设置 RUN_REAL_TESTS=true 执行 |
| TC-2: 断点续跑 (stage=1→4) | ⏭️ SKIP | 需要真实 GitHub Issue |
| TC-3: 断点续跑 (stage=2→4) | ⏭️ SKIP | 需要真实 GitHub Issue |
| TC-4: 断点续跑 (stage=3→4) | ⏭️ SKIP | 需要真实 GitHub Issue |
| TC-7: GitHub 标签流转 | ⏭️ SKIP | 需要真实 GitHub Issue |

## Summary

**Result**: PASS

TC-5 和 TC-6 不依赖真实 GitHub Issue，全部通过（10/10 passed, 0 failed）。

### 发现并修复的测试脚本问题

1. **PROJECT_ROOT 路径错误**：原脚本 `PROJECT_ROOT="$(cd "$SCRIPT_DIR" && pwd)"` 指向 tests 目录而非项目根目录，改为 `"$SCRIPT_DIR/.."` 修正。
2. **((TESTS_PASSED++)) 在 set -e 下崩溃**：post-increment 在 TESTS_PASSED=0 时返回 0，导致 `((0))` 为 false 触发 `set -e` 退出。修复：改为 `((++TESTS_PASSED))`（pre-increment）并 `declare -i` 声明变量。
