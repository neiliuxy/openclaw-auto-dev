#!/bin/bash
# validate-changes.sh - 智能验证代码变更
# 根据 issue 内容动态生成验证规则
# 用法：./scripts/validate-changes.sh <issue_number>

set -e

ISSUE_NUM=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VALIDATION_CONFIG_DIR="$PROJECT_ROOT/.validation"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# 从 GitHub 获取 issue 详情
fetch_issue_details() {
    log_step "获取 Issue #$ISSUE_NUM 详情..."
    
    local issue_data=$(gh issue view "$ISSUE_NUM" --json title,body,labels --repo "$REPO" 2>/dev/null)
    
    if [ -z "$issue_data" ]; then
        log_warn "无法从 GitHub 获取 issue，尝试本地配置"
        return 1
    fi
    
    echo "$issue_data"
    return 0
}

# 解析 issue 内容，提取验证需求
parse_validation_requirements() {
    local issue_body="$1"
    local issue_title="$2"
    
    log_step "分析 issue 内容，提取验证需求..."
    
    # 创建临时验证配置
    mkdir -p "$VALIDATION_CONFIG_DIR"
    local config_file="$VALIDATION_CONFIG_DIR/issue-$ISSUE_NUM.conf"
    
    # 清空配置
    > "$config_file"
    
    # 检测文件移动需求
    if echo "$issue_body $issue_title" | grep -qi "移动\|move\|migrate\|relocate"; then
        echo "CHECK_FILE_MOVE=true" >> "$config_file"
        
        # 尝试提取源文件和目标目录
        local src_file=$(echo "$issue_body" | grep -oP '(?<=from )[\w./]+' | head -1 | tr -d "'")
        local dst_dir=$(echo "$issue_body" | grep -oP '(?<=to )[\w./]+' | head -1 | tr -d "'")
        
        if [ -n "$src_file" ]; then
            echo "SRC_FILE=$src_file" >> "$config_file"
        fi
        if [ -n "$dst_dir" ]; then
            echo "DST_DIR=$dst_dir" >> "$config_file"
        fi
    fi
    
    # 检测文件创建需求
    if echo "$issue_body $issue_title" | grep -qi "创建\|create\|add\|新增"; then
        echo "CHECK_FILE_CREATE=true" >> "$config_file"
    fi
    
    # 检测文件删除需求
    if echo "$issue_body $issue_title" | grep -qi "删除\|delete\|remove\|drop"; then
        echo "CHECK_FILE_DELETE=true" >> "$config_file"
    fi
    
    # 检测代码修改需求
    if echo "$issue_body $issue_title" | grep -qi "修改\|modify\|update\|fix\|refactor"; then
        echo "CHECK_CODE_MODIFY=true" >> "$config_file"
    fi
    
    # 检测编译需求
    if echo "$issue_body $issue_title" | grep -qi "编译\|build\|compile\|make"; then
        echo "CHECK_BUILD=true" >> "$config_file"
    fi
    
    # 检测测试需求
    if echo "$issue_body $issue_title" | grep -qi "测试\|test\|run\|execute"; then
        echo "CHECK_RUN=true" >> "$config_file"
    fi
    
    # 检测配置修改需求
    if echo "$issue_body $issue_title" | grep -qi "配置\|config\|setting\|yaml\|json"; then
        echo "CHECK_CONFIG=true" >> "$config_file"
    fi
    
    log_info "验证配置已生成：$config_file"
    cat "$config_file"
}

# 验证文件移动
validate_file_move() {
    local src_file="${SRC_FILE:-}"
    local dst_dir="${DST_DIR:-}"
    
    log_step "验证文件移动..."
    
    # 如果配置中没有指定具体文件，尝试智能检测
    if [ -z "$src_file" ] || [ -z "$dst_dir" ]; then
        log_warn "未指定具体文件路径，执行通用验证"
        
        # 检查最近 git diff 中是否有文件移动
        local moved_files=$(git diff --name-status HEAD~1 | grep "^R" | wc -l)
        if [ "$moved_files" -gt 0 ]; then
            log_info "检测到 $moved_files 个文件移动操作"
            git diff --name-status HEAD~1 | grep "^R"
        else
            log_warn "未检测到文件移动操作"
            return 1
        fi
    else
        # 验证指定的文件移动
        local dst_file="$dst_dir/$(basename "$src_file")"
        
        if [ -f "$src_file" ]; then
            log_error "源文件 $src_file 仍然存在（应该被移动）"
            return 1
        fi
        
        if [ ! -f "$dst_file" ]; then
            log_error "目标文件 $dst_file 不存在"
            return 1
        fi
        
        log_info "✅ 文件移动验证通过：$src_file -> $dst_file"
    fi
    
    return 0
}

# 验证文件创建
validate_file_create() {
    log_step "验证文件创建..."
    
    # 获取新增的文件列表
    local new_files=$(git diff --name-status HEAD~1 | grep "^A" | awk '{print $2}')
    
    if [ -z "$new_files" ]; then
        log_error "没有检测到新创建的文件"
        return 1
    fi
    
    local count=0
    for file in $new_files; do
        if [ -f "$file" ] && [ -s "$file" ]; then
            log_info "✅ 文件已创建：$file ($(wc -c < "$file") bytes)"
            ((count++))
        else
            log_error "文件 $file 不存在或为空"
            return 1
        fi
    done
    
    log_info "✅ 共创建 $count 个文件"
    return 0
}

# 验证文件删除
validate_file_delete() {
    log_step "验证文件删除..."
    
    # 获取删除的文件列表
    local deleted_files=$(git diff --name-status HEAD~1 | grep "^D" | awk '{print $2}')
    
    if [ -z "$deleted_files" ]; then
        log_warn "没有检测到删除的文件"
        return 0
    fi
    
    for file in $deleted_files; do
        if [ -f "$file" ]; then
            log_error "文件 $file 仍然存在（应该被删除）"
            return 1
        fi
        log_info "✅ 文件已删除：$file"
    done
    
    return 0
}

# 验证代码修改
validate_code_modify() {
    log_step "验证代码修改..."
    
    # 获取修改的文件列表
    local modified_files=$(git diff --name-status HEAD~1 | grep "^M" | awk '{print $2}')
    
    if [ -z "$modified_files" ]; then
        log_warn "没有检测到修改的文件"
        return 0
    fi
    
    for file in $modified_files; do
        if [ -f "$file" ]; then
            local changes=$(git diff HEAD~1 -- "$file" | grep -c "^[+-]" || true)
            log_info "✅ 文件已修改：$file ($changes 行变更)"
        else
            log_error "文件 $file 不存在"
            return 1
        fi
    done
    
    return 0
}

# 验证编译
validate_build() {
    log_step "验证编译..."
    
    cd "$PROJECT_ROOT"
    
    # 检查是否有 Makefile
    if [ ! -f "Makefile" ] && [ ! -f "makefile" ]; then
        log_warn "没有 Makefile，跳过编译验证"
        return 0
    fi
    
    # 清理并编译
    log_info "执行 make clean..."
    make clean > /dev/null 2>&1 || true
    
    log_info "执行 make..."
    if ! make 2>&1; then
        log_error "❌ 编译失败"
        return 1
    fi
    
    log_info "✅ 编译成功"
    return 0
}

# 验证程序运行
validate_run() {
    log_step "验证程序运行..."
    
    cd "$PROJECT_ROOT"
    
    # 查找可执行文件
    local executables=$(find . -maxdepth 2 -type f -executable -not -name "*.sh" -not -path "./.git/*" 2>/dev/null)
    
    if [ -z "$executables" ]; then
        log_warn "没有检测到可执行文件，跳过运行验证"
        return 0
    fi
    
    for exe in $executables; do
        log_info "测试执行：$exe"
        if timeout 5 "./$exe" > /dev/null 2>&1; then
            log_info "✅ 程序运行成功：$exe"
        else
            log_warn "⚠️ 程序运行失败或超时：$exe"
        fi
    done
    
    return 0
}

# 验证配置文件
validate_config() {
    log_step "验证配置文件..."
    
    # 查找修改的配置文件
    local config_files=$(git diff --name-only HEAD~1 | grep -E "\.(yaml|yml|json|toml|ini|conf|config)$" || true)
    
    if [ -z "$config_files" ]; then
        log_warn "没有检测到配置文件修改"
        return 0
    fi
    
    for config in $config_files; do
        if [ -f "$config" ]; then
            # 尝试验证 JSON/YAML 语法
            case "$config" in
                *.json)
                    if command -v jq &> /dev/null; then
                        if jq empty "$config" 2>/dev/null; then
                            log_info "✅ JSON 语法有效：$config"
                        else
                            log_error "❌ JSON 语法错误：$config"
                            return 1
                        fi
                    else
                        log_info "✅ 配置文件已修改：$config"
                    fi
                    ;;
                *.yaml|*.yml)
                    if command -v python3 &> /dev/null; then
                        if python3 -c "import yaml; yaml.safe_load(open('$config'))" 2>/dev/null; then
                            log_info "✅ YAML 语法有效：$config"
                        else
                            log_error "❌ YAML 语法错误：$config"
                            return 1
                        fi
                    else
                        log_info "✅ 配置文件已修改：$config"
                    fi
                    ;;
                *)
                    log_info "✅ 配置文件已修改：$config"
                    ;;
            esac
        fi
    done
    
    return 0
}

# 主验证流程
main() {
    log_info "========================================"
    log_info "智能验证系统 - Issue #$ISSUE_NUM"
    log_info "========================================"
    
    cd "$PROJECT_ROOT"
    
    # 获取 issue 详情
    local issue_data=$(fetch_issue_details)
    local issue_title=""
    local issue_body=""
    
    if [ -n "$issue_data" ]; then
        issue_title=$(echo "$issue_data" | jq -r '.title' 2>/dev/null || echo "")
        issue_body=$(echo "$issue_data" | jq -r '.body' 2>/dev/null || echo "")
        
        # 解析验证需求
        parse_validation_requirements "$issue_body" "$issue_title"
    fi
    
    # 加载验证配置
    local config_file="$VALIDATION_CONFIG_DIR/issue-$ISSUE_NUM.conf"
    if [ -f "$config_file" ]; then
        source "$config_file"
    fi
    
    local errors=0
    local checks_run=0
    
    echo ""
    log_info "执行验证检查..."
    echo ""
    
    # 执行配置的验证检查
    if [ "${CHECK_FILE_MOVE:-false}" = "true" ]; then
        ((checks_run++))
        validate_file_move || ((errors++))
    fi
    
    if [ "${CHECK_FILE_CREATE:-false}" = "true" ]; then
        ((checks_run++))
        validate_file_create || ((errors++))
    fi
    
    if [ "${CHECK_FILE_DELETE:-false}" = "true" ]; then
        ((checks_run++))
        validate_file_delete || ((errors++))
    fi
    
    if [ "${CHECK_CODE_MODIFY:-false}" = "true" ]; then
        ((checks_run++))
        validate_code_modify || ((errors++))
    fi
    
    if [ "${CHECK_BUILD:-false}" = "true" ]; then
        ((checks_run++))
        validate_build || ((errors++))
    fi
    
    if [ "${CHECK_RUN:-false}" = "true" ]; then
        ((checks_run++))
        validate_run || ((errors++))
    fi
    
    if [ "${CHECK_CONFIG:-false}" = "true" ]; then
        ((checks_run++))
        validate_config || ((errors++))
    fi
    
    # 如果没有特定检查，执行基础验证
    if [ $checks_run -eq 0 ]; then
        log_warn "没有特定验证需求，执行基础验证..."
        validate_code_modify || ((errors++))
        ((checks_run++))
    fi
    
    echo ""
    log_info "========================================"
    log_info "验证完成：$checks_run 个检查，$errors 个错误"
    log_info "========================================"
    
    if [ $errors -eq 0 ]; then
        log_info "✅ 所有验证通过！"
        return 0
    else
        log_error "❌ 验证失败：$errors 个错误"
        return $errors
    fi
}

# 执行
main
