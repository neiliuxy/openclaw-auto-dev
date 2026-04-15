// Issue #90: Pipeline State Improvements
// Pipeline state management - manages stage transitions and state persistence

#ifndef PIPELINE_STATE_H
#define PIPELINE_STATE_H

#include "pipeline_stage.h"

#include <string>
#include <vector>
#include <ctime>

namespace pipeline {

// Stage result entry (now uses timeout_seconds from pipeline_stage.h)
struct StageResult {
    int stage_number;
    std::string stage_name;
    StageStatus status;
    std::string session_id;
    time_t started_at;
    time_t completed_at;
    int timeout_seconds;       // NEW: timeout for this stage (0 = no timeout)
    time_t last_heartbeat_at;  // NEW: last activity heartbeat
    std::string output_summary;
    std::vector<std::string> files_created;
    std::string error_message;

    StageResult()
        : stage_number(0)
        , status(StageStatus::Pending)
        , started_at(0)
        , completed_at(0)
        , timeout_seconds(0)
        , last_heartbeat_at(0) {}
};

// Pipeline state
struct PipelineState {
    std::string pipeline_id;
    int issue_number;
    Stage current_stage;
    StageStatus status;
    time_t started_at;
    time_t completed_at;
    std::vector<StageResult> stage_results;

    PipelineState()
        : issue_number(0)
        , current_stage(Stage::None)
        , status(StageStatus::Pending)
        , started_at(0)
        , completed_at(0) {}
};

// PipelineStateManager: manages pipeline state persistence and transitions
class PipelineStateManager {
public:
    explicit PipelineStateManager(const std::string& state_dir, int issue_number);

    // Initialize a new pipeline
    bool initialize();

    // Load existing pipeline state (returns false if no state found)
    bool load();

    // Save current pipeline state
    bool save() const;

    // Transition to next stage
    bool advance_to_next_stage();

    // Mark current stage as running
    bool start_stage(Stage stage, const std::string& session_id);

    // Mark current stage as completed
    bool complete_stage(Stage stage, const std::string& summary,
                        const std::vector<std::string>& files);

    // Mark current stage as failed
    bool fail_stage(Stage stage, const std::string& error);

    // Retry a failed stage (resets to pending so it can be started again)
    bool retry_stage(Stage stage);

    // Send heartbeat for a running stage (updates last_heartbeat_at)
    bool heartbeat_stage(Stage stage);

    // Check if a running stage has timed out
    bool is_stage_timed_out(Stage stage) const;

    // Check if a specific stage is completed
    bool is_stage_completed(Stage stage) const;

    // Check if pipeline is complete (success or failure)
    bool is_pipeline_complete() const;

    // Check if pipeline succeeded (all stages completed)
    bool is_pipeline_succeeded() const;

    // Get current stage
    Stage get_current_stage() const { return current_stage_; }

    // Get pipeline status
    StageStatus get_status() const { return status_; }

    // Get all stage results
    const std::vector<StageResult>& get_stage_results() const { return stage_results_; }

    // Get state directory
    const std::string& get_state_dir() const { return state_dir_; }

    // Get pipeline ID
    const std::string& get_pipeline_id() const { return pipeline_id_; }

    // Get pipeline ID
    int get_issue_number() const { return issue_number_; }

    // Set stage timeout (must be called before start_stage)
    bool set_stage_timeout(Stage stage, int timeout_seconds);

    // Get stage timeout
    int get_stage_timeout(Stage stage) const;

private:
    std::string state_dir_;
    int issue_number_;
    std::string pipeline_id_;
    Stage current_stage_;
    StageStatus status_;
    std::vector<StageResult> stage_results_;

    std::string get_stage_file(Stage stage) const;
    std::string get_current_stage_file() const;
    bool write_json(const std::string& filename, const std::string& content) const;
    std::string read_json(const std::string& filename) const;
    StageResult* find_stage_result(Stage stage);
    const StageResult* find_stage_result(Stage stage) const;
};

}  // namespace pipeline

#endif  // PIPELINE_STATE_H
