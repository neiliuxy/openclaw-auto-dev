// Issue #83: test: 验证 4-session pipeline 通知
// 实现四阶段代理流水线的通知机制

#include "pipeline_notifier.h"

namespace pipeline {

PipelineNotifier::PipelineNotifier(int issue_number)
    : issue_number_(issue_number) {
    reset();
}

Notification PipelineNotifier::create_notification(Stage stage, const std::string& artifact) {
    Notification notif;
    notif.stage = stage;
    notif.message = artifact;
    notif.issue_number = issue_number_;
    return notif;
}

std::string PipelineNotifier::notify_architect(const std::string& artifact) {
    last_notification_ = create_notification(Stage::Architect, artifact);
    return last_notification_.format();
}

std::string PipelineNotifier::notify_developer(const std::string& artifact) {
    last_notification_ = create_notification(Stage::Developer, artifact);
    return last_notification_.format();
}

std::string PipelineNotifier::notify_tester(const std::string& artifact) {
    last_notification_ = create_notification(Stage::Tester, artifact);
    return last_notification_.format();
}

std::string PipelineNotifier::notify_reviewer(const std::string& artifact) {
    last_notification_ = create_notification(Stage::Reviewer, artifact);
    return last_notification_.format();
}

void PipelineNotifier::reset() {
    last_notification_ = create_notification(Stage::Architect, "");
}

}  // namespace pipeline
