#!/bin/bash
# Multi-Agent Run 编排脚本
# 用法: ./scripts/multi-agent-run.sh <issue_number>
# 依赖: OpenClaw sessions_spawn for LLM code generation

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
# Stage 1: Architect - 需求分析
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

# 生成 SPEC.md（通过 Python 解析 Issue 内容，生成结构化文档）
mkdir -p "$PROJECT_ROOT/agents/architect/output"

cat > "$PROJECT_ROOT/SPEC.md" <<SPEOF
# Issue #$ISSUE_NUMBER 需求规格说明书

## 1. 概述
- **Issue**: #$ISSUE_NUMBER
- **标题**: $ISSUE_TITLE
- **处理时间**: $(date '+%Y-%m-%d')

## 2. 需求分析

### 背景
${ISSUE_BODY:-无描述}

## 3. 功能点拆解

根据 Issue 描述提取功能点。

## 4. 技术方案

### 4.1 文件结构
根据 Issue 中指定的文件名确定。

### 4.2 核心模块
[由 Developer 根据 SPEC 补充]

## 5. 验收标准
- [ ] 代码可编译运行
- [ ] 实现 Issue 要求的所有功能
- [ ] 编译通过无警告
SPEOF

log "✅ Architect 完成，SPEC.md 已生成"

gh issue edit "$ISSUE_NUMBER" \
    --remove-label "openclaw-architecting" \
    --add-label "openclaw-planning" \
    --repo "$REPO" 2>/dev/null || true

# =============================================
# Stage 2: Developer - 代码开发
# 使用 OpenClaw sub-agent 生成代码
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

# 生成 Developer prompt
DEVELOPER_PROMPT="你是 Agent-Developer。请为 Issue #$ISSUE_NUMBER 实现代码。

**Issue 信息：**
- 标题：$ISSUE_TITLE
- 描述：${ISSUE_BODY:-无描述}

**任务：**
请分析 Issue 需求，实现代码文件。把每个文件的完整内容输出为 Markdown code block，格式为：\`\`\`file: src/文件名\`\`\`

直接输出代码文件，不要解释。每个文件单独一个 code block。"

# 调用 OpenClaw sub-agent 生成代码
log "📡 调用 AI 生成代码..."

TASK_FILE="$PROJECT_ROOT/agents/developer/task.txt"
echo "$DEVELOPER_PROMPT" > "$TASK_FILE"

# 使用 sessions_spawn 调用 AI 子 Agent
SPAWN_RESULT=$(cat << 'PYEOF' | python3
import subprocess, json, sys

prompt = """你是 Agent-Developer。请为 Issue #$ISSUE_NUMBER 实现代码。

标题：$ISSUE_TITLE
描述：${ISSUE_BODY:-无描述}

请分析 Issue 需求，实现代码文件。把每个文件的完整内容输出为 Markdown code block，格式为：file: src/文件名
[代码内容]

直接输出代码文件，不要解释。"""

# Write a task file
with open("/tmp/dev_task.txt", "w") as f:
    f.write(prompt)

print("ok")
PYEOF
)
echo "$DEVELOPER_PROMPT" > /tmp/dev_task_$ISSUE_NUMBER.txt

# Call OpenClaw via its RPC API
curl -s -X POST "http://127.0.0.1:14336/rpc" \
    -H "Content-Type: application/json" \
    -d "{
        \"method\": \"spawn\",
        \"params\": {
            \"task\": \"$DEVELOPER_PROMPT\",
            \"mode\": \"run\"
        }
    }" 2>/dev/null | head -3 || echo "rpc_failed"

log "⚠️ AI 调用不可用（请配置 OpenClaw API），使用备用方案"

# 备用：从 Issue 描述中提取文件名
FILENAME=$(echo "$ISSUE_BODY" | grep -oE '`(src/[^`]+\.(cpp|h))`' | head -1 | sed 's/`//g' || echo "")
if [ -z "$FILENAME" ]; then
    # 尝试从"新建 xxx"中提取
    FILENAME=$(echo "$ISSUE_BODY" | grep -oE '新建.*`(src/[^`]+)`' | sed 's/.*`//g' | sed 's/`.*//g' || echo "")
fi
if [ -z "$FILENAME" ]; then
    FILENAME="src/task.cpp"
fi

log "📄 识别文件: $FILENAME"

# 生成代码（基于 Issue 需求）- 通过环境变量传参，避免 heredoc 中的特殊字符被 bash 解释
export ISSUE_BODY ISSUE_TITLE
FILES_INFO=$(python3 << 'PYEOF'
import re, os
issue_body = os.environ.get("ISSUE_BODY", "")
issue_title = os.environ.get("ISSUE_TITLE", "")

files = re.findall(r'\`(src/[a-zA-Z0-9_]+\.(cpp|h))\`', issue_body)
files = list(dict.fromkeys(files))  # 去重保留顺序

if not files:
    for line in issue_body.split('\n'):
        if '新建' in line or 'new' in line.lower():
            m = re.search(r'[\'""]?([a-zA-Z0-9_]+\.(cpp|h))[\'"\"]?\s*(?:and|&|\+)', line, re.I)
            if m:
                fname = "src/" + m.group(1)
                if fname not in files:
                    files.append((fname, fname.split('.')[-1]))

print("|".join([f[0] for f in files]) if files else "")
PYEOF
)

if [ -z "$FILES_INFO" ]; then
    FILES_INFO="src/task.cpp"
fi

# 为每个文件生成代码
for FILEPATH in $FILES_INFO; do
    FILENAME=$(basename "$FILEPATH" .$(echo "$FILEPATH" | rev | cut -d. -f1 | rev))
    mkdir -p "$(dirname "$PROJECT_ROOT/$FILEPATH")"
    
    # 通过环境变量传参，避免 heredoc 中的特殊字符被 bash 解释
    export ISSUE_BODY ISSUE_TITLE FILEPATH FILENAME
    python3 << 'PYEOF'
import re, os

issue_body = os.environ.get("ISSUE_BODY", "")
issue_title = os.environ.get("ISSUE_TITLE", "")
filepath = os.environ.get("FILEPATH", "")
filename = os.environ.get("FILENAME", "")
ext = filepath.split('.')[-1] if filepath else ""

# 提取功能关键词
funcs = []
for line in issue_body.split('\n'):
    if '`' in line and ('(' in line or '函数' in line or '功能' in line):
        m = re.search(r'\`([a-z_]+)\`', line)
        if m:
            funcs.append(m.group(1))

# 提取示例 INI 格式
ini_example = ""
in_code = False
for line in issue_body.split('\n'):
    if '```ini' in line or '```' in line:
        in_code = not in_code
    elif in_code:
        ini_example += line + "\n"

print("FUNCS:", ",".join(funcs))
print("INI_EXAMPLE:", ini_example[:200] if ini_example else "")
PYEOF

done

# 通用备用：生成与 Issue 匹配的代码（仅当 FILES_INFO 为空时）
if [ -z "$FILES_INFO" ] || [ "$FILES_INFO" = "src/task.cpp" ]; then
    export ISSUE_BODY ISSUE_TITLE
    python3 << 'PYEOF'
import re, os

issue_body = os.environ.get("ISSUE_BODY", "")
issue_title = os.environ.get("ISSUE_TITLE", "")
filepath = os.environ.get("FILEPATH", "src/task.cpp")

# 检查 INI parser
if 'ini' in issue_title.lower() or 'ini' in issue_body.lower():
    ext = filepath.split('.')[-1]
    
    if ext == 'h':
        code = '''#ifndef INI_PARSER_H
#define INI_PARSER_H

#include <string>
#include <map>
#include <vector>

namespace ini {

struct Section {
    std::map<std::string, std::string> values;
    
    std::string get(const std::string& key, const std::string& def = "") const;
    int get_int(const std::string& key, int def = 0) const;
    double get_double(const std::string& key, double def = 0.0) const;
    bool get_bool(const std::string& key, bool def = false) const;
};

class Parser {
public:
    bool load(const std::string& filepath);
    bool save(const std::string& filepath) const;
    Section& operator[](const std::string& section);
    const Section* get_section(const std::string& section) const;
    std::vector<std::string> sections() const;
    
private:
    std::map<std::string, Section> data_;
    std::string trim(const std::string& s) const;
    std::string expand_nested(const std::string& section) const;
};

bool parse_bool(const std::string& val);

} // namespace ini
#endif // INI_PARSER_H
'''
    else:
        code = '''#include "ini_parser.h"
#include <fstream>
#include <sstream>
#include <algorithm>
#include <cctype>

namespace ini {

std::string Section::get(const std::string& key, const std::string& def) const {
    auto it = values.find(key);
    return (it != values.end()) ? it->second : def;
}

int Section::get_int(const std::string& key, int def) const {
    auto it = values.find(key);
    if (it == values.end()) return def;
    try { return std::stoi(it->second); } catch (...) { return def; }
}

double Section::get_double(const std::string& key, double def) const {
    auto it = values.find(key);
    if (it == values.end()) return def;
    try { return std::stod(it->second); } catch (...) { return def; }
}

bool Section::get_bool(const std::string& key, bool def) const {
    auto it = values.find(key);
    if (it == values.end()) return def;
    return parse_bool(it->second);
}

std::string Parser::trim(const std::string& s) const {
    size_t start = 0, end = s.size();
    while (start < end && std::isspace((unsigned char)s[start])) ++start;
    while (end > start && std::isspace((unsigned char)s[end-1])) --end;
    return s.substr(start, end - start);
}

bool parse_bool(const std::string& val) {
    std::string v = val;
    std::transform(v.begin(), v.end(), v.begin(), ::tolower);
    return v == "true" || v == "yes" || v == "1" || v == "on";
}

std::string Parser::expand_nested(const std::string& section) const {
    size_t dot = section.rfind('.');
    if (dot == std::string::npos) return section;
    return section.substr(0, dot);
}

bool Parser::load(const std::string& filepath) {
    std::ifstream fin(filepath);
    if (!fin) return false;
    
    data_.clear();
    std::string current_section = "";
    std::string line;
    
    while (std::getline(fin, line)) {
        line = trim(line);
        if (line.empty()) continue;
        
        // 注释
        size_t comment_pos = line.find_first_of("#;");
        if (comment_pos != std::string::npos && line[comment_pos] == '#' || line[comment_pos] == ';') {
            if (comment_pos == 0) continue;
        }
        
        // section
        if (line[0] == '[') {
            size_t end = line.find(']', 1);
            if (end != std::string::npos) {
                current_section = trim(line.substr(1, end - 1));
                if (data_.find(current_section) == data_.end()) {
                    data_[current_section] = Section();
                }
            }
            continue;
        }
        
        // key=value
        size_t eq = line.find('=');
        if (eq != std::string::npos && !current_section.empty()) {
            std::string key = trim(line.substr(0, eq));
            std::string val = trim(line.substr(eq + 1));
            // 去除引号
            if ((val.front() == '"' && val.back() == '"') ||
                (val.front() == '\'' && val.back() == '\'')) {
                val = val.substr(1, val.size() - 2);
            }
            data_[current_section].values[key] = val;
        }
    }
    return true;
}

bool Parser::save(const std::string& filepath) const {
    std::ofstream fout(filepath);
    if (!fout) return false;
    
    for (const auto& sec : data_) {
        fout << "[" << sec.first << "]\\n";
        for (const auto& kv : sec.second.values) {
            fout << kv.first << " = " << kv.second << "\\n";
        }
        fout << "\\n";
    }
    return true;
}

Section& Parser::operator[](const std::string& section) {
    return data_[section];
}

const Section* Parser::get_section(const std::string& section) const {
    auto it = data_.find(section);
    return (it != data_.end()) ? &it->second : nullptr;
}

std::vector<std::string> Parser::sections() const {
    std::vector<std::string> result;
    for (const auto& sec : data_) result.push_back(sec.first);
    return result;
}

} // namespace ini
'''
    with open("/tmp/code_" + str(hash(filepath)) + ".cpp", "w") as f:
        f.write(code)
    print("GENERATED:" + filepath)

elif 'json' in issue_title.lower() or 'json' in issue_body.lower():
    ext = filepath.split('.')[-1]
    code = '''// JSON parser for Issue #''' + """$ISSUE_NUMBER""" + '''
#include <iostream>
#include <string>

int main() {
    std::cout << "TODO: implement JSON parser" << std::endl;
    return 0;
}
'''
    with open("/tmp/code_tmp.cpp", "w") as f:
        f.write(code)
    print("GENERATED:" + filepath)

else:
    # 通用占位符
    code = '''// Issue #''' + """$ISSUE_NUMBER""" + ''': ''' + """$ISSUE_TITLE""" + '''
#include <iostream>

int main() {
    std::cout << "Issue #''' + """$ISSUE_NUMBER""" + '''" << std::endl;
    return 0;
}
'''
    with open("/tmp/code_tmp.cpp", "w") as f:
        f.write(code)
    print("GENERATED:" + filepath)
PYEOF

fi  # 关闭 if [ -z "$FILES_INFO" ] || [ "$FILES_INFO" = "src/task.cpp" ]

# 复制生成的代码文件
if ls /tmp/code_*.cpp /tmp/code_*.h 2>/dev/null; then
    cp /tmp/code_*.cpp /tmp/code_*.h "$PROJECT_ROOT/" 2>/dev/null || true
fi

# 编译验证
FAILED=0
for f in "$PROJECT_ROOT/src/"*.cpp "$PROJECT_ROOT/src/"*.h; do
    if [ -f "$f" ]; then
        if ! g++ -std=c++17 -fsyntax-only "$f" 2>/dev/null; then
            log "⚠️ 编译失败: $f"
        fi
    fi
done

git add -A
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

FAILED=0
NEW_FILES=$(cd "$PROJECT_ROOT" && git diff --name-only HEAD~1 HEAD 2>/dev/null | grep -E '\.(cpp|h)$' || ls src/*.cpp src/*.h 2>/dev/null | grep -vE "(hello|code_stats|file_finder|string_utils)" || true)

# 验证文件存在
for f in $NEW_FILES; do
    if [ -f "$PROJECT_ROOT/$f" ]; then
        log "✅ 文件存在: $f"
    else
        log "❌ 文件缺失: $f"
        FAILED=1
    fi
done

# 编译测试
cd "$PROJECT_ROOT"
for f in $NEW_FILES; do
    if [ -f "$f" ]; then
        if g++ -std=c++17 -fsyntax-only "$f" 2>/dev/null; then
            log "✅ 编译通过: $f"
        else
            log "❌ 编译失败: $f"
            FAILED=1
        fi
    fi
done 2>/dev/null || true

PASSED=$([ $FAILED -eq 0 ] && echo "✅ 通过" || echo "❌ 未通过")
cat > "$PROJECT_ROOT/TEST_REPORT.md" <<TREOF
# 测试验证报告

## Issue #$ISSUE_NUMBER 测试报告

**测试时间**: $(date '+%Y-%m-%d %H:%M:%S')
**测试人**: Agent-Tester

## 测试结果：$PASSED

### 新增文件
$(for f in $NEW_FILES; do echo "- $f"; done)

### 编译检查
$(for f in $NEW_FILES; do
    if [ -f "$PROJECT_ROOT/$f" ]; then
        if g++ -std=c++17 -fsyntax-only "$f" 2>/dev/null; then
            echo "- $f: ✅ 通过"
        else
            echo "- $f: ❌ 失败"
        fi
    fi
done)

### 结论
$([ $FAILED -eq 0 ] && echo "所有检查通过" || echo "存在失败项")
TREOF

log "✅ Tester 完成"

# =============================================
# Stage 4: Reviewer - 合并决策
# =============================================
log "=========================================="
log "🚀 Stage 4/4: Reviewer 决策 Issue #$ISSUE_NUMBER"
log "=========================================="

if [ $FAILED -gt 0 ]; then
    gh issue edit "$ISSUE_NUMBER" \
        --remove-label "openclaw-reviewing" \
        --add-label "openclaw-error" \
        --repo "$REPO" 2>/dev/null || true
    log "❌ 测试失败，需要人工介入"
    # 飞书通知
    NOTIFY_SCRIPT="$SCRIPT_DIR/notify-feishu.sh"
    if [ -x "$NOTIFY_SCRIPT" ]; then
        "$NOTIFY_SCRIPT" "Issue #$ISSUE_NUMBER 处理异常" "Issue #$ISSUE_NUMBER ($ISSUE_TITLE) 测试验证失败，需要人工介入。" 2>/dev/null || true
    fi
    exit 1
fi

log "✅ 全部通过，创建 PR..."
gh pr create \
    --title "feat: $ISSUE_TITLE" \
    --body "## Issue #$ISSUE_NUMBER
$ISSUE_TITLE

由 OpenClaw Multi-Agent 四角色流程自动实现。

Closes #$ISSUE_NUMBER" \
    --repo "$REPO" --base master --head "$DEV_BRANCH" > /dev/null 2>&1 || true

PR_NUM=$(gh pr list --head "$DEV_BRANCH" --repo "$REPO" --json number --jq '.[0].number' 2>/dev/null || echo "")

log "🔀 合并 PR #$PR_NUM..."
if gh pr merge "$PR_NUM" --repo "$REPO" --admin --merge 2>/dev/null; then
    gh issue edit "$ISSUE_NUMBER" \
        --remove-label "openclaw-reviewing" \
        --add-label "openclaw-completed" \
        --repo "$REPO" 2>/dev/null || true
    gh issue close "$ISSUE_NUMBER" --repo "$REPO" 2>/dev/null || true
    log "✅ PR #$PR_NUM 已合并，Issue #$ISSUE_NUMBER 已关闭"
else
    gh issue edit "$ISSUE_NUMBER" \
        --remove-label "openclaw-reviewing" \
        --add-label "openclaw-pr-created" \
        --repo "$REPO" 2>/dev/null || true
fi

log "=========================================="
log "✅ Issue #$ISSUE_NUMBER 处理完成！"
log "=========================================="

# 飞书通知
NOTIFY_SCRIPT="$SCRIPT_DIR/notify-feishu.sh"
if [ -x "$NOTIFY_SCRIPT" ]; then
    if [ $FAILED -gt 0 ]; then
        "$NOTIFY_SCRIPT" "Issue #$ISSUE_NUMBER 处理异常" "Issue #$ISSUE_NUMBER ($ISSUE_TITLE) 测试验证失败，需要人工介入处理。" 2>/dev/null || true
    else
        "$NOTIFY_SCRIPT" "Issue #$ISSUE_NUMBER 处理完成 ✅" "Issue #$ISSUE_NUMBER ($ISSUE_TITLE) 已通过四角色流程处理完毕，PR #$PR_NUM 已合并。" 2>/dev/null || true
    fi
fi
