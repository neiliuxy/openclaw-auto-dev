// Issue #97: test: 方案B自动pipeline验证
// Developer stage - 验证 pipeline state 机制对 Issue #97 的正确性

#include "pipeline_state.h"
#include <iostream>
#include <cassert>
#include <vector>
#include <string>

using namespace pipeline;

// Test: 验证 Issue #97 的初始状态（Stage 1 - Architect 完成）
void test_97_initial_stage() {
    // Architect 阶段完成后，状态应为 1
    int stage = read_stage(97, ".pipeline-state");
    assert(stage == 1);
    std::cout << "✅ T1 Issue #97 initial stage = 1 (ArchitectDone) passed\n";
}

// Test: 验证 write_stage 和 read_stage 的完整性
void test_97_write_and_read() {
    // 备份当前状态
    int original = read_stage(97, ".pipeline-state");
    
    // 写入 Stage 2 (Developer)
    bool write_ok = write_stage(97, 2, ".pipeline-state");
    assert(write_ok == true);
    std::cout << "✅ T2 write_stage(97, 2) passed\n";
    
    // 读取验证
    int stage = read_stage(97, ".pipeline-state");
    assert(stage == 2);
    std::cout << "✅ T3 read_stage(97) = 2 passed\n";
    
    // 恢复原始状态
    write_stage(97, original, ".pipeline-state");
    std::cout << "✅ T4 restore original stage = " << original << " passed\n";
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
        std::cout << "✅ stage_to_description(" << stage << ") = \"" << desc << "\" passed\n";
    }
}

// Test: 验证阶段范围有效性
void test_97_valid_stage_range() {
    // 合法的阶段值: 1, 2, 3, 4
    for (int stage = 1; stage <= 4; stage++) {
        std::string desc = stage_to_description(stage);
        assert(desc != "Unknown");
        std::cout << "✅ Valid stage " << stage << " -> \"" << desc << "\" passed\n";
    }
}

// Test: 验证非存在 Issue 返回 -1
void test_97_nonexistent_issue() {
    // Issue #99999 应该不存在，返回 -1
    int stage = read_stage(99999, ".pipeline-state");
    assert(stage == -1);
    std::cout << "✅ T nonexistent issue returns -1 passed\n";
}

int main() {
    std::cout << "Running pipeline_97_test (Issue #97 - 方案B自动pipeline验证)...\n\n";
    
    test_97_initial_stage();
    test_97_write_and_read();
    test_97_stage_descriptions();
    test_97_valid_stage_range();
    test_97_nonexistent_issue();
    
    std::cout << "\n✅ All tests passed!\n";
    std::cout << "Issue #97 Developer stage: pipeline state validation complete\n";
    return 0;
}
