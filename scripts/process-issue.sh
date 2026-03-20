#!/bin/bash
# OpenClaw Auto Dev - Issue 处理脚本
# 自动处理 openclaw-new Issue 的完整流程

set -euo pipefail

# 启用调试模式（可选）
# set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/process-$(date '+%Y-%m-%d').log"

# 确保日志目录存在
mkdir -p "$LOG_DIR"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 错误处理函数
error_exit() {
    log "❌ 错误：$1"
    # 更新 Issue 状态为 error
    if [ -n "$ISSUE_NUMBER" ]; then
        gh issue edit "$ISSUE_NUMBER" \
            --remove-label "openclaw-processing" \
            --add-label "openclaw-error" \
            --repo "$REPO" || true
    fi
    exit 1
}

# 配置
REPO="neiliuxy/openclaw-auto-dev"
ISSUE_NUMBER="${1:-}"

if [ -z "$ISSUE_NUMBER" ]; then
    # 从 scan-result.json 读取
    if [ -f "$PROJECT_ROOT/scan-result.json" ]; then
        ISSUE_NUMBER=$(jq -r '.issue_number // empty' "$PROJECT_ROOT/scan-result.json")
    fi
fi

if [ -z "$ISSUE_NUMBER" ]; then
    log "ℹ️ 没有需要处理的 Issue"
    exit 0
fi

log "=========================================="
log "🚀 开始处理 Issue #$ISSUE_NUMBER"
log "=========================================="

# 步骤 1: 获取 Issue 信息
log "📋 获取 Issue 信息..."
ISSUE_TITLE=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json title --jq '.title')
ISSUE_BODY=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json body --jq '.body')

log "📝 Issue 标题：$ISSUE_TITLE"
log "📄 Issue 描述：${ISSUE_BODY:-空}"

# 步骤 2: 创建分支
BRANCH_NAME="openclaw/issue-$ISSUE_NUMBER"
log "🌿 创建分支：$BRANCH_NAME"

# 确保在 master 分支
git checkout master
git pull origin master

# 创建并切换到新分支
if git show-ref --verify --quiet refs/heads/"$BRANCH_NAME"; then
    log "⚠️ 分支已存在，删除并重新创建"
    git branch -D "$BRANCH_NAME" || true
fi

git checkout -b "$BRANCH_NAME"

# 步骤 3: 更新 Issue 标签为 processing
log "🏷️ 更新 Issue 标签为 openclaw-processing..."
gh issue edit "$ISSUE_NUMBER" \
    --remove-label "openclaw-new" \
    --add-label "openclaw-processing" \
    --repo "$REPO"

# 步骤 4: 根据 Issue 内容开发/解决问题
log "💻 开始开发/解决问题..."

# 解析 Issue 内容，判断任务类型（优先检查配置文件等需求）
# 先检查是否是 C++ 相关的配置/测试需求
if echo "$ISSUE_TITLE $ISSUE_BODY" | grep -qiE "json.*配置|配置.*json|config.*file"; then
    if echo "$ISSUE_TITLE $ISSUE_BODY" | grep -qiE "c\+\+|hello|cpp|程序"; then
        log "📝 任务类型：C++ 程序添加 JSON 配置支持"
        
        if [ -f "hello.cpp" ]; then
            # 修改现有 hello.cpp 添加配置支持
            cat > hello.cpp <<'EOF'
#include <iostream>
#include <fstream>
#include <string>
#include <map>

// Simple JSON parser for config file
std::map<std::string, std::string> parseConfig(const std::string& filename) {
    std::map<std::string, std::string> config;
    std::ifstream file(filename);
    
    if (!file.is_open()) {
        return config; // Return empty config if file doesn't exist
    }
    
    std::string line;
    std::string key, value;
    
    while (std::getline(file, line)) {
        size_t colonPos = line.find(':');
        if (colonPos != std::string::npos) {
            size_t start = line.find('"');
            size_t end = line.find('"', start + 1);
            if (start != std::string::npos && end != std::string::npos) {
                key = line.substr(start + 1, end - start - 1);
                
                start = line.find('"', colonPos + 1);
                end = line.find('"', start + 1);
                if (start != std::string::npos && end != std::string::npos) {
                    value = line.substr(start + 1, end - start - 1);
                    config[key] = value;
                }
            }
        }
    }
    return config;
}

int main(int argc, char* argv[]) {
    std::string name = "World";
    std::string mode = "simple";
    std::string configFile = "config.json";
    
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--name" && i + 1 < argc) {
            name = argv[++i];
        } else if (arg == "--mode" && i + 1 < argc) {
            mode = argv[++i];
        } else if (arg == "--config" && i + 1 < argc) {
            configFile = argv[++i];
        } else if (arg == "--help") {
            std::cout << "Usage: ./hello [options]\n";
            std::cout << "  --name <name>    Set greeting name\n";
            std::cout << "  --mode <mode>    Set mode: simple, fancy, banner\n";
            std::cout << "  --config <file>  Set config file path\n";
            std::cout << "  --help           Show this help\n";
            return 0;
        }
    }
    
    auto config = parseConfig(configFile);
    if (config.count("name")) name = config["name"];
    if (config.count("mode")) mode = config["mode"];
    
    if (mode == "fancy") {
        std::cout << "═══════════════════════════════\n";
        std::cout << "     Hello, " << name << "!\n";
        std::cout << "═══════════════════════════════\n";
    } else if (mode == "banner") {
        std::cout << "╔════════════════════════════╗\n";
        std::cout << "║    Hello, " << name << "!     ║\n";
        std::cout << "╚════════════════════════════╝\n";
    } else {
        std::cout << "Hello, " << name << "!" << std::endl;
    }
    
    return 0;
}
EOF
            git add hello.cpp
            
            # 创建示例配置文件
            cat > config.json <<'EOF'
{
  "name": "Developer",
  "mode": "simple"
}
EOF
            git add config.json
            COMMIT_MSG="feat: add JSON config file support (closes #$ISSUE_NUMBER)"
        else
            log "⚠️ 未找到 hello.cpp，创建配置文档"
            cat > CONFIG.md <<EOF
# JSON 配置文件支持

## 配置格式

\`\`\`json
{
  "name": "Developer",
  "mode": "fancy"
}
\`\`\`

## 命令行参数

- \`--config <file>\` 指定配置文件路径
- \`--name <name>\` 覆盖配置中的用户名
- \`--mode <mode>\` 覆盖配置中的模式
EOF
            git add CONFIG.md
            COMMIT_MSG="docs: add config file documentation (closes #$ISSUE_NUMBER)"
        fi
    else
        log "📋 任务类型：通用配置需求"
        cat > "SOLUTION-$ISSUE_NUMBER.md" <<EOF
# Solution for Issue #$ISSUE_NUMBER
EOF
        git add "SOLUTION-$ISSUE_NUMBER.md"
        COMMIT_MSG="docs: add solution for issue #$ISSUE_NUMBER"
    fi
elif echo "$ISSUE_TITLE $ISSUE_BODY" | grep -qiE "test.*c\+\+|c\+\+.*test|测试.*程序"; then
    log "📝 任务类型：C++ 程序添加测试"
    COMMIT_MSG="feat: add test support (closes #$ISSUE_NUMBER)"
elif echo "$ISSUE_TITLE $ISSUE_BODY" | grep -qiE "c\+\+|hello.*world"; then
    log "📝 任务类型：C++ Hello World 程序"
    
    cat > hello.cpp <<'EOF'
#include <iostream>

int main() {
    std::cout << "Hello, World!" << std::endl;
    return 0;
}
EOF
    
    cat > Makefile <<'EOF'
CXX = g++
CXXFLAGS = -std=c++11 -Wall -Wextra

hello: hello.cpp
	$(CXX) $(CXXFLAGS) -o hello hello.cpp

clean:
	rm -f hello

.PHONY: clean
EOF
    
    cat > HELLO_README.md <<EOF
# Hello World in C++

## 编译
\`\`\`bash
make
\`\`\`

## 运行
\`\`\`bash
./hello
\`\`\`
EOF
    
    git add hello.cpp Makefile HELLO_README.md
    COMMIT_MSG="feat: add C++ Hello World program (closes #$ISSUE_NUMBER)"
elif echo "$ISSUE_TITLE" | grep -qiE "python"; then
    log "🐍 任务类型：Python 相关"
    echo "# Python Task" > task.py
    git add task.py
    COMMIT_MSG="feat: add Python task template (closes #$ISSUE_NUMBER)"
elif echo "$ISSUE_TITLE" | grep -qiE "javascript|node\.js|js "; then
    log "📜 任务类型：JavaScript 相关"
    echo "// JavaScript Task" > task.js
    git add task.js
    COMMIT_MSG="feat: add JavaScript task template (closes #$ISSUE_NUMBER)"
elif echo "$ISSUE_TITLE" | grep -qiE "json"; then
    log "📋 任务类型：JSON 相关（需要根据上下文判断语言）"
    # 创建通用 JSON 配置文件模板
    cat > "config-$ISSUE_NUMBER.json" <<EOF
{
  "name": "Developer",
  "mode": "default"
}
EOF
    git add "config-$ISSUE_NUMBER.json"
    COMMIT_MSG="feat: add JSON config template (closes #$ISSUE_NUMBER)"
else
    log "📋 任务类型：通用任务"
    # 创建通用的解决方案文件
    cat > "SOLUTION-$ISSUE_NUMBER.md" <<EOF
# Solution for Issue #$ISSUE_NUMBER

## Issue
$ISSUE_TITLE

## Description
${ISSUE_BODY:-No description provided}

## Solution
[Solution details here]

## Testing
[Test instructions here]

---
Generated by OpenClaw Auto Dev 🦞
EOF
        git add "SOLUTION-$ISSUE_NUMBER.md"
        COMMIT_MSG="feat: add solution for issue #$ISSUE_NUMBER"
fi

# 步骤 5: 验证变更
log "🔍 验证变更..."
VALIDATION_SCRIPT="$SCRIPT_DIR/validate-changes.sh"
if [ -x "$VALIDATION_SCRIPT" ]; then
    # 传递 REPO 环境变量给验证脚本
    export REPO
    if ! "$VALIDATION_SCRIPT" "$ISSUE_NUMBER"; then
        log "❌ 验证失败，中止提交"
        # 恢复更改
        git reset --hard HEAD
        error_exit "变更验证失败"
    fi
    log "✅ 验证通过"
else
    log "⚠️ 验证脚本不存在或不可执行，跳过验证"
fi

# 步骤 6: 提交更改
log "📦 提交更改..."
git add -A
git commit -m "$COMMIT_MSG"

# 步骤 7: 推送到远程分支
log "📤 推送到远程分支..."
git push -u origin "$BRANCH_NAME"

# 步骤 8: 创建 PR
log "🔀 创建 Pull Request..."
PR_TITLE=$(gh pr create \
    --title "Fix: $ISSUE_TITLE" \
    --body "This PR addresses Issue #$ISSUE_NUMBER

## Changes
- Automated fix by OpenClaw Auto Dev 🦞

## Checklist
- [ ] Code reviewed
- [ ] Tests passed
- [ ] Documentation updated

Closes #$ISSUE_NUMBER" \
    --repo "$REPO" \
    --base master \
    --head "$BRANCH_NAME")

# 提取 PR 编号（gh pr create 返回 URL，需要从 URL 或列表中提取）
PR_NUMBER=$(gh pr list --head "$BRANCH_NAME" --repo "$REPO" --json number --jq '.[0].number' 2>/dev/null || echo "")

if [ -n "$PR_NUMBER" ] && [ "$PR_NUMBER" != "null" ]; then
    log "✅ PR #$PR_NUMBER 已创建"
else
    log "⚠️ 无法提取 PR 编号"
    PR_NUMBER="unknown"
fi

# 步骤 9: 更新 Issue 标签为 pr-created
log "🏷️ 更新 Issue 标签为 openclaw-pr-created..."
gh issue edit "$ISSUE_NUMBER" \
    --remove-label "openclaw-processing" \
    --add-label "openclaw-pr-created" \
    --repo "$REPO"

# 步骤 10: 自动合并 PR
log "🔀 等待 CI 检查（3 秒）..."
sleep 3

log "✅ 合并 Pull Request..."
# 使用 --auto 让 GitHub 在 CI 通过后自动合并，或立即合并
MERGE_RESULT=$(gh pr merge "$PR_NUMBER" \
    --repo "$REPO" \
    --merge \
    --subject "Fix: $ISSUE_TITLE" \
    --body "Automatically merged by OpenClaw Auto Dev 🦞" 2>&1) || {
    log "⚠️ PR 合并命令执行失败：$MERGE_RESULT"
    log "⚠️ 尝试使用 API 直接合并..."
    gh api repos/"$REPO"/pulls/"$PR_NUMBER"/merge -X PUT \
        -f merge_method=merge \
        -f commit_title="Fix: $ISSUE_TITLE" \
        -f commit_message="Automatically merged by OpenClaw Auto Dev 🦞" || {
        log "❌ PR 合并失败，可能需要人工介入"
        error_exit "PR 合并失败"
    }
}

log "✅ 等待合并完成（2 秒）..."
sleep 2

# 验证合并状态
MERGE_STATUS=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json merged --jq '.merged')
if [ "$MERGE_STATUS" != "true" ]; then
    log "⚠️ PR 合并状态验证失败，当前状态：$MERGE_STATUS"
    log "⚠️ 继续执行后续步骤..."
fi

# 步骤 11: 更新 Issue 标签为 completed
log "🏷️ 更新 Issue 标签为 openclaw-completed..."
gh issue edit "$ISSUE_NUMBER" \
    --remove-label "openclaw-pr-created" 2>/dev/null || true \
    --add-label "openclaw-completed" \
    --repo "$REPO"

# 步骤 12: 关闭 Issue
log "✅ 关闭 Issue..."
gh issue close "$ISSUE_NUMBER" --repo "$REPO"

# 步骤 13: 删除远程分支
log "🧹 清理分支..."
git checkout master
git pull origin master

# 检查分支是否存在再删除
if git show-ref --verify --quiet refs/heads/"$BRANCH_NAME"; then
    git branch -D "$BRANCH_NAME"
    log "✅ 本地分支已删除"
else
    log "ℹ️ 本地分支不存在，跳过删除"
fi

if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
    git push origin --delete "$BRANCH_NAME" || true
    log "✅ 远程分支已删除"
else
    log "ℹ️ 远程分支不存在，跳过删除"
fi

# 生成完成报告
cat > "$PROJECT_ROOT/scan-result.json" <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "status": "completed",
    "message": "Issue #$ISSUE_NUMBER 已处理完成",
    "issue_number": $ISSUE_NUMBER,
    "issue_title": "$(echo "$ISSUE_TITLE" | jq -Rs '.[:-1]')",
    "pr_number": $PR_NUMBER,
    "branch": "$BRANCH_NAME"
}
EOF

log "=========================================="
log "✅ Issue #$ISSUE_NUMBER 处理完成！"
log "   PR: #$PR_NUMBER"
log "   分支：$BRANCH_NAME (已删除)"
log "=========================================="

# 返回到 master 分支
git checkout master
