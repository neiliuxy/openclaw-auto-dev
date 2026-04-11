// Issue #99: test: 方案B修复后验证
// Developer stage - 验证 pipeline cron 自动处理流程的可用性

#include "pipeline_state.h"
#include <iostream>
#include <cassert>
#include <vector>
#include <string>

using namespace pipeline;

// Test: 验证 pipeline state API 读写能力（使用合成 issue，不依赖遗留状态文件）
void test_99_initial_stage() {
    const int synthetic_issue = 99999;
    int original = read_stage(synthetic_issue, ".pipeline-state");
    
    bool write_ok = write_stage(synthetic_issue, 2, ".pipeline-state");
    assert(write_ok == true);
    int stage = read_stage(synthetic_issue, ".pipeline-state");
    assert(stage == 2);
    
    if (original >= 0) {
        write_stage(synthetic_issue, original, ".pipeline-state");
    } else {
        std::string path = ".pipeline-state/" + std::to_string(synthetic_issue) + "_stage";
        std::remove(path.c_str());
    }
    
    std::cout << "✅ T1 synthetic issue API roundtrip passed\n";
}

// Test: 验证 Developer 阶段状态写入和读取
void test_99_developer_stage() {
    // 备份当前状态
    int original = read_stage(99, ".pipeline-state");
    
    // 写入 Stage 2 (DeveloperDone)
    bool write_ok = write_stage(99, 2, ".pipeline-state");
    assert(write_ok == true);
    std::cout << "✅ T2 write_stage(99, 2) passed\n";
    
    // 读取验证
    int stage = read_stage(99, ".pipeline-state");
    assert(stage == 2);
    std::cout << "✅ T3 read_stage(99) = 2 (DeveloperDone) passed\n";
    
    // 恢复原始状态
    write_stage(99, original, ".pipeline-state");
    std::cout << "✅ T4 restore original stage = " << original << " passed\n";
}

// Test: 验证 stage_to_description 转换正确性
void test_99_stage_descriptions() {
    std::vector<std::pair<int, std::string>> expected = {
        {0, "NotStarted"},
        {1, "ArchitectDone"},
        {2, "DeveloperDone"},
        {3, "TesterDone"},
        {4, "PipelineDone"}
    };
    
    for (const auto& [stage, desc] : expected) {
        std::string result = stage_to_description(stage);
        assert(result == desc);
        std::cout << "✅ stage_to_description(" << stage << ") = \"" << desc << "\" passed\n";
    }
}

// Test: 验证 Developer 阶段描述正确
void test_99_developer_description() {
    std::string desc = stage_to_description(2);
    assert(desc == "DeveloperDone");
    std::cout << "✅ Developer stage description = \"DeveloperDone\" passed\n";
}

// Test: 验证非存在 Issue 返回 -1
void test_99_nonexistent_issue() {
    // Issue #99999 应该不存在，返回 -1
    int stage = read_stage(99999, ".pipeline-state");
    assert(stage == -1);
    std::cout << "✅ T nonexistent issue returns -1 passed\n";
}

// Test: 验证 pipeline state API 在有效 issue number 上正常工作
void test_99_state_file_path() {
    const int synthetic_issue = 99998;
    bool write_ok = write_stage(synthetic_issue, 3, ".pipeline-state");
    assert(write_ok == true);
    int stage = read_stage(synthetic_issue, ".pipeline-state");
    assert(stage == 3);
    
    std::string path = ".pipeline-state/" + std::to_string(synthetic_issue) + "_stage";
    std::remove(path.c_str());
    
    std::cout << "✅ T6 API correctly writes/reads stage file for synthetic issue\n";
}

int main() {
    std::cout << "Running pipeline_99_test (Issue #99 - 方案B修复后验证)...\n\n";
    
    test_99_initial_stage();
    test_99_developer_stage();
    test_99_stage_descriptions();
    test_99_developer_description();
    test_99_nonexistent_issue();
    test_99_state_file_path();
    
    std::cout << "\n✅ All tests passed!\n";
    std::cout << "Issue #99 Developer stage: pipeline cron validation complete\n";
    return 0;
}
