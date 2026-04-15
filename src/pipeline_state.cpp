// Issue #90: Pipeline State Improvements
// Pipeline state management implementation - proper JSON parsing, timeouts, retries

#include "pipeline_state.h"

#include <iostream>
#include <fstream>
#include <sstream>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>
#include <string.h>

namespace pipeline {

namespace {

std::string int_to_string(int n) {
    std::ostringstream oss;
    oss << n;
    return oss.str();
}

// Escape a string for JSON (minimal: " and \ and control chars)
std::string escape_json(const std::string& s) {
    std::string result;
    result.reserve(s.size());
    for (size_t i = 0; i < s.size(); ++i) {
        char c = s[i];
        switch (c) {
            case '"':  result += "\\\""; break;
            case '\\': result += "\\\\"; break;
            case '\n': result += "\\n";  break;
            case '\r': result += "\\r";  break;
            case '\t': result += "\\t";  break;
            default:   result += c;     break;
        }
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

// Trim whitespace from both ends
std::string trim(const std::string& s) {
    size_t start = 0;
    while (start < s.size() && (s[start] == ' ' || s[start] == '\t' || 
                                 s[start] == '\n' || s[start] == '\r')) {
        ++start;
    }
    size_t end = s.size();
    while (end > start && (s[end-1] == ' ' || s[end-1] == '\t' ||
                           s[end-1] == '\n' || s[end-1] == '\r')) {
        --end;
    }
    return s.substr(start, end - start);
}

// Extract a string value from a JSON key-value pair
// Looks for "key": "value" or "key":value (non-string)
bool extract_json_field(const std::string& line, const std::string& key, std::string* out) {
    std::string pattern = "\"" + key + "\"";
    size_t pos = line.find(pattern);
    if (pos == std::string::npos) return false;
    
    size_t colon = line.find(':', pos);
    if (colon == std::string::npos) return false;
    
    size_t value_start = colon + 1;
    while (value_start < line.size() && (line[value_start] == ' ' || line[value_start] == '\t')) {
        ++value_start;
    }
    
    if (value_start >= line.size()) return false;
    
    if (line[value_start] == '"') {
        // Quoted string
        size_t value_end = value_start + 1;
        while (value_end < line.size()) {
            if (line[value_end] == '\\' && value_end + 1 < line.size()) {
                value_end += 2;
            } else if (line[value_end] == '"') {
                break;
            } else {
                ++value_end;
            }
        }
        *out = line.substr(value_start + 1, value_end - value_start - 1);
    } else {
        // Unquoted (null, boolean, number)
        size_t value_end = value_start;
        while (value_end < line.size() && line[value_end] != ',' && 
               line[value_end] != '}' && line[value_end] != '\n') {
            ++value_end;
        }
        *out = trim(line.substr(value_start, value_end - value_start));
        if (*out == "null") out->clear();
    }
    return true;
}

// Extract an integer value from a JSON field
bool extract_json_int(const std::string& line, const std::string& key, int* out) {
    std::string val;
    if (!extract_json_field(line, key, &val)) return false;
    if (val.empty() || val == "null") return false;
    if (val == "true") { *out = 1; return true; }
    if (val == "false") { *out = 0; return true; }
    try {
        *out = std::stoi(val);
        return true;
    } catch (...) {
        return false;
    }
}

// Read a JSON array of strings from a field
bool extract_json_string_array(const std::string& content, const std::string& key, 
                                std::vector<std::string>* out) {
    std::string pattern = "\"" + key + "\"";
    size_t pos = content.find(pattern);
    if (pos == std::string::npos) return false;
    
    size_t bracket = content.find('[', pos);
    if (bracket == std::string::npos) return false;
    
    size_t end_bracket = bracket + 1;
    int depth = 1;
    bool in_string = false;
    while (end_bracket < content.size() && depth > 0) {
        char c = content[end_bracket];
        if (c == '"' && (end_bracket == bracket + 1 || content[end_bracket-1] != '\\')) {
            in_string = !in_string;
        } else if (!in_string) {
            if (c == '[') ++depth;
            else if (c == ']') --depth;
        }
        ++end_bracket;
    }
    
    if (depth != 0) return false;
    std::string arr = content.substr(bracket + 1, end_bracket - bracket - 2);
    if (arr.empty()) return true;
    
    size_t item_start = 0;
    for (size_t i = 0; i <= arr.size(); ++i) {
        if (i == arr.size() || (arr[i] == ',' && !in_string)) {
            std::string item = trim(arr.substr(item_start, i - item_start));
            if (!item.empty() && item != ",") {
                if (item[0] == '"' && item[item.size()-1] == '"') {
                    item = item.substr(1, item.size() - 2);
                    // Unescape
                    std::string unescaped;
                    for (size_t j = 0; j < item.size(); ++j) {
                        if (item[j] == '\\' && j + 1 < item.size()) {
                            switch (item[j+1]) {
                                case '"': unescaped += '"'; break;
                                case '\\': unescaped += '\\'; break;
                                case 'n': unescaped += '\n'; break;
                                case 'r': unescaped += '\r'; break;
                                case 't': unescaped += '\t'; break;
                                default: unescaped += item[j+1]; break;
                            }
                            ++j;
                        } else {
                            unescaped += item[j];
                        }
                    }
                    out->push_back(unescaped);
                }
            }
            item_start = i + 1;
        }
        if (i < arr.size() && arr[i] == '"') in_string = !in_string;
    }
    return true;
}

}  // anonymous namespace

PipelineStateManager::PipelineStateManager(const std::string& state_dir, int issue_number)
    : state_dir_(state_dir)
    , issue_number_(issue_number)
    , pipeline_id_()
    , current_stage_(Stage::None)
    , status_(StageStatus::Pending) {
}

bool PipelineStateManager::initialize() {
    // Create state directory
    if (mkdir(state_dir_.c_str(), 0755) != 0 && errno != EEXIST) {
        std::cerr << "[ERROR] Failed to create state directory: " << state_dir_ 
                  << ": " << strerror(errno) << std::endl;
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
        switch (i) {
            case 1: r.stage_name = "architect"; break;
            case 2: r.stage_name = "developer"; break;
            case 3: r.stage_name = "tester"; break;
            case 4: r.stage_name = "reviewer"; break;
        }
        // Default timeouts: Architect=30min, Developer=60min, Tester=30min, Reviewer=15min
        r.timeout_seconds = (i == 2) ? 3600 : 1800;
        r.last_heartbeat_at = 0;
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

    // Parse pipeline.json
    std::string line;
    std::istringstream iss(content);
    std::string current_stage_name;
    int current_stage_num = 0;
    bool in_stages_object = false;  // Stop parsing top-level fields once inside stages
    
    // First pass: load pipeline-level fields
    while (std::getline(iss, line)) {
        std::string trimmed = trim(line);
        if (trimmed.empty()) continue;
        
        // Once we see "stages": {, stop capturing top-level fields
        if (trimmed.find("\"stages\"") != std::string::npos) {
            in_stages_object = true;
            continue;
        }
        if (in_stages_object) continue;
        
        std::string val;
        if (extract_json_field(trimmed, "pipeline_id", &val)) {
            pipeline_id_ = val;
        }
        if (extract_json_int(trimmed, "current_stage", &current_stage_num)) {
            current_stage_ = stage_from_number(current_stage_num);
        }
        if (extract_json_field(trimmed, "status", &val)) {
            status_ = string_to_status(val);
        }
    }

    // Load each stage file
    stage_results_.clear();
    for (int i = 1; i <= 4; ++i) {
        StageResult r;
        r.stage_number = i;
        switch (i) {
            case 1: r.stage_name = "architect"; break;
            case 2: r.stage_name = "developer"; break;
            case 3: r.stage_name = "tester"; break;
            case 4: r.stage_name = "reviewer"; break;
        }
        r.timeout_seconds = (i == 2) ? 3600 : 1800;
        r.last_heartbeat_at = 0;

        std::string stage_file_path = state_dir_ + "/stage-" + int_to_string(i) + ".json";
        std::string stage_content = read_json(stage_file_path);
        if (!stage_content.empty()) {
            std::istringstream siss(stage_content);
            std::string sline;
            while (std::getline(siss, sline)) {
                std::string stri = trim(sline);
                if (stri.empty()) continue;
                
                std::string fval;
                if (extract_json_field(stri, "status", &fval)) {
                    r.status = string_to_status(fval);
                }
                if (extract_json_field(stri, "session_id", &fval)) {
                    r.session_id = fval;
                }
                int iv = 0;
                if (extract_json_int(stri, "started_at", &iv)) {
                    r.started_at = static_cast<time_t>(iv);
                }
                if (extract_json_int(stri, "completed_at", &iv)) {
                    r.completed_at = static_cast<time_t>(iv);
                }
                if (extract_json_int(stri, "timeout_seconds", &iv)) {
                    r.timeout_seconds = iv;
                }
                if (extract_json_int(stri, "last_heartbeat_at", &iv)) {
                    r.last_heartbeat_at = static_cast<time_t>(iv);
                }
                if (extract_json_field(stri, "summary", &fval)) {
                    r.output_summary = fval;
                }
                if (extract_json_field(stri, "error", &fval)) {
                    r.error_message = fval;
                }
            }
            // Extract files_created array
            extract_json_string_array(stage_content, "files_created", &r.files_created);
        }
        stage_results_.push_back(r);
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
        stage_json << "  \"timeout_seconds\": " << r.timeout_seconds << ",\n";
        if (r.last_heartbeat_at > 0) {
            stage_json << "  \"last_heartbeat_at\": " << static_cast<int>(r.last_heartbeat_at) << ",\n";
        }
        stage_json << "  \"output\": {\n";
        stage_json << "    \"summary\": \"" << escape_json(r.output_summary) << "\",\n";
        stage_json << "    \"files_created\": " << files_to_json(r.files_created) << "\n";
        stage_json << "  },\n";
        stage_json << "  \"error\": " 
                   << (r.error_message.empty() ? "null" : "\"" + escape_json(r.error_message) + "\"") 
                   << "\n";
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
    r->last_heartbeat_at = now;
    r->error_message.clear();
    r->completed_at = 0;

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

bool PipelineStateManager::retry_stage(Stage stage) {
    StageResult* r = find_stage_result(stage);
    if (!r) return false;
    if (r->status != StageStatus::Failed) return false;  // Can only retry failed stages

    r->status = StageStatus::Pending;
    r->session_id.clear();
    r->started_at = 0;
    r->completed_at = 0;
    r->last_heartbeat_at = 0;
    r->output_summary.clear();
    r->files_created.clear();
    r->error_message.clear();

    // Also update pipeline status if this was the blocking failure
    if (status_ == StageStatus::Failed) {
        status_ = StageStatus::Running;
    }

    return save();
}

bool PipelineStateManager::heartbeat_stage(Stage stage) {
    time_t now = time(nullptr);

    StageResult* r = find_stage_result(stage);
    if (!r) return false;
    if (r->status != StageStatus::Running) return false;

    r->last_heartbeat_at = now;
    return save();
}

bool PipelineStateManager::is_stage_timed_out(Stage stage) const {
    const StageResult* r = find_stage_result(stage);
    if (!r) return false;
    if (r->status != StageStatus::Running) return false;
    if (r->timeout_seconds <= 0) return false;

    time_t now = time(nullptr);
    time_t elapsed = now - r->last_heartbeat_at;
    return elapsed > r->timeout_seconds;
}

bool PipelineStateManager::is_stage_completed(Stage stage) const {
    const StageResult* r = find_stage_result(stage);
    if (!r) return false;
    return r->status == StageStatus::Completed;
}

bool PipelineStateManager::is_pipeline_complete() const {
    return status_ == StageStatus::Completed || status_ == StageStatus::Failed;
}

bool PipelineStateManager::is_pipeline_succeeded() const {
    return status_ == StageStatus::Completed;
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

bool PipelineStateManager::set_stage_timeout(Stage stage, int timeout_seconds) {
    StageResult* r = find_stage_result(stage);
    if (!r) return false;
    r->timeout_seconds = timeout_seconds;
    return save();
}

int PipelineStateManager::get_stage_timeout(Stage stage) const {
    const StageResult* r = find_stage_result(stage);
    if (!r) return 0;
    return r->timeout_seconds;
}

}  // namespace pipeline
