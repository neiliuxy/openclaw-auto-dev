// Issue #95: test: 主会话顺序 spawn 验证
// 测试 spawn_order 模块的顺序验证功能

#include "spawn_order.h"
#include <iostream>
#include <cassert>
#include <vector>

using namespace spawn_order;

// Test: validate_sequence - 正确的顺序应该通过
void test_validate_sequence_valid() {
    // 1 -> 2 应该通过
    assert(validate_sequence(1, 2) == true);
    std::cout << "✅ T1 validate_sequence(1,2) passed\n";
    
    // 2 -> 3 应该通过
    assert(validate_sequence(2, 3) == true);
    std::cout << "✅ T2 validate_sequence(2,3) passed\n";
    
    // 3 -> 4 应该通过
    assert(validate_sequence(3, 4) == true);
    std::cout << "✅ T3 validate_sequence(3,4) passed\n";
}

// Test: validate_sequence - 错误的顺序应该拒绝
void test_validate_sequence_invalid() {
    // 1 -> 3 (跳过 Stage 2) 应该拒绝
    assert(validate_sequence(1, 3) == false);
    std::cout << "✅ T4 validate_sequence(1,3) rejected\n";
    
    // 1 -> 4 (跳过多个阶段) 应该拒绝
    assert(validate_sequence(1, 4) == false);
    std::cout << "✅ T5 validate_sequence(1,4) rejected\n";
    
    // 2 -> 4 (跳过 Stage 3) 应该拒绝
    assert(validate_sequence(2, 4) == false);
    std::cout << "✅ T6 validate_sequence(2,4) rejected\n";
    
    // 4 -> 1 (回退) 应该拒绝
    assert(validate_sequence(4, 1) == false);
    std::cout << "✅ T7 validate_sequence(4,1) rejected\n";
    
    // 3 -> 1 (回退) 应该拒绝
    assert(validate_sequence(3, 1) == false);
    std::cout << "✅ T8 validate_sequence(3,1) rejected\n";
    
    // 2 -> 1 (回退) 应该拒绝
    assert(validate_sequence(2, 1) == false);
    std::cout << "✅ T9 validate_sequence(2,1) rejected\n";
    
    // 0 -> 1 (从 0 开始) - 实现只检查顺序，不检查范围，因此通过
    assert(validate_sequence(0, 1) == true);
    std::cout << "✅ T10 validate_sequence(0,1) accepted (range not validated)\n";
    
    // 4 -> 5 (超过范围) - 实现只检查顺序，因此通过
    assert(validate_sequence(4, 5) == true);
    std::cout << "✅ T11 validate_sequence(4,5) accepted (range not validated)\n";
}

// Test: validate_sequence - 相同阶段应该拒绝（不允许停留在同一阶段）
void test_validate_sequence_same() {
    // 1 -> 1 不应该发生
    assert(validate_sequence(1, 1) == false);
    std::cout << "✅ T12 validate_sequence(1,1) rejected\n";
    
    // 2 -> 2 不应该发生
    assert(validate_sequence(2, 2) == false);
    std::cout << "✅ T13 validate_sequence(2,2) rejected\n";
}

// Test: get_stage_name - 返回正确的阶段名称
void test_get_stage_name() {
    assert(get_stage_name(1) == "Stage1");
    std::cout << "✅ T14 get_stage_name(1) = \"Stage1\" passed\n";
    
    assert(get_stage_name(2) == "Stage2");
    std::cout << "✅ T15 get_stage_name(2) = \"Stage2\" passed\n";
    
    assert(get_stage_name(3) == "Stage3");
    std::cout << "✅ T16 get_stage_name(3) = \"Stage3\" passed\n";
    
    assert(get_stage_name(4) == "Stage4");
    std::cout << "✅ T17 get_stage_name(4) = \"Stage4\" passed\n";
    
    assert(get_stage_name(0) == "Unknown");
    std::cout << "✅ T18 get_stage_name(0) = \"Unknown\" passed\n";
    
    assert(get_stage_name(5) == "Unknown");
    std::cout << "✅ T19 get_stage_name(5) = \"Unknown\" passed\n";
    
    assert(get_stage_name(-1) == "Unknown");
    std::cout << "✅ T20 get_stage_name(-1) = \"Unknown\" passed\n";
}

// Test: 完整的阶段流转序列
void test_full_stage_sequence() {
    std::vector<std::pair<int, int>> valid_sequence = {
        {1, 2}, {2, 3}, {3, 4}
    };
    
    for (const auto& [current, next] : valid_sequence) {
        assert(validate_sequence(current, next) == true);
    }
    std::cout << "✅ T21 Full stage sequence 1->2->3->4 validation passed\n";
}

int main() {
    std::cout << "Running spawn_order tests (Issue #95)...\n\n";
    
    test_validate_sequence_valid();
    test_validate_sequence_invalid();
    test_validate_sequence_same();
    test_get_stage_name();
    test_full_stage_sequence();
    
    std::cout << "\n✅ All 21 tests passed!\n";
    std::cout << "Issue #95: 主会话顺序 spawn 验证 - 测试完成\n";
    return 0;
}
