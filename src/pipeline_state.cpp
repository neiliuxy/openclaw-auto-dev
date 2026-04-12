// Issue #93: test: 验证心跳自动续跑
// 提供 pipeline 状态文件的读写工具函数

#include "pipeline_state.h"
#include <fstream>
#include <sstream>
#include <cstdio>
#include <ctime>
#include <iomanip>

namespace pipeline {

static std::string get_current_timestamp() {
    std::time_t now = std::time(nullptr);
    std::ostringstream oss;
    oss << std::put_time(std::gmtime(&now), "%Y-%m-%dT%H:%M:%S+08:00");
    return oss.str();
}

static std::string quote_string(const std::string& s) {
    std::ostringstream oss;
    oss << "\"";
    for (char c : s) {
        if (c == '\\' || c == '"') oss << '\\';
        oss << c;
    }
    oss << "\"";
    return oss.str();
}

int read_stage(int issue_number, const std::string& state_dir) {
    std::ostringstream path;
    path << state_dir << "/" << issue_number << "_stage";
    
    std::ifstream fin(path.str());
    if (!fin.is_open()) {
        return -1;  // 文件不存在
    }
    
    // 读取整个文件内容
    std::string content((std::istreambuf_iterator<char>(fin)),
                          std::istreambuf_iterator<char>());
    fin.close();
    
    // 检测格式并解析
    char first_char = content[0];
    
    if (first_char == '{') {
        // JSON 格式：{"issue": 102, "stage": 1, ...} 或 {"issue_num": 97, "stage": 1}
        size_t stage_pos = content.find("\"stage\"");
        if (stage_pos != std::string::npos) {
            size_t colon_pos = content.find(':', stage_pos);
            if (colon_pos != std::string::npos) {
                size_t start = colon_pos + 1;
                while (start < content.size() && (content[start] == ' ' || content[start] == '\t' || content[start] == '\n' || content[start] == '\r' || content[start] == '"')) start++;
                size_t end = start;
                while (end < content.size() && (isdigit(content[end]) || content[end] == '-')) end++;
                if (end > start) {
                    return std::stoi(content.substr(start, end - start));
                }
            }
        }
        // JSON 但未找到 stage，尝试整个内容解析
        try {
            return std::stoi(content);
        } catch (...) {
            return -1;
        }
    }
    
    // 检查是否为 key=value 格式 (e.g., "issue_num=97\nstage=1")
    if (content.find("stage=") != std::string::npos) {
        size_t stage_pos = content.find("stage=");
        size_t start = stage_pos + 6;  // skip "stage="
        size_t end = start;
        while (end < content.size() && (isdigit(content[end]) || content[end] == '-')) end++;
        if (end > start) {
            return std::stoi(content.substr(start, end - start));
        }
    }
    
    // 纯整数格式
    try {
        size_t start = 0;
        while (start < content.size() && (content[start] == ' ' || content[start] == '\t' || content[start] == '\n' || content[start] == '\r')) start++;
        if (start < content.size() && (isdigit(content[start]) || content[start] == '-')) {
            size_t end = start;
            while (end < content.size() && (isdigit(content[end]) || content[end] == '-')) end++;
            return std::stoi(content.substr(start, end - start));
        }
    } catch (...) {
        return -1;
    }
    
    return -1;
}

bool write_stage_with_error(int issue_number, int stage, const std::string& error,
                            const std::string& state_dir) {
    std::ostringstream path;
    path << state_dir << "/" << issue_number << "_stage";
    
    std::ofstream fout(path.str());
    if (!fout.is_open()) {
        return false;
    }
    
    std::string timestamp = get_current_timestamp();
    std::string error_field = (error == "null" || error.empty()) ? "null" : quote_string(error);
    
    fout << "{\n";
    fout << "  \"issue\": " << issue_number << ",\n";
    fout << "  \"stage\": " << stage << ",\n";
    fout << "  \"updated_at\": " << quote_string(timestamp) << ",\n";
    fout << "  \"error\": " << error_field << "\n";
    fout << "}\n";
    fout.close();
    return true;
}

bool write_stage(int issue_number, int stage, const std::string& state_dir) {
    return write_stage_with_error(issue_number, stage, "null", state_dir);
}

std::string stage_to_description(int stage) {
    switch (stage) {
        case 0: return "NotStarted";
        case 1: return "ArchitectDone";
        case 2: return "DeveloperDone";
        case 3: return "TesterDone";
        case 4: return "PipelineDone";
        default: return "Unknown";
    }
}

}  // namespace pipeline
