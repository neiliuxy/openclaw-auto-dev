// Issue #93: test: 验证心跳自动续跑
// 提供 pipeline 状态文件的读写工具函数

#ifndef PIPELINE_STATE_H
#define PIPELINE_STATE_H

#include <string>

namespace pipeline {

// Pipeline 阶段值
enum class PipelineStage {
    NotStarted = 0,      // 未开始
    ArchitectDone = 1,   // Architect 完成
    DeveloperDone = 2,   // Developer 完成
    TesterDone = 3,      // Tester 完成
    PipelineDone = 4     // Pipeline 完成
};

// 读取指定 Issue 的 pipeline 状态文件
// 返回 -1 表示文件不存在或读取失败
int read_stage(int issue_number, const std::string& state_dir = ".pipeline-state");

// 写入指定 Issue 的 pipeline 状态文件
// 返回 true 表示成功
bool write_stage(int issue_number, int stage, const std::string& state_dir = ".pipeline-state");

// 将 stage 值转换为字符串描述
std::string stage_to_description(int stage);

}  // namespace pipeline

#endif  // PIPELINE_STATE_H
