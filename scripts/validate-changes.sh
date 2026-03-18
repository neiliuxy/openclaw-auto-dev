#!/bin/bash
# validate-changes.sh - 验证代码变更的正确性
# 用法：./scripts/validate-changes.sh <issue_number>

set -e

ISSUE_NUM=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 验证文件移动
validate_file_move() {
    local src=$1
    local dst=$2
    
    log_info "验证文件移动：$src -> $dst"
    
    # 检查目标文件是否存在
    if [ ! -f "$dst" ]; then
        log_error "目标文件 $dst 不存在"
        return 1
    fi
    
    # 检查源文件是否已删除（如果是移动操作）
    if [ -f "$src" ]; then
        log_error "源文件 $src 仍然存在（应该被删除）"
        return 1
    fi
    
    # 验证文件大小合理（非空）
    if [ ! -s "$dst" ]; then
        log_error "目标文件 $dst 为空"
        return 1
    fi
    
    log_info "✅ 文件移动验证通过"
    return 0
}

# 验证文件创建
validate_file_created() {
    local filepath=$1
    
    log_info "验证文件创建：$filepath"
    
    if [ ! -f "$filepath" ]; then
        log_error "文件 $filepath 不存在"
        return 1
    fi
    
    if [ ! -s "$filepath" ]; then
        log_error "文件 $filepath 为空"
        return 1
    fi
    
    log_info "✅ 文件创建验证通过"
    return 0
}

# 验证文件删除
validate_file_deleted() {
    local filepath=$1
    
    log_info "验证文件删除：$filepath"
    
    if [ -f "$filepath" ]; then
        log_error "文件 $filepath 仍然存在（应该被删除）"
        return 1
    fi
    
    log_info "✅ 文件删除验证通过"
    return 0
}

# 验证 Makefile 更新
validate_makefile() {
    local makefile_path="$PROJECT_ROOT/Makefile"
    
    if [ ! -f "$makefile_path" ]; then
        log_warn "Makefile 不存在，跳过验证"
        return 0
    fi
    
    log_info "验证 Makefile 语法"
    
    # 检查 Makefile 是否有基本的 target
    if ! grep -q "^[a-zA-Z_][a-zA-Z0-9_]*:" "$makefile_path"; then
        log_error "Makefile 没有有效的 target"
        return 1
    fi
    
    log_info "✅ Makefile 验证通过"
    return 0
}

# 验证编译
validate_build() {
    log_info "执行编译验证"
    
    cd "$PROJECT_ROOT"
    
    # 检查是否有 Makefile
    if [ ! -f "Makefile" ]; then
        log_warn "没有 Makefile，跳过编译验证"
        return 0
    fi
    
    # 清理并编译
    if ! make clean > /dev/null 2>&1; then
        log_warn "make clean 失败，继续尝试编译"
    fi
    
    if ! make > /dev/null 2>&1; then
        log_error "编译失败"
        return 1
    fi
    
    log_info "✅ 编译验证通过"
    return 0
}

# 验证程序运行
validate_run() {
    local program=$1
    
    log_info "验证程序运行：$program"
    
    cd "$PROJECT_ROOT"
    
    if [ ! -x "$program" ]; then
        log_warn "程序 $program 不可执行，跳过运行验证"
        return 0
    fi
    
    if ! ./"$program" > /dev/null 2>&1; then
        log_error "程序 $program 运行失败"
        return 1
    fi
    
    log_info "✅ 程序运行验证通过"
    return 0
}

# 验证 Git 状态
validate_git_status() {
    log_info "验证 Git 状态"
    
    cd "$PROJECT_ROOT"
    
    # 检查是否有未提交的变更
    local uncommitted=$(git status --porcelain | wc -l)
    if [ "$uncommitted" -gt 0 ]; then
        log_warn "有 $uncommitted 个未提交的变更"
        git status --porcelain
    else
        log_info "✅ Git 工作区干净"
    fi
    
    return 0
}

# 主验证流程
main() {
    log_info "================================"
    log_info "开始验证 Issue #$ISSUE_NUM 的变更"
    log_info "================================"
    
    local errors=0
    
    # 读取验证配置（如果存在）
    local config_file="$PROJECT_ROOT/.validation/issue-$ISSUE_NUM.conf"
    
    if [ -f "$config_file" ]; then
        log_info "加载验证配置：$config_file"
        source "$config_file"
    fi
    
    # 执行通用验证
    validate_makefile || ((errors++))
    validate_build || ((errors++))
    validate_git_status || ((errors++))
    
    # 如果有可执行文件，运行测试
    if [ -x "$PROJECT_ROOT/hello" ]; then
        validate_run "hello" || ((errors++))
    fi
    
    echo ""
    log_info "================================"
    if [ $errors -eq 0 ]; then
        log_info "✅ 所有验证通过！"
    else
        log_error "❌ 验证失败：$errors 个错误"
    fi
    log_info "================================"
    
    return $errors
}

# 执行
main
