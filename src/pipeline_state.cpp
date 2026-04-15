// Issue #81: 4-session pipeline verification
// Pipeline state management implementation

#include "pipeline_state.h"

#include <iostream>
#include <fstream>
#include <sstream>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <time.h>

namespace pipeline {

namespace {

std::string int_to_string(int n) {
    std::ostringstream oss;
    oss << n;
    return oss.str();
}

std::string status_to_string(StageStatus s) {
    switch (s) {
        case StageStatus::Pending:   return "pending";
        case StageStatus::Running:   return "running";
        case StageStatus::Completed: return "completed";
        case StageStatus::Failed:    return "failed";
        default:                      return "unknown";
    }
}

StageStatus string_to_status(const std::string& s) {
    if (s == "pending")   return StageStatus::Pending;
    if (s == "running")   return StageStatus::Running;
    if (s == "completed") return StageStatus::Completed;
    if (s == "failed")    return StageStatus::Failed;
    return StageStatus::Pending;
}

std::string escape_json(const std::string& s) {
    std::string result;
    for (size_t i = 0; i < s.size(); ++i) {
        char c = s[i];
        if (c == '"') result += "\\\"";
        else if (c == '\\') result += "\\\\";
        else if (c == '\n') result += "\\n";
        else if (c == '\r') result += "\\r";
        else if (c == '\t') result += "\\t";
        else result += c;
    }
    return result;
}

std::string files_to_json(const std::vector<std::string>& files) {
    std::ostringstream oss;
    oss << "[";
    for (size_t i = 0; i < files.size(); ++i) {
        if (i > 0) oss << ",";
        oss << "\"" << escape_json(files[i]) << "\"";
    }
    oss << "]";
    return oss.str();
}

}  // anonymous namespace

PipelineStateManager::PipelineStateManager(const std::string& state_dir, int issue_number)
    : state_dir_(state_dir)
    , issue_number_(issue_number)
    , current_stage_(Stage::None)
    , status_(StageStatus::Pending) {
}

bool PipelineStateManager::initialize() {
    // Create state directory
    if (mkdir(state_dir_.c_str(), 0755) != 0 && errno != EEXIST) {
        std::cerr << "[ERROR] Failed to create state directory: " << state_dir_ << std::endl;
        return false;
    }

    // Generate pipeline ID
    time_t now = time(nullptr);
    pipeline_id_ = "pipeline_" + int_to_string(static_cast<int>(now));
    current_stage_ = Stage::Architect;
    status_ = StageStatus::Running;

    stage_results_.clear();

    // Initialize 4 stage slots
    for (int i = 1; i <= 4; ++i) {
        StageResult r;
        r.stage_number = i;
        r.status = (i == 1) ? StageStatus::Pending : StageStatus::Pending;
        switch (i) {
            case 1: r.stage_name = "architect"; break;
            case 2: r.stage_name = "developer"; break;
            case 3: r.stage_name = "tester"; break;
            case 4: r.stage_name = "reviewer"; break;
        }
        stage_results_.push_back(r);
    }

    return save();
}

bool PipelineStateManager::load() {
    std::string pipeline_file = state_dir_ + "/pipeline.json";
    std::string content = read_json(pipeline_file);
    if (content.empty()) {
        return false;
    }

    // Simple parsing - in production use proper JSON library
    // For now, we just verify the file exists and is readable
    std::ifstream f(pipeline_file.c_str());
    if (!f.is_open()) {
        return false;
    }

    // Load current_stage file
    std::string stage_file = state_dir_ + "/current_stage";
    std::ifstream sf(stage_file.c_str());
    if (sf.is_open()) {
        int stage_num = 0;
        sf >> stage_num;
        current_stage_ = static_cast<Stage>(stage_num);
    }

    // Load each stage file
    for (int i = 1; i <= 4; ++i) {
        std::string stage_file_path = state_dir_ + "/stage-" + int_to_string(i) + ".json";
        std::ifstream stf(stage_file_path.c_str());
        if (stf.is_open()) {
            StageResult r;
            r.stage_number = i;
            switch (i) {
                case 1: r.stage_name = "architect"; break;
                case 2: r.stage_name = "developer"; break;
                case 3: r.stage_name = "tester"; break;
                case 4: r.stage_name = "reviewer"; break;
            }
            // Read status from file
            std::string line;
            while (std::getline(stf, line)) {
                if (line.find("\"status\"") != std::string::npos) {
                    size_t pos = line.find(":\"");
                    if (pos != std::string::npos) {
                        std::string status_val = line.substr(pos + 2);
                        size_t end = status_val.find("\"");
                        if (end != std::string::npos) {
                            status_val = status_val.substr(0, end);
                        }
                        r.status = string_to_status(status_val);
                    }
                }
                if (line.find("\"session_id\"") != std::string::npos) {
                    size_t pos = line.find(":\"");
                    if (pos != std::string::npos) {
                        r.session_id = line.substr(pos + 2);
                        size_t end = r.session_id.find("\"");
                        if (end != std::string::npos) {
                            r.session_id = r.session_id.substr(0, end);
                        }
                    }
                }
            }
            // Update existing or add new
            bool found = false;
            for (size_t j = 0; j < stage_results_.size(); ++j) {
                if (stage_results_[j].stage_number == i) {
                    stage_results_[j] = r;
                    found = true;
                    break;
                }
            }
            if (!found) {
                stage_results_.push_back(r);
            }
        }
    }

    return true;
}

bool PipelineStateManager::save() const {
    time_t now = time(nullptr);

    // Write pipeline.json
    std::ostringstream pipeline_json;
    pipeline_json << "{\n";
    pipeline_json << "  \"pipeline_id\": \"" << escape_json(pipeline_id_) << "\",\n";
    pipeline_json << "  \"issue\": \"#" << issue_number_ << "\",\n";
    pipeline_json << "  \"started_at\": " << static_cast<int>(now) << ",\n";
    pipeline_json << "  \"current_stage\": " << static_cast<int>(current_stage_) << ",\n";
    pipeline_json << "  \"status\": \"" << status_to_string(status_) << "\",\n";
    pipeline_json << "  \"stages\": {\n";
    for (size_t i = 0; i < stage_results_.size(); ++i) {
        const StageResult& r = stage_results_[i];
        pipeline_json << "    \"" << r.stage_name << "\": {\n";
        pipeline_json << "      \"status\": \"" << status_to_string(r.status) << "\",\n";
        pipeline_json << "      \"session_id\": \"" << escape_json(r.session_id) << "\"";
        if (r.completed_at > 0) {
            pipeline_json << ",\n      \"completed_at\": " << static_cast<int>(r.completed_at);
        }
        pipeline_json << "\n    }";
        if (i < stage_results_.size() - 1) pipeline_json << ",";
        pipeline_json << "\n";
    }
    pipeline_json << "  }\n";
    pipeline_json << "}\n";

    if (!write_json(state_dir_ + "/pipeline.json", pipeline_json.str())) {
        return false;
    }

    // Write current_stage file
    {
        std::ofstream f((state_dir_ + "/current_stage").c_str());
        if (!f.is_open()) return false;
        f << static_cast<int>(current_stage_);
    }

    // Write individual stage files
    for (size_t i = 0; i < stage_results_.size(); ++i) {
        const StageResult& r = stage_results_[i];
        std::string stage_file = state_dir_ + "/stage-" + int_to_string(r.stage_number) + ".json";

        std::ostringstream stage_json;
        stage_json << "{\n";
        stage_json << "  \"stage\": " << r.stage_number << ",\n";
        stage_json << "  \"name\": \"" << escape_json(r.stage_name) << "\",\n";
        stage_json << "  \"status\": \"" << status_to_string(r.status) << "\",\n";
        stage_json << "  \"session_id\": \"" << escape_json(r.session_id) << "\",\n";
        if (r.started_at > 0) {
            stage_json << "  \"started_at\": " << static_cast<int>(r.started_at) << ",\n";
        }
        if (r.completed_at > 0) {
            stage_json << "  \"completed_at\": " << static_cast<int>(r.completed_at) << ",\n";
        }
        stage_json << "  \"output\": {\n";
        stage_json << "    \"summary\": \"" << escape_json(r.output_summary) << "\",\n";
        stage_json << "    \"files_created\": " << files_to_json(r.files_created) << "\n";
        stage_json << "  },\n";
        stage_json << "  \"error\": " << (r.error_message.empty() ? "null" : "\"" + escape_json(r.error_message) + "\"") << "\n";
        stage_json << "}\n";

        if (!write_json(stage_file, stage_json.str())) {
            return false;
        }
    }

    return true;
}

bool PipelineStateManager::advance_to_next_stage() {
    int current = static_cast<int>(current_stage_);
    if (current >= 4) {
        status_ = StageStatus::Completed;
        return save();
    }
    current_stage_ = static_cast<Stage>(current + 1);
    return save();
}

bool PipelineStateManager::start_stage(Stage stage, const std::string& session_id) {
    time_t now = time(nullptr);

    StageResult* r = find_stage_result(stage);
    if (!r) return false;

    r->status = StageStatus::Running;
    r->session_id = session_id;
    r->started_at = now;

    return save();
}

bool PipelineStateManager::complete_stage(Stage stage, const std::string& summary,
                                           const std::vector<std::string>& files) {
    time_t now = time(nullptr);

    StageResult* r = find_stage_result(stage);
    if (!r) return false;

    r->status = StageStatus::Completed;
    r->completed_at = now;
    r->output_summary = summary;
    r->files_created = files;

    // If this was the final stage (Reviewer), mark pipeline as complete
    if (stage == Stage::Reviewer) {
        status_ = StageStatus::Completed;
    }

    return save();
}

bool PipelineStateManager::fail_stage(Stage stage, const std::string& error) {
    time_t now = time(nullptr);

    StageResult* r = find_stage_result(stage);
    if (!r) return false;

    r->status = StageStatus::Failed;
    r->completed_at = now;
    r->error_message = error;

    status_ = StageStatus::Failed;

    return save();
}

bool PipelineStateManager::is_stage_completed(Stage stage) const {
    const StageResult* r = find_stage_result(stage);
    if (!r) return false;
    return r->status == StageStatus::Completed;
}

bool PipelineStateManager::is_pipeline_complete() const {
    return status_ == StageStatus::Completed || status_ == StageStatus::Failed;
}

std::string PipelineStateManager::get_stage_file(Stage stage) const {
    return state_dir_ + "/stage-" + int_to_string(static_cast<int>(stage)) + ".json";
}

std::string PipelineStateManager::get_current_stage_file() const {
    return state_dir_ + "/current_stage";
}

bool PipelineStateManager::write_json(const std::string& filename, const std::string& content) const {
    std::ofstream f(filename.c_str());
    if (!f.is_open()) {
        std::cerr << "[ERROR] Cannot write file: " << filename << std::endl;
        return false;
    }
    f << content;
    return true;
}

std::string PipelineStateManager::read_json(const std::string& filename) const {
    std::ifstream f(filename.c_str());
    if (!f.is_open()) {
        return "";
    }
    std::ostringstream oss;
    oss << f.rdbuf();
    return oss.str();
}

StageResult* PipelineStateManager::find_stage_result(Stage stage) {
    int num = static_cast<int>(stage);
    for (size_t i = 0; i < stage_results_.size(); ++i) {
        if (stage_results_[i].stage_number == num) {
            return &stage_results_[i];
        }
    }
    return nullptr;
}

const StageResult* PipelineStateManager::find_stage_result(Stage stage) const {
    int num = static_cast<int>(stage);
    for (size_t i = 0; i < stage_results_.size(); ++i) {
        if (stage_results_[i].stage_number == num) {
            return &stage_results_[i];
        }
    }
    return nullptr;
}

}  // namespace pipeline
