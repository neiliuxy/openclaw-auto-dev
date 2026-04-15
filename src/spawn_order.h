// Issue #95: test: 主会话顺序 spawn 验证
// 提供 spawn 顺序验证的工具函数

#ifndef SPAWN_ORDER_H
#define SPAWN_ORDER_H

#include <string>
#include <vector>

namespace spawn_order {

// Spawn 阶段定义
enum class SpawnStage {
    Stage1 = 1,  // 初始阶段
    Stage2 = 2,  // 分析 Issue 需求
    Stage3 = 3,  // 创建目录和 SPEC.md
    Stage4 = 4   // 提交到分支并更新状态
};

// 验证阶段顺序是否正确
// 返回 true 表示顺序正确
bool validate_sequence(int current_stage, int next_stage);

// 获取阶段的描述
std::string get_stage_name(int stage);

}  // namespace spawn_order

#endif  // SPAWN_ORDER_H
