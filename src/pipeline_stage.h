// Issue #90: Pipeline State Improvements
// Shared pipeline stage definitions — unifies Stage enum across all pipeline components

#ifndef PIPELINE_STAGE_H
#define PIPELINE_STAGE_H

#include <string>

namespace pipeline {

// Pipeline stage identifiers (used by both pipeline_state and pipeline_notifier)
enum class Stage {
    None = 0,
    Architect = 1,
    Developer = 2,
    Tester = 3,
    Reviewer = 4
};

// Stage status
enum class StageStatus {
    Pending = 0,
    Running = 1,
    Completed = 2,
    Failed = 3
};

// Convert stage to string (internal name)
inline std::string stage_to_string(Stage s) {
    switch (s) {
        case Stage::Architect:  return "architect";
        case Stage::Developer:  return "developer";
        case Stage::Tester:     return "tester";
        case Stage::Reviewer:   return "reviewer";
        default:                 return "unknown";
    }
}

// Convert stage to display name (human-readable)
inline std::string stage_to_display_name(Stage s) {
    switch (s) {
        case Stage::Architect:  return "Architect";
        case Stage::Developer:  return "Developer";
        case Stage::Tester:     return "Tester";
        case Stage::Reviewer:   return "Reviewer";
        default:                 return "Unknown";
    }
}

// Convert stage to short code (for labels/tags)
inline std::string stage_to_code(Stage s) {
    switch (s) {
        case Stage::Architect:  return "ARCH";
        case Stage::Developer:  return "DEV";
        case Stage::Tester:     return "TEST";
        case Stage::Reviewer:   return "REVIEW";
        default:                 return "???";
    }
}

// Convert stage number to Stage enum
inline Stage stage_from_number(int n) {
    switch (n) {
        case 1: return Stage::Architect;
        case 2: return Stage::Developer;
        case 3: return Stage::Tester;
        case 4: return Stage::Reviewer;
        default: return Stage::None;
    }
}

// Convert status to string
inline std::string status_to_string(StageStatus s) {
    switch (s) {
        case StageStatus::Pending:   return "pending";
        case StageStatus::Running:   return "running";
        case StageStatus::Completed: return "completed";
        case StageStatus::Failed:    return "failed";
        default:                      return "unknown";
    }
}

// Convert string to status
inline StageStatus string_to_status(const std::string& s) {
    if (s == "pending")   return StageStatus::Pending;
    if (s == "running")   return StageStatus::Running;
    if (s == "completed") return StageStatus::Completed;
    if (s == "failed")    return StageStatus::Failed;
    return StageStatus::Pending;
}

// Check if a stage number represents a valid pipeline stage
inline bool is_valid_stage(int n) {
    return n >= 1 && n <= 4;
}

// Get the next stage after the given one (returns None if at end)
inline Stage next_stage(Stage s) {
    int n = static_cast<int>(s);
    if (n >= 4) return Stage::None;
    return static_cast<Stage>(n + 1);
}

// Get total number of pipeline stages
inline constexpr int total_stages() { return 4; }

}  // namespace pipeline

#endif  // PIPELINE_STAGE_H
