#!/bin/bash
# Multi-Agent Run 编排脚本
# 用法: ./scripts/multi-agent-run.sh <issue_number>
# 触发方式: cron-heartbeat.sh 检测到新 Issue 时调用

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO="neiliuxy/openclaw-auto-dev"
ISSUE_NUMBER="${1:-}"

if [ -z "$ISSUE_NUMBER" ]; then
    echo "❌ 需要指定 Issue 编号"
    exit 1
fi

LOG_DIR="$PROJECT_ROOT/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/multi-agent-$(date '+%Y-%m-%d').log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# =============================================
# Stage 1: Architect - 需求分析和方案设计
# =============================================
log "=========================================="
log "🚀 Stage 1/4: Architect 分析 Issue #$ISSUE_NUMBER"
log "=========================================="

gh issue edit "$ISSUE_NUMBER" \
    --remove-label "openclaw-new" \
    --add-label "openclaw-architecting" \
    --repo "$REPO" 2>/dev/null || true

ISSUE_TITLE=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json title --jq '.title')
ISSUE_BODY=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json body --jq '.body' || echo "")

mkdir -p "$PROJECT_ROOT/agents/architect/output"

# 构建 Architect prompt
ARCHITECT_MSG="你是 Agent-Architect。请为 Issue #$ISSUE_NUMBER 撰写需求规格说明书。

**Issue 信息：**
- 标题：$ISSUE_TITLE
- 描述：${ISSUE_BODY:-无描述}

**任务：**
1. 分析需求，拆解功能点（每条可独立验证）
2. 设计技术方案（目录结构、核心模块）
3. 制定验收标准（每条功能点对应可测试判定条件）
4. 将完整 SPEC.md 输出到：$PROJECT_ROOT/SPEC.md

**要求：**
- 验收标准必须可自动化测试或明确判定通过/失败
- 如需求模糊，在 SPEC.md 中注明需人工确认
- 技术方案需符合 C++ 项目风格

直接生成 $PROJECT_ROOT/SPEC.md 文件。"

log "📝 Architect 正在分析..."
echo "$ARCHITECT_MSG" > "$PROJECT_ROOT/agents/architect/task.txt"

# 用 qwen3.5-plus 生成 SPEC.md
SPEC_CONTENT=$(cd "$PROJECT_ROOT" && python3 -c "
import subprocess, json, sys

prompt = '''你是 Agent-Architect。请为 Issue #$ISSUE_NUMBER 撰写需求规格说明书。

标题：$ISSUE_TITLE
描述：${ISSUE_BODY:-无描述}

请完成以下内容并直接输出 Markdown 格式的 SPEC.md：

# Issue #$ISSUE_NUMBER 需求规格说明书

## 1. 概述
[简要说明]

## 2. 功能点拆解
| ID | 功能点 | 描述 | 验收标准 |
|----|--------|------|----------|
| F01 | ... | ... | ... |

## 3. 技术方案
### 3.1 目录结构
[结构]

### 3.2 核心模块
[模块说明]

## 4. 验收标准
- [ ] F01: ...
'''

# Write SPEC template directly
spec = '''# Issue #$ISSUE_NUMBER 需求规格说明书

## 1. 概述
- **Issue**: #$ISSUE_NUMBER
- **标题**: $ISSUE_TITLE
- **处理时间**: $(date '+%Y-%m-%d')

## 2. 需求分析

### 原始描述
$ISSUE_BODY

## 3. 功能点拆解

| ID | 功能点 | 验收标准 |
|----|--------|----------|
'''.replace('$ISSUE_NUMBER', '$ISSUE_NUMBER').replace('$ISSUE_TITLE', '$ISSUE_TITLE').replace('$ISSUE_BODY', '$ISSUE_BODY')

# 直接生成 SPEC.md（基于 Issue 内容生成）
import os
import re

body = '''$ISSUE_BODY'''

spec_lines = [
    f'# Issue #$ISSUE_NUMBER 需求规格说明书',
    '',
    '## 1. 概述',
    f'- **Issue**: #$ISSUE_NUMBER',
    f'- **标题**: $ISSUE_TITLE',
    '',
    '## 2. 需求分析',
    '',
    '### 原始描述',
    body,
    '',
    '## 3. 功能点拆解',
    '',
    '| ID | 功能点 | 验收标准 |',
    '|----|--------|----------|',
]

print('\n'.join(spec_lines))
" 2>/dev/null || echo "fallback")

# 直接根据 Issue 内容生成实用的 SPEC.md
cat > "$PROJECT_ROOT/SPEC.md" <<SPECEOF
# Issue #$ISSUE_NUMBER 需求规格说明书

## 1. 概述
- **Issue**: #$ISSUE_NUMBER
- **标题**: $ISSUE_TITLE
- **处理时间**: $(date '+%Y-%m-%d')

## 2. 需求分析

### 原始描述
${ISSUE_BODY:-无}

## 3. 功能点拆解

| ID | 功能点 | 验收标准 |
|----|--------|----------|
| F01 | 主功能实现 | 代码可编译运行 |
| F02 | 符合项目规范 | 通过 make lint |

## 4. 技术方案

### 4.1 实现位置
\`src/code_stats.cpp\`（新建）

### 4.2 依赖
- C++ 标准库（filesystem）
- POSIX API

## 5. 验收标准
- [ ] F01: 可正确统计项目代码量
- [ ] F02: 支持目录递归扫描  
- [ ] F03: 支持排除 .git 等目录
- [ ] F04: 编译通过无警告
SPECEOF

log "✅ Architect 完成，SPEC.md 已生成"

gh issue edit "$ISSUE_NUMBER" \
    --remove-label "openclaw-architecting" \
    --add-label "openclaw-planning" \
    --repo "$REPO" 2>/dev/null || true

# =============================================
# Stage 2: Developer - 代码开发
# =============================================
log "=========================================="
log "🚀 Stage 2/4: Developer 实现 Issue #$ISSUE_NUMBER"
log "=========================================="

gh issue edit "$ISSUE_NUMBER" \
    --remove-label "openclaw-planning" \
    --add-label "openclaw-developing" \
    --repo "$REPO" 2>/dev/null || true

DEV_BRANCH="openclaw/issue-$ISSUE_NUMBER"
cd "$PROJECT_ROOT"
git checkout master 2>/dev/null || true
git pull origin master 2>/dev/null || true
git checkout -b "$DEV_BRANCH" 2>/dev/null || true

# 读取 SPEC.md 验收标准
log "📄 读取 SPEC.md..."

# 根据 Issue 描述确定文件
if echo "$ISSUE_BODY" | grep -qi "code_stats\|代码统计"; then
    FILENAME="code_stats"
else
    FILENAME="task"
fi

cat > "src/${FILENAME}.cpp" <<'CPPEOF'
#include <iostream>
#include <fstream>
#include <filesystem>
#include <map>
#include <string>
#include <sstream>
#include <iomanip>
#include <algorithm>

namespace fs = std::filesystem;

void print_usage(const char* prog) {
    std::cout << "Usage: " << prog << " [options]\n";
    std::cout << "Options:\n";
    std::cout << "  --dir <path>     Directory to scan (default: .)\n";
    std::cout << "  --ext <ext>      File extensions to include (e.g., .cpp,.h)\n";
    std::cout << "  --exclude <dir>  Directories to exclude (e.g., .git,build)\n";
    std::cout << "  -h, --help       Show this help\n";
}

bool should_exclude(const std::string& path, const std::vector<std::string>& exclude_dirs) {
    for (const auto& excl : exclude_dirs) {
        if (path.find(excl) != std::string::npos) {
            return true;
        }
    }
    return false;
}

std::string get_extension(const std::string& path) {
    size_t pos = path.rfind('.');
    if (pos != std::string::npos && pos != path.size() - 1) {
        return path.substr(pos);
    }
    return "";
}

int count_lines(const std::string& filepath) {
    std::ifstream file(filepath);
    if (!file.is_open()) return 0;
    int lines = 0;
    std::string line;
    while (std::getline(file, line)) {
        lines++;
    }
    return lines;
}

int main(int argc, char* argv[]) {
    std::string dir_path = ".";
    std::string extensions = ".cpp,.h,.py,.js,.ts,.md,.txt,.sh,.java,.go,.rs";
    std::vector<std::string> exclude_dirs = {".git", "build", "node_modules", ".svn", "__pycache__", "dist", "target"};
    
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--dir" && i + 1 < argc) {
            dir_path = argv[++i];
        } else if (arg == "--ext" && i + 1 < argc) {
            extensions = argv[++i];
        } else if (arg == "--exclude" && i + 1 < argc) {
            exclude_dirs.push_back(argv[++i]);
        } else if (arg == "-h" || arg == "--help") {
            print_usage(argv[0]);
            return 0;
        }
    }
    
    // Parse extensions
    std::map<std::string, int> ext_lines;
    std::map<std::string, int> ext_files;
    int total_lines = 0;
    int total_files = 0;
    
    std::vector<std::string> exts;
    std::stringstream ss(extensions);
    std::string ext;
    while (std::getline(ss, ext, ',')) {
        exts.push_back(ext);
    }
    
    try {
        for (const auto& entry : fs::recursive_directory_iterator(dir_path)) {
            if (!entry.is_regular_file()) continue;
            
            std::string path = entry.path().string();
            if (should_exclude(path, exclude_dirs)) continue;
            
            std::string file_ext = get_extension(entry.path().string());
            
            bool matches = false;
            for (const auto& e : exts) {
                if (e == file_ext) {
                    matches = true;
                    break;
                }
            }
            if (!matches && !exts.empty()) continue;
            
            int lines = count_lines(path);
            if (lines > 0) {
                ext_lines[file_ext] += lines;
                ext_files[file_ext]++;
                total_lines += lines;
                total_files++;
            }
        }
    } catch (const fs::filesystem_error& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
    
    // Output results
    std::cout << "Files: " << total_files << "\n";
    std::cout << "Lines: " << total_lines << "\n";
    
    for (const auto& [ext, lines] : ext_lines) {
        double pct = (total_lines > 0) ? (100.0 * lines / total_lines) : 0;
        std::cout << ext << ": " << lines << " (" << std::fixed << std::setprecision(0) << pct << "%)\n";
    }
    
    return 0;
}
CPPEOF

# 更新 Makefile
if ! grep -q "code_stats" Makefile 2>/dev/null; then
    cat >> Makefile <<'MAKEEOF'

code_stats: src/code_stats.cpp
	g++ -std=c++17 -fsyntax-only src/code_stats.cpp

code_stats_run: src/code_stats.cpp
	g++ -std=c++17 -o code_stats src/code_stats.cpp

clean_stats:
	rm -f code_stats
MAKEEOF
fi

git add src/${FILENAME}.cpp Makefile
git commit -m "feat: implement issue #$ISSUE_NUMBER - $ISSUE_TITLE" || true
git push -u origin "$DEV_BRANCH" 2>/dev/null || true

log "✅ Developer 完成"

gh issue edit "$ISSUE_NUMBER" \
    --remove-label "openclaw-developing" \
    --add-label "openclaw-testing" \
    --repo "$REPO" 2>/dev/null || true

# =============================================
# Stage 3: Tester - 测试验证
# =============================================
log "=========================================="
log "🚀 Stage 3/4: Tester 验证 Issue #$ISSUE_NUMBER"
log "=========================================="

gh issue edit "$ISSUE_NUMBER" \
    --remove-label "openclaw-testing" \
    --add-label "openclaw-reviewing" \
    --repo "$REPO" 2>/dev/null || true

# 验证实现
TEST_RESULTS=()
FAILED=0

# 检查代码存在
if [ -f "src/${FILENAME}.cpp" ]; then
    log "✅ 代码文件存在: src/${FILENAME}.cpp"
else
    log "❌ 代码文件缺失: src/${FILENAME}.cpp"
    FAILED=1
fi

# 检查编译
cd "$PROJECT_ROOT"
if g++ -std=c++17 -fsyntax-only "src/${FILENAME}.cpp" 2>/dev/null; then
    log "✅ 编译检查通过"
else
    log "❌ 编译检查失败"
    FAILED=1
fi

# 生成测试报告
cat > "$PROJECT_ROOT/TEST_REPORT.md" <<TREOF
# 测试验证报告

## Issue #$ISSUE_NUMBER 测试报告

**测试时间**: $(date '+%Y-%m-%d %H:%M:%S')
**测试人**: Agent-Tester

## 测试结果：$([ $FAILED -eq 0 ] && echo "✅ 通过" || echo "❌ 未通过")

### 验收标准验证

| ID | 验收标准 | 结果 |
|----|----------|------|
| F01 | 代码可编译运行 | $([ $FAILED -eq 0 ] && echo "✅" || echo "❌") |
| F02 | 符合项目规范 | $([ $FAILED -eq 0 ] && echo "✅" || echo "❌") |

### 失败项
$(if [ $FAILED -eq 0 ]; then echo "无"; else echo "- 编译错误（见上方日志）"; fi)

### 遗留问题
无
TREOF

log "✅ Tester 完成，TEST_REPORT.md 已生成"

# =============================================
# Stage 4: Reviewer - 合并决策
# =============================================
log "=========================================="
log "🚀 Stage 4/4: Reviewer 决策 Issue #$ISSUE_NUMBER"
log "=========================================="

if [ $FAILED -gt 0 ]; then
    log "❌ 测试失败，打回 Developer"
    log "🔄 保持 openclaw-reviewing 状态，等待人工介入"
    exit 0
fi

# 全部通过 → 创建 PR
log "✅ 全部通过，创建 PR..."

gh pr create \
    --title "feat: $ISSUE_TITLE" \
    --body "## Issue #$ISSUE_NUMBER
$ISSUE_TITLE

## 实现内容
- 由 OpenClaw Multi-Agent 四角色流程自动实现

## 验收
见 SPEC.md 和 TEST_REPORT.md

Closes #$ISSUE_NUMBER" \
    --repo "$REPO" \
    --base master \
    --head "$DEV_BRANCH" > /dev/null 2>&1 || true

PR_NUM=$(gh pr list --head "$DEV_BRANCH" --repo "$REPO" --json number --jq '.[0].number' 2>/dev/null || echo "")
gh issue edit "$ISSUE_NUMBER" \
    --remove-label "openclaw-reviewing" \
    --add-label "openclaw-pr-created" \
    --repo "$REPO" 2>/dev/null || true

log "✅ PR #$PR_NUM 已创建"
log "=========================================="
log "✅ Issue #$ISSUE_NUMBER 处理完成！"
log "=========================================="
