// Issue #93: test: 验证心跳自动续跑
// 提供 pipeline 状态文件的读写工具函数

#include "pipeline_state.h"
#include <fstream>
#include <sstream>
#include <cstdio>

namespace pipeline {

int read_stage(int issue_number, const std::string& state_dir) {
    std::ostringstream path;
    path << state_dir << "/" << issue_number << "_stage";
    
    std::ifstream fin(path.str());
    if (!fin.is_open()) {
        return -1;  // 文件不存在
    }
    
    int stage = -1;
    fin >> stage;
    fin.close();
    return stage;
}

bool write_stage(int issue_number, int stage, const std::string& state_dir) {
    std::ostringstream path;
    path << state_dir << "/" << issue_number << "_stage";
    
    std::ofstream fout(path.str());
    if (!fout.is_open()) {
        return false;
    }
    
    fout << stage << "\n";
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
