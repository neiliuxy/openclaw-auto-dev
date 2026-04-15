// Issue #81: test: 4-session pipeline verification
// Test for pipeline_state module

#include <iostream>
#include <string>
#include <cassert>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <vector>
#include "pipeline_state.h"

using namespace pipeline;

bool test_pipeline_state_init() {
    std::string test_dir = "/tmp/pipeline_state_test_" + std::to_string(getpid());
    mkdir(test_dir.c_str(), 0755);

    PipelineStateManager mgr(test_dir, 81);
    bool ok = mgr.initialize();
    if (ok) {
        std::cout << "[PASS] test_pipeline_state_init" << std::endl;
    } else {
        std::cout << "[FAIL] test_pipeline_state_init" << std::endl;
    }

    // Cleanup
    rmdir(test_dir.c_str());
    return ok;
}

bool test_pipeline_state_manager_creation() {
    std::string test_dir = "/tmp/pipeline_state_test_" + std::to_string(getpid());
    mkdir(test_dir.c_str(), 0755);

    PipelineStateManager mgr(test_dir, 81);
    
    // Initialize
    if (!mgr.initialize()) {
        std::cout << "[FAIL] test_pipeline_state_manager_creation: init failed" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    // Check initial state
    if (mgr.get_current_stage() != Stage::Architect) {
        std::cout << "[FAIL] test_pipeline_state_manager_creation: initial stage not Architect" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    if (mgr.get_status() != StageStatus::Running) {
        std::cout << "[FAIL] test_pipeline_state_manager_creation: initial status not Running" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    std::cout << "[PASS] test_pipeline_state_manager_creation" << std::endl;
    rmdir(test_dir.c_str());
    return true;
}

bool test_stage_start_and_complete() {
    std::string test_dir = "/tmp/pipeline_state_test_" + std::to_string(getpid());
    mkdir(test_dir.c_str(), 0755);

    PipelineStateManager mgr(test_dir, 81);
    mgr.initialize();

    // Start Architect stage
    if (!mgr.start_stage(Stage::Architect, "sess_architect_81")) {
        std::cout << "[FAIL] test_stage_start_and_complete: start_stage failed" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    // Complete Architect stage
    std::vector<std::string> files;
    files.push_back("docs/PIPELINE-ARCHITECTURE-81.md");
    if (!mgr.complete_stage(Stage::Architect, "Architect completed design doc", files)) {
        std::cout << "[FAIL] test_stage_start_and_complete: complete_stage failed" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    // Verify stage is completed
    if (!mgr.is_stage_completed(Stage::Architect)) {
        std::cout << "[FAIL] test_stage_start_and_complete: is_stage_completed returned false" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    // Advance to next stage
    if (!mgr.advance_to_next_stage()) {
        std::cout << "[FAIL] test_stage_start_and_complete: advance_to_next_stage failed" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    if (mgr.get_current_stage() != Stage::Developer) {
        std::cout << "[FAIL] test_stage_start_and_complete: current stage not Developer after advance" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    std::cout << "[PASS] test_stage_start_and_complete" << std::endl;
    rmdir(test_dir.c_str());
    return true;
}

bool test_stage_transitions() {
    std::string test_dir = "/tmp/pipeline_state_test_" + std::to_string(getpid());
    mkdir(test_dir.c_str(), 0755);

    PipelineStateManager mgr(test_dir, 81);
    mgr.initialize();

    // Complete all 4 stages
    Stage stages[] = {Stage::Architect, Stage::Developer, Stage::Tester, Stage::Reviewer};
    std::string summaries[] = {
        "Architecture design completed",
        "Code implementation completed",
        "Testing completed",
        "Review completed"
    };

    for (int i = 0; i < 4; ++i) {
        std::vector<std::string> files;
        files.push_back("stage_" + std::to_string(i+1) + "_output.txt");
        
        if (!mgr.start_stage(stages[i], "sess_" + stage_to_string(stages[i]) + "_81")) {
            std::cout << "[FAIL] test_stage_transitions: start_stage failed at stage " << i+1 << std::endl;
            rmdir(test_dir.c_str());
            return false;
        }

        if (!mgr.complete_stage(stages[i], summaries[i], files)) {
            std::cout << "[FAIL] test_stage_transitions: complete_stage failed at stage " << i+1 << std::endl;
            rmdir(test_dir.c_str());
            return false;
        }

        if (i < 3) {
            if (!mgr.advance_to_next_stage()) {
                std::cout << "[FAIL] test_stage_transitions: advance failed at stage " << i+1 << std::endl;
                rmdir(test_dir.c_str());
                return false;
            }
        }
    }

    // Pipeline should be complete
    if (!mgr.is_pipeline_complete()) {
        std::cout << "[FAIL] test_stage_transitions: pipeline not complete after all stages" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    std::cout << "[PASS] test_stage_transitions" << std::endl;
    rmdir(test_dir.c_str());
    return true;
}

bool test_stage_fail() {
    std::string test_dir = "/tmp/pipeline_state_test_" + std::to_string(getpid());
    mkdir(test_dir.c_str(), 0755);

    PipelineStateManager mgr(test_dir, 81);
    mgr.initialize();

    // Fail Architect stage
    if (!mgr.fail_stage(Stage::Architect, "Architect failed due to invalid input")) {
        std::cout << "[FAIL] test_stage_fail: fail_stage failed" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    // Pipeline should be in failed state
    if (mgr.get_status() != StageStatus::Failed) {
        std::cout << "[FAIL] test_stage_fail: status not Failed" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    // A failed pipeline is complete (terminated)
    if (!mgr.is_pipeline_complete()) {
        std::cout << "[FAIL] test_stage_fail: pipeline should be complete (failed pipeline is terminated)" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    std::cout << "[PASS] test_stage_fail" << std::endl;
    rmdir(test_dir.c_str());
    return true;
}

bool test_stage_to_string() {
    if (stage_to_string(Stage::Architect) != "architect") {
        std::cout << "[FAIL] test_stage_to_string: Architect" << std::endl;
        return false;
    }
    if (stage_to_string(Stage::Developer) != "developer") {
        std::cout << "[FAIL] test_stage_to_string: Developer" << std::endl;
        return false;
    }
    if (stage_to_string(Stage::Tester) != "tester") {
        std::cout << "[FAIL] test_stage_to_string: Tester" << std::endl;
        return false;
    }
    if (stage_to_string(Stage::Reviewer) != "reviewer") {
        std::cout << "[FAIL] test_stage_to_string: Reviewer" << std::endl;
        return false;
    }

    std::cout << "[PASS] test_stage_to_string" << std::endl;
    return true;
}

int main() {
    int passed = 0;
    int total = 6;

    std::cout << "=== Issue #81: Pipeline State Tests ===" << std::endl;
    std::cout << std::endl;

    if (test_pipeline_state_init()) passed++;
    if (test_pipeline_state_manager_creation()) passed++;
    if (test_stage_start_and_complete()) passed++;
    if (test_stage_transitions()) passed++;
    if (test_stage_fail()) passed++;
    if (test_stage_to_string()) passed++;

    std::cout << std::endl;
    std::cout << "=== Result: " << passed << "/" << total << " passed ===" << std::endl;

    return (passed == total) ? 0 : 1;
}
