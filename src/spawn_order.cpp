// Issue #95: test: 主会话顺序 spawn 验证
// 提供 spawn 顺序验证的工具函数

#include "spawn_order.h"

namespace spawn_order {

bool validate_sequence(int current_stage, int next_stage) {
    // 顺序 spawn: 1 -> 2 -> 3 -> 4
    // current_stage 必须小于 next_stage，且差距为 1
    return (next_stage == current_stage + 1);
}

std::string get_stage_name(int stage) {
    switch (stage) {
        case 1: return "Stage1";
        case 2: return "Stage2";
        case 3: return "Stage3";
        case 4: return "Stage4";
        default: return "Unknown";
    }
}

}  // namespace spawn_order
