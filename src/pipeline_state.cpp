// Issue #93: test: 验证心跳自动续跑
// 提供 pipeline 状态文件的读写工具函数

#include "pipeline_state.h"
#include <fstream>
#include <sstream>
#include <cstdio>
#include <ctime>
#include <iomanip>
#include <sstream>

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
    
    // 尝试检测是否为 JSON 格式
    char first_char = fin.peek();
    if (first_char == '{') {
        // JSON 格式：读取整个文件并解析 stage 字段
        std::string content((std::istreambuf_iterator<char>(fin)),
                              std::istreambuf_iterator<char>());
        fin.close();
        
        // 简单解析: 查找 "stage": 数字
        // 先查找 "stage" 关键字（避免被 "issue_num" 等混淆）
        size_t stage_pos = content.find("\"stage\"");
        if (stage_pos != std::string::npos) {
            size_t colon_pos = content.find(':', stage_pos);
            if (colon_pos != std::string::npos) {
                size_t start = colon_pos + 1;
                // 跳过空白和可能的引号
                while (start < content.size() && (content[start] == ' ' || content[start] == '\t' || content[start] == '\n' || content[start] == '\r' || content[start] == '"')) start++;
                size_t end = start;
                while (end < content.size() && (isdigit(content[end]) || content[end] == '-')) end++;
                if (end > start) {
                    return std::stoi(content.substr(start, end - start));
                }
            }
        }
        // JSON 解析失败，尝试从内容中提取纯整数（旧格式兼容）
        // 查找第一个有效的整数（可能是 {N} 格式或其他简单格式）
        size_t i = 0;
        while (i < content.size() && !isdigit(content[i]) && content[i] != '-') i++;
        if (i < content.size()) {
            size_t j = i;
            while (j < content.size() && (isdigit(content[j]) || content[j] == '-')) j++;
            if (j > i) {
                try {
                    return std::stoi(content.substr(i, j - i));
                } catch (...) {
                    return -1;
                }
            }
        }
        return -1;
    }
    
    // 旧格式：纯整数
    int stage = -1;
    fin >> stage;
    fin.close();
    return stage;
}

bool write_stage(int issue_number, int stage, const std::string& state_dir) {
    return write_stage_with_error(issue_number, stage, "null", state_dir);
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

PipelineState read_state(int issue_number, const std::string& state_dir) {
    PipelineState state;
    state.issue = issue_number;
    state.stage = -1;
    state.updated_at = "";
    state.error = "null";
    
    std::ostringstream path;
    path << state_dir << "/" << issue_number << "_stage";
    
    std::ifstream fin(path.str());
    if (!fin.is_open()) {
        return state;
    }
    
    char first_char = fin.peek();
    if (first_char == '{') {
        // JSON 格式
        std::string content((std::istreambuf_iterator<char>(fin)),
                              std::istreambuf_iterator<char>());
        fin.close();
        
        // 解析各字段
        
        // issue
        size_t issue_pos = content.find("\"issue\"");
        if (issue_pos != std::string::npos) {
            size_t colon = content.find(':', issue_pos);
            if (colon != std::string::npos) {
                size_t start = colon + 1;
                while (start < content.size() && !isdigit(content[start])) start++;
                size_t end = start;
                while (end < content.size() && isdigit(content[end])) end++;
                if (end > start) state.issue = std::stoi(content.substr(start, end - start));
            }
        }
        
        // stage
        size_t stage_pos = content.find("\"stage\"");
        if (stage_pos != std::string::npos) {
            size_t colon = content.find(':', stage_pos);
            if (colon != std::string::npos) {
                size_t start = colon + 1;
                while (start < content.size() && !isdigit(content[start]) && content[start] != '-') start++;
                size_t end = start;
                while (end < content.size() && (isdigit(content[end]) || content[end] == '-')) end++;
                if (end > start) state.stage = std::stoi(content.substr(start, end - start));
            }
        }
        
        // updated_at
        size_t updated_pos = content.find("\"updated_at\"");
        if (updated_pos != std::string::npos) {
            size_t colon = content.find(':', updated_pos);
            size_t start_quote = content.find('"', colon);
            size_t end_quote = content.find('"', start_quote + 1);
            if (start_quote != std::string::npos && end_quote != std::string::npos) {
                state.updated_at = content.substr(start_quote + 1, end_quote - start_quote - 1);
            }
        }
        
        // error
        size_t error_pos = content.find("\"error\"");
        if (error_pos != std::string::npos) {
            size_t colon = content.find(':', error_pos);
            size_t start = colon + 1;
            while (start < content.size() && (start >= content.size() || content[start] == ' ' || content[start] == '\t' || content[start] == '\n' || content[start] == '\r')) start++;
            if (start < content.size() && content[start] == 'n' && start + 4 < content.size() && content.substr(start, 4) == "null") {
                state.error = "null";
            } else {
                size_t start_quote = content.find('"', start);
                size_t end_quote = content.find('"', start_quote + 1);
                if (start_quote != std::string::npos && end_quote != std::string::npos) {
                    state.error = content.substr(start_quote + 1, end_quote - start_quote - 1);
                }
            }
        }
    } else {
        // 旧格式：纯整数
        int stage = -1;
        fin >> stage;
        fin.close();
        state.stage = stage;
    }
    
    return state;
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
