// Issue #90: Pipeline State Improvements
// Comprehensive test for pipeline_state module

#include <iostream>
#include <string>
#include <cassert>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <vector>
#include <fstream>
#include <sstream>
#include "pipeline_state.h"

using namespace pipeline;

static std::string test_dir_prefix = "/tmp/pipeline_state_test_";

bool test_pipeline_state_init() {
    std::string test_dir = test_dir_prefix + "init_" + std::to_string(getpid());
    mkdir(test_dir.c_str(), 0755);

    PipelineStateManager mgr(test_dir, 81);
    bool ok = mgr.initialize();
    if (ok) {
        std::cout << "[PASS] test_pipeline_state_init" << std::endl;
    } else {
        std::cout << "[FAIL] test_pipeline_state_init" << std::endl;
    }

    // Verify state file was created
    std::string pipeline_file = test_dir + "/pipeline.json";
    std::ifstream f(pipeline_file.c_str());
    if (!f.is_open()) {
        std::cout << "[FAIL] test_pipeline_state_init: pipeline.json not created" << std::endl;
        ok = false;
    }

    rmdir(test_dir.c_str());
    return ok;
}

bool test_pipeline_state_manager_creation() {
    std::string test_dir = test_dir_prefix + "create_" + std::to_string(getpid());
    mkdir(test_dir.c_str(), 0755);

    PipelineStateManager mgr(test_dir, 81);
    
    if (!mgr.initialize()) {
        std::cout << "[FAIL] test_pipeline_state_manager_creation: init failed" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

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

    if (mgr.get_issue_number() != 81) {
        std::cout << "[FAIL] test_pipeline_state_manager_creation: wrong issue number" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    std::cout << "[PASS] test_pipeline_state_manager_creation" << std::endl;
    rmdir(test_dir.c_str());
    return true;
}

bool test_stage_start_and_complete() {
    std::string test_dir = test_dir_prefix + "start_" + std::to_string(getpid());
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
    std::string test_dir = test_dir_prefix + "trans_" + std::to_string(getpid());
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

    if (!mgr.is_pipeline_succeeded()) {
        std::cout << "[FAIL] test_stage_transitions: pipeline not succeeded" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    std::cout << "[PASS] test_stage_transitions" << std::endl;
    rmdir(test_dir.c_str());
    return true;
}

bool test_stage_fail() {
    std::string test_dir = test_dir_prefix + "fail_" + std::to_string(getpid());
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
        std::cout << "[FAIL] test_stage_fail: pipeline should be complete (failed)" << std::endl;
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

bool test_load_and_save() {
    std::string test_dir = test_dir_prefix + "loadsave_" + std::to_string(getpid());
    mkdir(test_dir.c_str(), 0755);

    PipelineStateManager mgr1(test_dir, 99);
    mgr1.initialize();
    
    // Start and complete architect
    mgr1.start_stage(Stage::Architect, "sess_arch_99");
    std::vector<std::string> files;
    files.push_back("docs/DESIGN-99.md");
    mgr1.complete_stage(Stage::Architect, "Design completed", files);
    mgr1.advance_to_next_stage();
    
    // Start developer (leave it running)
    mgr1.start_stage(Stage::Developer, "sess_dev_99");
    
    // Save pipeline ID
    std::string saved_pipeline_id = mgr1.get_pipeline_id();

    // Create new manager and load
    PipelineStateManager mgr2(test_dir, 99);
    bool loaded = mgr2.load();
    if (!loaded) {
        std::cout << "[FAIL] test_load_and_save: load() returned false" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    // Verify loaded state
    if (mgr2.get_pipeline_id() != saved_pipeline_id) {
        std::cout << "[FAIL] test_load_and_save: pipeline_id mismatch" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    if (mgr2.get_current_stage() != Stage::Developer) {
        std::cout << "[FAIL] test_load_and_save: current_stage not Developer" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    if (mgr2.get_status() != StageStatus::Running) {
        std::cout << "[FAIL] test_load_and_save: status not Running" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    // Verify architect is completed
    if (!mgr2.is_stage_completed(Stage::Architect)) {
        std::cout << "[FAIL] test_load_and_save: Architect stage not marked completed" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    const std::vector<StageResult>& results = mgr2.get_stage_results();
    if (results.size() != 4) {
        std::cout << "[FAIL] test_load_and_save: expected 4 stage results, got " << results.size() << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    std::cout << "[PASS] test_load_and_save" << std::endl;
    rmdir(test_dir.c_str());
    return true;
}

bool test_retry_failed_stage() {
    std::string test_dir = test_dir_prefix + "retry_" + std::to_string(getpid());
    mkdir(test_dir.c_str(), 0755);

    PipelineStateManager mgr(test_dir, 77);
    mgr.initialize();
    
    // Fail the architect stage
    mgr.fail_stage(Stage::Architect, "Something went wrong");
    
    if (mgr.get_status() != StageStatus::Failed) {
        std::cout << "[FAIL] test_retry_failed_stage: status not Failed after fail_stage" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    // Retry the failed stage
    if (!mgr.retry_stage(Stage::Architect)) {
        std::cout << "[FAIL] test_retry_failed_stage: retry_stage failed" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    // Status should be back to Running
    if (mgr.get_status() != StageStatus::Running) {
        std::cout << "[FAIL] test_retry_failed_stage: status not Running after retry" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    // Stage should be pending again
    const StageResult* r = nullptr;
    for (const auto& sr : mgr.get_stage_results()) {
        if (sr.stage_number == 1) { r = &sr; break; }
    }
    if (!r || r->status != StageStatus::Pending) {
        std::cout << "[FAIL] test_retry_failed_stage: stage not Pending after retry" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    std::cout << "[PASS] test_retry_failed_stage" << std::endl;
    rmdir(test_dir.c_str());
    return true;
}

bool test_heartbeat() {
    std::string test_dir = test_dir_prefix + "heartbeat_" + std::to_string(getpid());
    mkdir(test_dir.c_str(), 0755);

    PipelineStateManager mgr(test_dir, 66);
    mgr.initialize();
    
    // Start architect
    mgr.start_stage(Stage::Architect, "sess_arch_66");
    
    time_t before = time(nullptr);
    
    // Send heartbeat
    if (!mgr.heartbeat_stage(Stage::Architect)) {
        std::cout << "[FAIL] test_heartbeat: heartbeat_stage failed" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }
    
    time_t after = time(nullptr);
    
    // Reload and check
    PipelineStateManager mgr2(test_dir, 66);
    mgr2.load();
    
    bool found = false;
    for (const auto& r : mgr2.get_stage_results()) {
        if (r.stage_number == 1 && r.last_heartbeat_at >= before && r.last_heartbeat_at <= after) {
            found = true;
            break;
        }
    }
    
    if (!found) {
        std::cout << "[FAIL] test_heartbeat: heartbeat not persisted" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    std::cout << "[PASS] test_heartbeat" << std::endl;
    rmdir(test_dir.c_str());
    return true;
}

bool test_stage_timeout() {
    std::string test_dir = test_dir_prefix + "timeout_" + std::to_string(getpid());
    mkdir(test_dir.c_str(), 0755);

    PipelineStateManager mgr(test_dir, 55);
    mgr.initialize();
    
    // Set a short timeout (1 second) for testing
    if (!mgr.set_stage_timeout(Stage::Architect, 1)) {
        std::cout << "[FAIL] test_stage_timeout: set_stage_timeout failed" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }
    
    // Start architect
    mgr.start_stage(Stage::Architect, "sess_arch_55");
    
    // Should not be timed out immediately
    if (mgr.is_stage_timed_out(Stage::Architect)) {
        std::cout << "[FAIL] test_stage_timeout: stage timed out immediately after start" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }
    
    // Wait 2 seconds
    sleep(2);
    
    // Should be timed out now
    if (!mgr.is_stage_timed_out(Stage::Architect)) {
        std::cout << "[FAIL] test_stage_timeout: stage did not time out after waiting" << std::endl;
        rmdir(test_dir.c_str());
        return false;
    }

    std::cout << "[PASS] test_stage_timeout" << std::endl;
    rmdir(test_dir.c_str());
    return true;
}

bool test_stage_helper_functions() {
    // Test stage_from_number
    if (stage_from_number(1) != Stage::Architect) {
        std::cout << "[FAIL] test_stage_helper_functions: stage_from_number(1)" << std::endl;
        return false;
    }
    if (stage_from_number(4) != Stage::Reviewer) {
        std::cout << "[FAIL] test_stage_helper_functions: stage_from_number(4)" << std::endl;
        return false;
    }
    if (stage_from_number(0) != Stage::None) {
        std::cout << "[FAIL] test_stage_helper_functions: stage_from_number(0)" << std::endl;
        return false;
    }
    if (stage_from_number(99) != Stage::None) {
        std::cout << "[FAIL] test_stage_helper_functions: stage_from_number(99)" << std::endl;
        return false;
    }
    
    // Test next_stage
    if (next_stage(Stage::Architect) != Stage::Developer) {
        std::cout << "[FAIL] test_stage_helper_functions: next_stage(Architect)" << std::endl;
        return false;
    }
    if (next_stage(Stage::Reviewer) != Stage::None) {
        std::cout << "[FAIL] test_stage_helper_functions: next_stage(Reviewer)" << std::endl;
        return false;
    }
    
    // Test status_to_string / string_to_status
    if (status_to_string(StageStatus::Running) != "running") {
        std::cout << "[FAIL] test_stage_helper_functions: status_to_string" << std::endl;
        return false;
    }
    if (string_to_status("failed") != StageStatus::Failed) {
        std::cout << "[FAIL] test_stage_helper_functions: string_to_status" << std::endl;
        return false;
    }
    if (string_to_status("invalid") != StageStatus::Pending) {
        std::cout << "[FAIL] test_stage_helper_functions: string_to_status invalid" << std::endl;
        return false;
    }
    
    // Test is_valid_stage
    if (!is_valid_stage(1) || !is_valid_stage(4)) {
        std::cout << "[FAIL] test_stage_helper_functions: is_valid_stage true case" << std::endl;
        return false;
    }
    if (is_valid_stage(0) || is_valid_stage(5)) {
        std::cout << "[FAIL] test_stage_helper_functions: is_valid_stage false case" << std::endl;
        return false;
    }

    std::cout << "[PASS] test_stage_helper_functions" << std::endl;
    return true;
}

bool test_display_names() {
    if (stage_to_display_name(Stage::Architect) != "Architect") {
        std::cout << "[FAIL] test_display_names: Architect" << std::endl;
        return false;
    }
    if (stage_to_display_name(Stage::Developer) != "Developer") {
        std::cout << "[FAIL] test_display_names: Developer" << std::endl;
        return false;
    }
    if (stage_to_display_name(Stage::Tester) != "Tester") {
        std::cout << "[FAIL] test_display_names: Tester" << std::endl;
        return false;
    }
    if (stage_to_display_name(Stage::Reviewer) != "Reviewer") {
        std::cout << "[FAIL] test_display_names: Reviewer" << std::endl;
        return false;
    }

    std::cout << "[PASS] test_display_names" << std::endl;
    return true;
}

bool test_code_names() {
    if (stage_to_code(Stage::Architect) != "ARCH") {
        std::cout << "[FAIL] test_code_names: ARCH" << std::endl;
        return false;
    }
    if (stage_to_code(Stage::Developer) != "DEV") {
        std::cout << "[FAIL] test_code_names: DEV" << std::endl;
        return false;
    }
    if (stage_to_code(Stage::Tester) != "TEST") {
        std::cout << "[FAIL] test_code_names: TEST" << std::endl;
        return false;
    }
    if (stage_to_code(Stage::Reviewer) != "REVIEW") {
        std::cout << "[FAIL] test_code_names: REVIEW" << std::endl;
        return false;
    }

    std::cout << "[PASS] test_code_names" << std::endl;
    return true;
}

int main() {
    int passed = 0;
    int total = 13;

    std::cout << "=== Issue #90: Pipeline State Tests ===" << std::endl;
    std::cout << "Testing improvements: JSON parsing, timeouts, heartbeats, retries" << std::endl;
    std::cout << std::endl;

    if (test_pipeline_state_init()) passed++;
    if (test_pipeline_state_manager_creation()) passed++;
    if (test_stage_start_and_complete()) passed++;
    if (test_stage_transitions()) passed++;
    if (test_stage_fail()) passed++;
    if (test_stage_to_string()) passed++;
    if (test_load_and_save()) passed++;
    if (test_retry_failed_stage()) passed++;
    if (test_heartbeat()) passed++;
    if (test_stage_timeout()) passed++;
    if (test_stage_helper_functions()) passed++;
    if (test_display_names()) passed++;
    if (test_code_names()) passed++;

    std::cout << std::endl;
    std::cout << "=== Result: " << passed << "/" << total << " passed ===" << std::endl;

    return (passed == total) ? 0 : 1;
}
