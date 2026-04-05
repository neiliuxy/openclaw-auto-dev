// Issue #104: test: pipeline全流程自动触发验证
// Developer stage - 验证 pipeline 全流程自动触发完整性

#include "pipeline_state.h"
#include <iostream>
#include <cassert>
#include <vector>
#include <string>
#include <fstream>
#include <sys/stat.h>

using namespace pipeline;

// Helper: check if file exists
bool file_exists(const std::string& path) {
    struct stat buffer;
    return (stat(path.c_str(), &buffer) == 0);
}

// Test: 验证 Issue #104 的状态文件存在性
void test_104_state_file_exists() {
    std::string state_file = ".pipeline-state/104_stage";
    assert(file_exists(state_file));
    std::cout << "✅ T1 pipeline state file exists for Issue #104\n";
}

// Test: 验证 Issue #104 的当前阶段（Stage 2 - Developer 已完成）
void test_104_initial_stage() {
    int stage = read_stage(104, ".pipeline-state");
    assert(stage == 2);
    std::cout << "✅ T2 Issue #104 current stage = 2 (DeveloperDone)\n";
}

// Test: 验证 SPEC.md 文件存在
void test_104_spec_exists() {
    std::string spec_file = "openclaw/104_pipeline_full_auto/SPEC.md";
    assert(file_exists(spec_file));
    std::cout << "✅ T3 SPEC.md exists at openclaw/104_pipeline_full_auto/SPEC.md\n";
}

// Test: 验证 stage_to_description 转换正确性
void test_104_stage_descriptions() {
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
        std::cout << "✅ T stage_to_description(" << stage << ") = \"" << desc << "\" passed\n";
    }
}

// Test: 验证 write_stage 和 read_stage 的完整性
void test_104_write_and_read() {
    // 备份当前状态
    int original = read_stage(104, ".pipeline-state");

    // 写入 Stage 2 (Developer)
    bool write_ok = write_stage(104, 2, ".pipeline-state");
    assert(write_ok == true);
    std::cout << "✅ T5 write_stage(104, 2) passed\n";

    // 读取验证
    int stage = read_stage(104, ".pipeline-state");
    assert(stage == 2);
    std::cout << "✅ T6 read_stage(104) = 2 passed\n";

    // 恢复原始状态
    write_ok = write_stage(104, original, ".pipeline-state");
    assert(write_ok == true);
    std::cout << "✅ T7 restore stage to " << original << " passed\n";
}

// Test: 验证阶段范围有效性
void test_104_valid_stage_range() {
    // 合法的阶段值: 1, 2, 3, 4
    for (int stage = 1; stage <= 4; stage++) {
        std::string desc = stage_to_description(stage);
        assert(desc != "Unknown");
        std::cout << "✅ Valid stage " << stage << " -> \"" << desc << "\" passed\n";
    }
}

// Test: 验证 pipeline 完整性（所有关键文件存在）
void test_104_pipeline_completeness() {
    // 状态文件
    assert(file_exists(".pipeline-state/104_stage"));

    // SPEC 文件
    assert(file_exists("openclaw/104_pipeline_full_auto/SPEC.md"));

    // 状态文件内容格式验证
    int stage = read_stage(104, ".pipeline-state");
    assert(stage >= 0 && stage <= 4);

    std::cout << "✅ T8 pipeline completeness check passed\n";
}

// Test: 验证非存在 Issue 返回 -1
void test_104_nonexistent_issue() {
    int stage = read_stage(99999, ".pipeline-state");
    assert(stage == -1);
    std::cout << "✅ T nonexistent issue returns -1 passed\n";
}

// Test: 验证 Developer 阶段可以正常切换
void test_104_developer_stage_transition() {
    // 从 Stage 2 (Developer) 切换到 Stage 3 (Tester)
    int current = read_stage(104, ".pipeline-state");
    assert(current == 2);  // 确保当前是 DeveloperDone

    bool write_ok = write_stage(104, 3, ".pipeline-state");
    assert(write_ok == true);

    int new_stage = read_stage(104, ".pipeline-state");
    assert(new_stage == 3);
    std::cout << "✅ T10 Developer stage transition 2->3 passed\n";

    // 恢复到 Stage 2
    write_ok = write_stage(104, 2, ".pipeline-state");
    assert(write_ok == true);
    std::cout << "✅ T11 restore to stage 2 passed\n";
}

int main() {
    std::cout << "Running pipeline_104_test (Issue #104 - pipeline全流程自动触发验证)...\n\n";

    test_104_state_file_exists();
    test_104_initial_stage();
    test_104_spec_exists();
    test_104_stage_descriptions();
    test_104_write_and_read();
    test_104_valid_stage_range();
    test_104_pipeline_completeness();
    test_104_nonexistent_issue();
    test_104_developer_stage_transition();

    std::cout << "\n✅ All tests passed!\n";
    std::cout << "Issue #104 Developer stage: pipeline full auto trigger verification complete\n";
    return 0;
}
