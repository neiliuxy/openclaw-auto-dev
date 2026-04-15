// Issue #83: test: 验证 4-session pipeline 通知
// 验证四阶段代理流水线（Architect → Developer → Tester → Reviewer）中每个阶段能独立发送消息通知

#ifndef PIPELINE_NOTIFIER_H
#define PIPELINE_NOTIFIER_H

#include <string>

namespace pipeline {

// 流水线阶段枚举
enum class Stage {
    Architect,
    Developer,
    Tester,
    Reviewer
};

// 获取阶段的字符串名称
inline std::string stage_to_string(Stage s) {
    switch (s) {
        case Stage::Architect:  return "Architect";
        case Stage::Developer:  return "Developer";
        case Stage::Tester:     return "Tester";
        case Stage::Reviewer:   return "Reviewer";
        default:                 return "Unknown";
    }
}

// 通知消息结构
struct Notification {
    Stage stage;
    std::string message;
    int issue_number;
    
    std::string format() const {
        return stage_to_string(stage) + " 完成，" + message + " for Issue #" + std::to_string(issue_number);
    }
};

// PipelineNotifier: 管理流水线各阶段的通知发送
class PipelineNotifier {
public:
    explicit PipelineNotifier(int issue_number);
    
    // 发送各阶段通知（返回格式化消息字符串）
    std::string notify_architect(const std::string& artifact);
    std::string notify_developer(const std::string& artifact);
    std::string notify_tester(const std::string& artifact);
    std::string notify_reviewer(const std::string& artifact);
    
    // 获取最后发送的通知
    const Notification& last_notification() const { return last_notification_; }
    
    // 重置通知记录
    void reset();
    
private:
    int issue_number_;
    Notification last_notification_;
    
    Notification create_notification(Stage stage, const std::string& artifact);
};

}  // namespace pipeline

#endif  // PIPELINE_NOTIFIER_H
