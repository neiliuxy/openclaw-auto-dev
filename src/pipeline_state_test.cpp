// Issue #113: test: pipeline_state 核心函数覆盖率补全
// 补全 read_state 和 write_stage_with_error 的单元测试

#include "pipeline_state.h"
#include <iostream>
#include <cassert>
#include <vector>
#include <string>
#include <fstream>
#include <cstdio>

using namespace pipeline;

// Helper: clean up test state file
void cleanup(int issue_number) {
    std::string path = ".pipeline-state/" + std::to_string(issue_number) + "_stage";
    std::remove(path.c_str());
}

// Test: read_state - JSON 格式完整解析
void test_read_state_full_json() {
    const int issue = 99910;
    write_stage(issue, 3, ".pipeline-state");
    
    PipelineState state = read_state(issue, ".pipeline-state");
    assert(state.issue == issue);
    assert(state.stage == 3);
    assert(!state.updated_at.empty());
    assert(state.error == "null");
    
    cleanup(issue);
    std::cout << "✅ T1 read_state full JSON parsing passed\n";
}

// Test: read_state - 读取带 error 消息的 JSON
void test_read_state_with_error_message() {
    const int issue = 99911;
    write_stage_with_error(issue, 2, "timeout error", ".pipeline-state");
    
    PipelineState state = read_state(issue, ".pipeline-state");
    assert(state.issue == issue);
    assert(state.stage == 2);
    assert(state.error == "timeout error");
    
    cleanup(issue);
    std::cout << "✅ T2 read_state with error message passed\n";
}

// Test: read_state - 旧格式纯整数
void test_read_state_legacy_integer_format() {
    const int issue = 99912;
    // 写入旧格式（纯整数）
    {
        std::ofstream fout(".pipeline-state/" + std::to_string(issue) + "_stage");
        fout << "2";
        fout.close();
    }
    
    PipelineState state = read_state(issue, ".pipeline-state");
    assert(state.stage == 2);
    
    cleanup(issue);
    std::cout << "✅ T3 read_state legacy integer format passed\n";
}

// Test: read_state - 不存在的 Issue
void test_read_state_nonexistent() {
    PipelineState state = read_state(99999, ".pipeline-state");
    assert(state.stage == -1);
    assert(state.issue == 99999);
    std::cout << "✅ T4 read_state nonexistent issue passed\n";
}

// Test: write_stage_with_error - 正常写入
void test_write_stage_with_error_basic() {
    const int issue = 99913;
    bool ok = write_stage_with_error(issue, 1, "test error", ".pipeline-state");
    assert(ok == true);
    
    int stage = read_stage(issue, ".pipeline-state");
    assert(stage == 1);
    
    PipelineState state = read_state(issue, ".pipeline-state");
    assert(state.error == "test error");
    
    cleanup(issue);
    std::cout << "✅ T5 write_stage_with_error basic passed\n";
}

// Test: write_stage_with_error - error 为 null
void test_write_stage_with_error_null() {
    const int issue = 99914;
    bool ok = write_stage_with_error(issue, 4, "null", ".pipeline-state");
    assert(ok == true);
    
    PipelineState state = read_state(issue, ".pipeline-state");
    assert(state.error == "null");
    
    cleanup(issue);
    std::cout << "✅ T6 write_stage_with_error null error passed\n";
}

// Test: write_stage_with_error - error 为空字符串
void test_write_stage_with_error_empty() {
    const int issue = 99915;
    bool ok = write_stage_with_error(issue, 2, "", ".pipeline-state");
    assert(ok == true);
    
    PipelineState state = read_state(issue, ".pipeline-state");
    assert(state.error == "null");
    
    cleanup(issue);
    std::cout << "✅ T7 write_stage_with_error empty string passed\n";
}

// Test: write_stage_with_error - 特殊字符转义（JSON 存储为转义格式）
void test_write_stage_with_error_special_chars() {
    const int issue = 99916;
    // quote_string() escapes " and \ during write, so read_state returns escaped raw string
    bool ok = write_stage_with_error(issue, 1, "error with \"quotes\" and \\backslash\\", ".pipeline-state");
    assert(ok == true);
    
    PipelineState state = read_state(issue, ".pipeline-state");
    // read_state returns the raw string as stored (escaped), not unescaped
    assert(state.error == "error with \\\"quotes\\\" and \\\\backslash\\\\");
    
    cleanup(issue);
    std::cout << "✅ T8 write_stage_with_error special chars passed\n";
}

// Test: write_stage_with_error - 多字节 UTF-8 字符
void test_write_stage_with_error_utf8() {
    const int issue = 99917;
    bool ok = write_stage_with_error(issue, 2, "中文错误信息", ".pipeline-state");
    assert(ok == true);
    
    PipelineState state = read_state(issue, ".pipeline-state");
    assert(state.error == "中文错误信息");
    
    cleanup(issue);
    std::cout << "✅ T9 write_stage_with_error UTF-8 passed\n";
}

// Test: read_stage - 非 JSON 格式（旧格式整数）
void test_read_stage_legacy_integer() {
    const int issue = 99918;
    {
        std::ofstream fout(".pipeline-state/" + std::to_string(issue) + "_stage");
        fout << "4";
        fout.close();
    }
    
    int stage = read_stage(issue, ".pipeline-state");
    assert(stage == 4);
    
    cleanup(issue);
    std::cout << "✅ T10 read_stage legacy integer passed\n";
}

// Test: read_stage - JSON 但 stage 字段值异常（负数）
void test_read_stage_negative_stage() {
    const int issue = 99919;
    {
        std::ofstream fout(".pipeline-state/" + std::to_string(issue) + "_stage");
        fout << "{\"issue\": 99919, \"stage\": -1, \"updated_at\": \"2026-04-08T00:00:00+08:00\", \"error\": null}";
        fout.close();
    }
    
    int stage = read_stage(issue, ".pipeline-state");
    assert(stage == -1);
    
    cleanup(issue);
    std::cout << "✅ T11 read_stage negative stage value passed\n";
}

// Test: read_state - JSON 但所有字段存在
void test_read_state_all_fields() {
    const int issue = 99920;
    {
        std::ofstream fout(".pipeline-state/" + std::to_string(issue) + "_stage");
        fout << "{\n";
        fout << "  \"issue\": " << issue << ",\n";
        fout << "  \"stage\": 3,\n";
        fout << "  \"updated_at\": \"2026-04-08T12:34:56+08:00\",\n";
        fout << "  \"error\": \"some error\"\n";
        fout << "}\n";
        fout.close();
    }
    
    PipelineState state = read_state(issue, ".pipeline-state");
    assert(state.issue == issue);
    assert(state.stage == 3);
    assert(state.updated_at == "2026-04-08T12:34:56+08:00");
    assert(state.error == "some error");
    
    cleanup(issue);
    std::cout << "✅ T12 read_state all fields passed\n";
}

// Test: stage_to_description - 边界值
void test_stage_description_boundary() {
    assert(stage_to_description(0) == "NotStarted");
    assert(stage_to_description(4) == "PipelineDone");
    assert(stage_to_description(-1) == "Unknown");
    assert(stage_to_description(99) == "Unknown");
    std::cout << "✅ T13 stage_to_description boundary values passed\n";
}

// Test: read_stage - 损坏的 JSON（缺少 stage 字段）
void test_read_stage_missing_stage_field() {
    const int issue = 99921;
    {
        std::ofstream fout(".pipeline-state/" + std::to_string(issue) + "_stage");
        fout << "{\"issue\": 99921, \"updated_at\": \"2026-04-08T00:00:00+08:00\", \"error\": null}";
        fout.close();
    }
    
    int stage = read_stage(issue, ".pipeline-state");
    // 解析失败应返回 -1
    assert(stage == -1);
    
    cleanup(issue);
    std::cout << "✅ T14 read_stage missing stage field passed\n";
}

// Test: write_stage 返回值验证
void test_write_stage_return_value() {
    const int issue = 99922;
    // 先写入确保文件可写
    bool ok1 = write_stage(issue, 1, ".pipeline-state");
    assert(ok1 == true);
    
    // 读取验证
    int stage = read_stage(issue, ".pipeline-state");
    assert(stage == 1);
    
    cleanup(issue);
    std::cout << "✅ T15 write_stage return value passed\n";
}

// Test: read_state - JSON 中 error 字段为 null（非字符串 null）
void test_read_state_null_keyword() {
    const int issue = 99923;
    {
        std::ofstream fout(".pipeline-state/" + std::to_string(issue) + "_stage");
        fout << "{\"issue\": 99923, \"stage\": 2, \"updated_at\": \"2026-04-08\", \"error\": null}";
        fout.close();
    }
    
    PipelineState state = read_state(issue, ".pipeline-state");
    assert(state.stage == 2);
    assert(state.error == "null");
    
    cleanup(issue);
    std::cout << "✅ T16 read_state null keyword passed\n";
}

int main() {
    std::cout << "Running pipeline_state_test (Issue #113 - pipeline_state 覆盖率补全)...\n\n";
    
    test_read_state_full_json();
    test_read_state_with_error_message();
    test_read_state_legacy_integer_format();
    test_read_state_nonexistent();
    test_write_stage_with_error_basic();
    test_write_stage_with_error_null();
    test_write_stage_with_error_empty();
    test_write_stage_with_error_special_chars();
    test_write_stage_with_error_utf8();
    test_read_stage_legacy_integer();
    test_read_stage_negative_stage();
    test_read_state_all_fields();
    test_stage_description_boundary();
    test_read_stage_missing_stage_field();
    test_write_stage_return_value();
    test_read_state_null_keyword();
    
    std::cout << "\n✅ All 16 tests passed!\n";
    std::cout << "Issue #113: pipeline_state coverage complete\n";
    return 0;
}
