// Issue #97: test: 方案B自动pipeline验证
// Developer stage - 验证 pipeline state 机制对 Issue #97 的正确性

#include "pipeline_state.h"
#include <iostream>
#include <cassert>
#include <vector>
#include <string>
#include <cstdio>

using namespace pipeline;

// Test: 验证 Issue #97 的当前状态
// NOTE: state file may not exist for completed/merged issues (-1 is valid)
void test_97_initial_stage() {
    int stage = read_stage(97, ".pipeline-state");
    // -1 is valid (file not found, e.g. completed/merged issue)
    // 1-4 are valid pipeline stages
    assert(stage == -1 || (stage >= 1 && stage <= 4));
    if (stage == -1) {
        std::cout << "[PASS] T1 Issue #97 state file not found (stage=-1, issue may be merged/completed)" << std::endl;
    } else {
        std::string desc = stage_to_description(stage);
        assert(desc != "Unknown");
        std::cout << "[PASS] T1 Issue #97 current stage = " << stage << " (" << desc << ")" << std::endl;
    }
}

// Test: 验证 write_stage 和 read_stage 的完整性
// NOTE: state file may not exist (-1) - in that case we still test write/read roundtrip
void test_97_write_and_read() {
    // 备份当前状态（可能是 -1 表示文件不存在）
    int original = read_stage(97, ".pipeline-state");
    
    // 写入 Stage 2 (Developer)
    bool write_ok = write_stage(97, 2, ".pipeline-state");
    assert(write_ok == true);
    std::cout << "[PASS] T2 write_stage(97, 2)" << std::endl;
    
    // 读取验证
    int stage = read_stage(97, ".pipeline-state");
    assert(stage == 2);
    std::cout << "[PASS] T3 read_stage(97) = 2" << std::endl;
    
    // 恢复原始状态（如果原为 -1，删除文件以模拟原始状态）
    if (original == -1) {
        // 文件本来不存在，恢复时删除我们创建的文件
        std::remove(".pipeline-state/97_stage");
        std::cout << "[PASS] T4 restored to original state (no file)" << std::endl;
    } else {
        write_stage(97, original, ".pipeline-state");
        std::cout << "[PASS] T4 restore original stage = " << original << std::endl;
    }
}

// Test: 验证 stage_to_description 转换正确性
void test_97_stage_descriptions() {
    std::vector<std::pair<int, std::string>> expected = {
        {0, "NotStarted"},
        {1, "ArchitectDone"},
        {2, "DeveloperDone"},
        {3, "TesterDone"},
        {4, "PipelineDone"},
        {5, "Unknown"}
    };
    
    for (const auto& [stage, desc] : expected) {
        std::string result = stage_to_description(stage);
        assert(result == desc);
        std::cout << "[PASS] stage_to_description(" << stage << ") = \"" << desc << "\"" << std::endl;
    }
}

// Test: 验证阶段范围有效性
void test_97_valid_stage_range() {
    // 合法的阶段值: 1, 2, 3, 4
    for (int stage = 1; stage <= 4; stage++) {
        std::string desc = stage_to_description(stage);
        assert(desc != "Unknown");
        std::cout << "[PASS] Valid stage " << stage << " -> \"" << desc << "\"" << std::endl;
    }
}

// Test: 验证非存在 Issue 返回 -1
void test_97_nonexistent_issue() {
    // Issue #99999 应该不存在，返回 -1
    int stage = read_stage(99999, ".pipeline-state");
    assert(stage == -1);
    std::cout << "[PASS] T nonexistent issue returns -1" << std::endl;
}

int main() {
    std::cout << "Running pipeline_97_test (Issue #97 - 方案B自动pipeline验证)..." << std::endl << std::endl;
    
    test_97_initial_stage();
    test_97_write_and_read();
    test_97_stage_descriptions();
    test_97_valid_stage_range();
    test_97_nonexistent_issue();
    
    std::cout << std::endl << "=== All tests passed! ===" << std::endl;
    std::cout << "Issue #97 Developer stage: pipeline state validation complete" << std::endl;
    return 0;
}
