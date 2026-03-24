// Issue #93: test: 验证心跳自动续跑
// Issue #102: fix state file format to support JSON
// 提供 pipeline 状态文件的读写工具函数

#include "pipeline_state.h"
#include <fstream>
#include <sstream>
#include <cstdio>
#include <cstring>

namespace pipeline {

int read_stage(int issue_number, const std::string& state_dir) {
    std::ostringstream path;
    path << state_dir << "/" << issue_number << "_stage";
    
    std::ifstream fin(path.str());
    if (!fin.is_open()) {
        return -1;  // 文件不存在
    }
    
    // 读取文件内容
    std::stringstream buffer;
    buffer << fin.rdbuf();
    std::string content = buffer.str();
    fin.close();
    
    // 尝试解析 JSON 格式 {"issue_num":102,"stage":3}
    if (content.find("{") != std::string::npos) {
        // JSON 格式解析
        int found_issue = -1;
        int found_stage = -1;
        
        // 查找 "stage": 后面跟着的数字
        size_t stage_pos = content.find("\"stage\"");
        if (stage_pos != std::string::npos) {
            size_t colon_pos = content.find(":", stage_pos);
            if (colon_pos != std::string::npos) {
                size_t num_start = colon_pos + 1;
                // 跳过空白
                while (num_start < content.size() && (content[num_start] == ' ' || content[num_start] == '\t')) {
                    num_start++;
                }
                size_t num_end = num_start;
                // 提取数字
                while (num_end < content.size() && (isdigit(content[num_end]) || content[num_end] == '-')) {
                    num_end++;
                }
                if (num_end > num_start) {
                    found_stage = std::atoi(content.substr(num_start, num_end - num_start).c_str());
                }
            }
        }
        
        // 查找 "issue_num": 后面跟着的数字
        size_t issue_pos = content.find("\"issue_num\"");
        if (issue_pos != std::string::npos) {
            size_t colon_pos = content.find(":", issue_pos);
            if (colon_pos != std::string::npos) {
                size_t num_start = colon_pos + 1;
                while (num_start < content.size() && (content[num_start] == ' ' || content[num_start] == '\t')) {
                    num_start++;
                }
                size_t num_end = num_start;
                while (num_end < content.size() && isdigit(content[num_end])) {
                    num_end++;
                }
                if (num_end > num_start) {
                    found_issue = std::atoi(content.substr(num_start, num_end - num_start).c_str());
                }
            }
        }
        
        // 验证 issue_number 匹配
        if (found_issue == issue_number && found_stage >= 0) {
            return found_stage;
        }
    }
    
    // 回退：尝试直接读取整数（旧格式兼容）
    std::ifstream fin2(path.str());
    if (!fin2.is_open()) {
        return -1;
    }
    int stage = -1;
    fin2 >> stage;
    fin2.close();
    return stage;
}

bool write_stage(int issue_number, int stage, const std::string& state_dir) {
    std::ostringstream path;
    path << state_dir << "/" << issue_number << "_stage";
    
    std::ofstream fout(path.str());
    if (!fout.is_open()) {
        return false;
    }
    
    // 写入 JSON 格式以匹配实际状态文件格式
    fout << "{\"issue_num\": " << issue_number << ", \"stage\": " << stage << "}\n";
    fout.close();
    return true;
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
