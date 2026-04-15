// Issue #83: test: 验证 4-session pipeline 通知
// 验证四阶段代理流水线（Architect → Developer → Tester → Reviewer）中每个阶段能独立发送消息通知

#include <iostream>
#include <string>
#include <cassert>
#include "pipeline_notifier.h"

// 测试 Architect 阶段通知
bool test_architect_notification() {
    pipeline::PipelineNotifier notifier(83);
    
    std::string msg = notifier.notify_architect("SPEC.md 已生成");
    
    // 验证消息格式
    if (msg.find("Architect") == std::string::npos) {
        std::cerr << "[FAIL] Architect notification missing 'Architect'" << std::endl;
        return false;
    }
    if (msg.find("SPEC.md") == std::string::npos) {
        std::cerr << "[FAIL] Architect notification missing 'SPEC.md'" << std::endl;
        return false;
    }
    if (msg.find("#83") == std::string::npos) {
        std::cerr << "[FAIL] Architect notification missing '#83'" << std::endl;
        return false;
    }
    
    std::cout << "[PASS] test_architect_notification: " << msg << std::endl;
    return true;
}

// 测试 Developer 阶段通知
bool test_developer_notification() {
    pipeline::PipelineNotifier notifier(83);
    
    std::string msg = notifier.notify_developer("代码已实现");
    
    if (msg.find("Developer") == std::string::npos) {
        std::cerr << "[FAIL] Developer notification missing 'Developer'" << std::endl;
        return false;
    }
    if (msg.find("代码已实现") == std::string::npos) {
        std::cerr << "[FAIL] Developer notification missing '代码已实现'" << std::endl;
        return false;
    }
    if (msg.find("#83") == std::string::npos) {
        std::cerr << "[FAIL] Developer notification missing '#83'" << std::endl;
        return false;
    }
    
    std::cout << "[PASS] test_developer_notification: " << msg << std::endl;
    return true;
}

// 测试 Tester 阶段通知
bool test_tester_notification() {
    pipeline::PipelineNotifier notifier(83);
    
    std::string msg = notifier.notify_tester("测试通过");
    
    if (msg.find("Tester") == std::string::npos) {
        std::cerr << "[FAIL] Tester notification missing 'Tester'" << std::endl;
        return false;
    }
    if (msg.find("测试通过") == std::string::npos) {
        std::cerr << "[FAIL] Tester notification missing '测试通过'" << std::endl;
        return false;
    }
    if (msg.find("#83") == std::string::npos) {
        std::cerr << "[FAIL] Tester notification missing '#83'" << std::endl;
        return false;
    }
    
    std::cout << "[PASS] test_tester_notification: " << msg << std::endl;
    return true;
}

// 测试 Reviewer 阶段通知
bool test_reviewer_notification() {
    pipeline::PipelineNotifier notifier(83);
    
    std::string msg = notifier.notify_reviewer("审核完成");
    
    if (msg.find("Reviewer") == std::string::npos) {
        std::cerr << "[FAIL] Reviewer notification missing 'Reviewer'" << std::endl;
        return false;
    }
    if (msg.find("审核完成") == std::string::npos) {
        std::cerr << "[FAIL] Reviewer notification missing '审核完成'" << std::endl;
        return false;
    }
    if (msg.find("#83") == std::string::npos) {
        std::cerr << "[FAIL] Reviewer notification missing '#83'" << std::endl;
        return false;
    }
    
    std::cout << "[PASS] test_reviewer_notification: " << msg << std::endl;
    return true;
}

// 测试各阶段通知可区分
bool test_notifications_distinguishable() {
    pipeline::PipelineNotifier notifier(83);
    
    std::string architect_msg = notifier.notify_architect("SPEC.md 已生成");
    std::string developer_msg = notifier.notify_developer("代码已实现");
    std::string tester_msg = notifier.notify_tester("测试通过");
    std::string reviewer_msg = notifier.notify_reviewer("审核完成");
    
    // 各消息应该能明确区分
    if (architect_msg == developer_msg || architect_msg == tester_msg || architect_msg == reviewer_msg) {
        std::cerr << "[FAIL] Notifications are not distinguishable" << std::endl;
        return false;
    }
    if (developer_msg == tester_msg || developer_msg == reviewer_msg) {
        std::cerr << "[FAIL] Notifications are not distinguishable" << std::endl;
        return false;
    }
    if (tester_msg == reviewer_msg) {
        std::cerr << "[FAIL] Notifications are not distinguishable" << std::endl;
        return false;
    }
    
    std::cout << "[PASS] test_notifications_distinguishable" << std::endl;
    return true;
}

// 测试通知消息包含 Issue 编号
bool test_issue_number_in_notification() {
    pipeline::PipelineNotifier notifier(83);
    
    std::string architect_msg = notifier.notify_architect("SPEC.md 已生成");
    
    if (architect_msg.find("#83") == std::string::npos) {
        std::cerr << "[FAIL] Issue number missing from notification" << std::endl;
        return false;
    }
    
    std::cout << "[PASS] test_issue_number_in_notification" << std::endl;
    return true;
}

int main() {
    int passed = 0;
    int total = 6;
    
    std::cout << "=== Issue #83: 4-session Pipeline Notification Tests ===" << std::endl;
    std::cout << std::endl;
    
    if (test_architect_notification()) passed++;
    if (test_developer_notification()) passed++;
    if (test_tester_notification()) passed++;
    if (test_reviewer_notification()) passed++;
    if (test_notifications_distinguishable()) passed++;
    if (test_issue_number_in_notification()) passed++;
    
    std::cout << std::endl;
    std::cout << "=== Result: " << passed << "/" << total << " passed ===" << std::endl;
    
    return (passed == total) ? 0 : 1;
}
