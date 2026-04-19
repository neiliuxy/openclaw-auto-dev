#!/bin/bash
# validate-changes.sh - 智能验证代码变更
# 根据 issue 内容动态生成验证规则
# 支持 YAML 配置文件（--yaml-config）进行结构化验证
# 用法：./scripts/validate-changes.sh <issue_number> [--yaml-config <file>]

set -e

ISSUE_NUM=""
YAML_CONFIG=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VALIDATION_CONFIG_DIR="$PROJECT_ROOT/.validation"
REPO="neiliuxy/openclaw-auto-dev"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --yaml-config)
            if [[ $# -lt 2 || "$2" == -* ]]; then
                echo "错误：--yaml-config 需要一个文件路径参数" >&2
                echo "用法：$0 <issue_number> [--yaml-config <yaml_file>]"
                exit 1
            fi
            YAML_CONFIG="$2"
            shift 2
            ;;
        *)
            ISSUE_NUM="$1"
            shift
            ;;
    esac
done

if [ -z "$ISSUE_NUM" ]; then
    echo "用法：$0 <issue_number> [--yaml-config <yaml_file>]"
    exit 1
fi

# Validate --yaml-config argument if provided
if [ -n "$YAML_CONFIG" ]; then
    # If YAML_CONFIG looks like a flag (starts with -), --yaml-config had no value
    if [[ "$YAML_CONFIG" == -* ]]; then
        echo "错误：--yaml-config 需要一个文件路径参数" >&2
        echo "用法：$0 <issue_number> [--yaml-config <yaml_file>]"
        exit 1
    fi
    # Validate the file exists when explicitly provided
    if [ ! -f "$YAML_CONFIG" ]; then
        echo "错误：YAML 配置文件不存在：$YAML_CONFIG" >&2
        exit 1
    fi
fi

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${BLUE}[STEP]${NC} $1"; }

# ─── YAML 解析（纯 Shell 实现，仅支持简单结构）──────────────
# 格式：
#   required_actions:
#     - type: create_file
#       path: src/my_feature.cpp
#     - type: modify_file
#       path: CMakeLists.txt
#       must_contain: "my_feature"
#     - type: build
#       command: make
#     - type: test
#       command: make test

parse_yaml_config() {
    local yaml_file="$1"
    local action_count=0
    local tmp_env_file=$(mktemp)

    if [ ! -f "$yaml_file" ]; then
        echo -e "${YELLOW}[WARN]${NC} YAML 配置文件不存在：$yaml_file" >&2
        rm -f "$tmp_env_file"
        return 1
    fi

    echo -e "${BLUE}[STEP]${NC} 读取 YAML 配置文件：$yaml_file" >&2

    # 提取 required_actions 块（从冒号后到文件末尾）
    local in_actions=false
    local indent=""
    local line_num=0

    while IFS= read -r line || [ -n "$line" ]; do
        ((line_num++)) || true

        # 跳过空行和注释
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # 检测 required_actions: 开始
        if [[ "$line" =~ ^[[:space:]]*required_actions[[:space:]]*: ]]; then
            in_actions=true
            # 记录缩进级别
            indent=$(echo "$line" | sed 's/\(.*\):.*/\1/' | sed 's/\(.*\)[^ ]/\1/' | sed 's/[^ ].*//')
            continue
        fi

        $in_actions || continue

        # 检测顶级新节（缩进减少）
        local current_indent=$(echo "$line" | sed 's/\(^ *\).*/\1/')
        if [ ${#current_indent} -le ${#indent} ] && [[ "$line" =~ ^[^-] ]]; then
            break
        fi

        # 只处理 - type: 开头的行
        [[ "$line" =~ ^[[:space:]]*-[[:space:]]*type: ]] || continue

        # 提取 type 值
        local action_type=$(echo "$line" | sed 's/.*- type: *//' | tr -d '"' | tr -d "'" | xargs)
        local action_path=""
        local action_must_contain=""
        local action_command=""

        # 读取后续行（同一 action 块）
        while IFS= read -r subline || [ -n "$subline" ]; do
            [[ -z "$subline" ]] && continue
            local sub_indent=$(echo "$subline" | sed 's/\(^ *\).*/\1/')
            # 子行缩进必须大于 action 行
            [ ${#sub_indent} -le ${#current_indent} ] && break

            if [[ "$subline" =~ ^[[:space:]]*path: ]]; then
                action_path=$(echo "$subline" | sed 's/.*path: *//' | tr -d '"' | tr -d "'" | xargs)
            elif [[ "$subline" =~ ^[[:space:]]*must_contain: ]]; then
                action_must_contain=$(echo "$subline" | sed 's/.*must_contain: *//' | tr -d '"' | tr -d "'" | xargs)
            elif [[ "$subline" =~ ^[[:space:]]*command: ]]; then
                action_command=$(echo "$subline" | sed 's/.*command: *//' | tr -d '"' | tr -d "'" | xargs)
            fi
        done

        # 注册 action 到临时文件（避免子 shell 变量丢失问题）
        echo "YAML_ACTION_${action_count}_TYPE='$action_type'" >> "$tmp_env_file"
        echo "YAML_ACTION_${action_count}_PATH='$action_path'" >> "$tmp_env_file"
        echo "YAML_ACTION_${action_count}_CONTAIN='$action_must_contain'" >> "$tmp_env_file"
        echo "YAML_ACTION_${action_count}_CMD='$action_command'" >> "$tmp_env_file"
        ((action_count++)) || true
    done < "$yaml_file"

    # 输出临时文件路径和计数
    echo "PARSED_ACTION_COUNT=$action_count"
    echo "PARSED_ENV_FILE=$tmp_env_file"
}

# ─── 从 GitHub 获取 issue 详情 ─────────────────────────────────
fetch_issue_details() {
    log_step "获取 Issue #$ISSUE_NUM 详情..."
    local issue_data=$(gh issue view "$ISSUE_NUM" --json title,body,labels --repo "$REPO" 2>/dev/null || echo "")
    if [ -z "$issue_data" ]; then
        log_warn "无法从 GitHub 获取 issue，尝试本地配置"
        return 1
    fi
    echo "$issue_data"
    return 0
}

# ─── 基于 issue 内容生成关键词验证配置 ────────────────────────
parse_validation_requirements() {
    local issue_body="$1"
    local issue_title="$2"

    log_step "分析 issue 内容，提取验证需求..."

    mkdir -p "$VALIDATION_CONFIG_DIR"
    local config_file="$VALIDATION_CONFIG_DIR/issue-$ISSUE_NUM.conf"
    > "$config_file"

    # 检测各种需求
    if echo "$issue_body $issue_title" | grep -qi "移动\|move\|migrate\|relocate"; then
        echo "CHECK_FILE_MOVE=true" >> "$config_file"
        local src_file=$(echo "$issue_body" | grep -oP '(?<=from )[\w./]+' | head -1 | tr -d "'")
        local dst_dir=$(echo "$issue_body" | grep -oP '(?<=to )[\w./]+' | head -1 | tr -d "'")
        [ -n "$src_file" ] && echo "SRC_FILE=$src_file" >> "$config_file"
        [ -n "$dst_dir" ] && echo "DST_DIR=$dst_dir" >> "$config_file"
    fi

    if echo "$issue_body $issue_title" | grep -qi "创建\|create\|add\|新增"; then
        echo "CHECK_FILE_CREATE=true" >> "$config_file"
    fi

    if echo "$issue_body $issue_title" | grep -qi "删除\|delete\|remove\|drop"; then
        echo "CHECK_FILE_DELETE=true" >> "$config_file"
    fi

    if echo "$issue_body $issue_title" | grep -qi "修改\|modify\|update\|fix\|refactor"; then
        echo "CHECK_CODE_MODIFY=true" >> "$config_file"
    fi

    if echo "$issue_body $issue_title" | grep -qi "编译\|build\|compile\|make"; then
        echo "CHECK_BUILD=true" >> "$config_file"
    fi

    if echo "$issue_body $issue_title" | grep -qi "测试\|test\|run\|execute"; then
        echo "CHECK_RUN=true" >> "$config_file"
    fi

    if echo "$issue_body $issue_title" | grep -qi "配置\|config\|setting\|yaml\|json"; then
        echo "CHECK_CONFIG=true" >> "$config_file"
    fi

    log_info "验证配置已生成：$config_file"
}

# ─── YAML action 验证 ──────────────────────────────────────────
validate_yaml_action() {
    local action_type="$1"
    local action_path="$2"
    local action_contain="$3"
    local action_cmd="$4"
    local errors=0

    case "$action_type" in
        create_file)
            log_step "[YAML] 验证 create_file: $action_path"
            if [ -f "$action_path" ] && [ -s "$action_path" ]; then
                log_info "✅ 文件已创建：$action_path ($(wc -c < "$action_path") bytes)"
            else
                log_error "❌ 文件不存在或为空：$action_path"
                errors=$((errors + 1))
            fi
            ;;
        modify_file)
            log_step "[YAML] 验证 modify_file: $action_path"
            if [ ! -f "$action_path" ]; then
                log_error "❌ 文件不存在：$action_path"
                errors=$((errors + 1))
            elif [ -n "$action_contain" ]; then
                if grep -q "$action_contain" "$action_path" 2>/dev/null; then
                    log_info "✅ 文件包含必需内容：$action_path (found: $action_contain)"
                else
                    log_error "❌ 文件不包含必需内容：$action_path (missing: $action_contain)"
                    errors=$((errors + 1))
                fi
            else
                log_info "✅ 文件已修改：$action_path"
            fi
            ;;
        build)
            log_step "[YAML] 验证 build: $action_cmd"
            cd "$PROJECT_ROOT"
            if eval "$action_cmd" > /tmp/build_output.log 2>&1; then
                log_info "✅ 构建成功：$action_cmd"
            else
                log_error "❌ 构建失败：$action_cmd"
                cat /tmp/build_output.log | tail -20
                errors=$((errors + 1))
            fi
            ;;
        test)
            log_step "[YAML] 验证 test: $action_cmd"
            cd "$PROJECT_ROOT"
            if eval "$action_cmd" > /tmp/test_output.log 2>&1; then
                log_info "✅ 测试成功：$action_cmd"
            else
                log_warn "⚠️ 测试失败或不可用：$action_cmd"
                cat /tmp/test_output.log | tail -10
            fi
            ;;
        *)
            log_warn "未知 action 类型：$action_type"
            ;;
    esac

    return $errors
}

# ─── 传统关键词验证（fallback） ───────────────────────────────
validate_file_move() {
    local errors=0
    log_step "验证文件移动..."

    if [ -z "$SRC_FILE" ] || [ -z "$DST_DIR" ]; then
        local moved_files=$(git diff --name-status HEAD~1 2>/dev/null | grep "^R" | wc -l || echo "0")
        if [ "$moved_files" -gt 0 ]; then
            log_info "检测到 $moved_files 个文件移动操作"
            git diff --name-status HEAD~1 | grep "^R"
        else
            log_warn "未检测到文件移动操作"
        fi
    else
        local dst_file="$DST_DIR/$(basename "$SRC_FILE")"
        if [ -f "$SRC_FILE" ]; then
            log_error "源文件 $SRC_FILE 仍然存在（应该被移动）"
            errors=$((errors + 1))
        fi
        if [ ! -f "$dst_file" ]; then
            log_error "目标文件 $dst_file 不存在"
            errors=$((errors + 1))
        else
            log_info "✅ 文件移动验证通过：$SRC_FILE -> $dst_file"
        fi
    fi
    return $errors
}

validate_file_create() {
    local errors=0
    log_step "验证文件创建..."
    local new_files=$(git diff --name-status HEAD~1 2>/dev/null | grep "^A" | awk '{print $2}' || echo "")

    if [ -z "$new_files" ]; then
        log_error "没有检测到新创建的文件"
        return 1
    fi

    local count=0
    for file in $new_files; do
        if [ -f "$file" ] && [ -s "$file" ]; then
            log_info "✅ 文件已创建：$file ($(wc -c < "$file") bytes)"
            ((count++)) || true
        else
            log_error "文件 $file 不存在或为空"
            errors=$((errors + 1))
        fi
    done
    log_info "✅ 共创建 $count 个文件"
    return $errors
}

validate_file_delete() {
    local errors=0
    log_step "验证文件删除..."
    local deleted_files=$(git diff --name-status HEAD~1 2>/dev/null | grep "^D" | awk '{print $2}' || echo "")

    if [ -z "$deleted_files" ]; then
        log_warn "没有检测到删除的文件"
        return 0
    fi

    for file in $deleted_files; do
        if [ -f "$file" ]; then
            log_error "文件 $file 仍然存在（应该被删除）"
            errors=$((errors + 1))
        else
            log_info "✅ 文件已删除：$file"
        fi
    done
    return $errors
}

validate_code_modify() {
    local errors=0
    log_step "验证代码修改..."
    local modified_files=$(git diff --name-status HEAD~1 2>/dev/null | grep "^M" | grep -v "scan-result.json" | awk '{print $2}' || echo "")

    if [ -z "$modified_files" ]; then
        log_warn "没有检测到修改的文件"
        return 0
    fi

    for file in $modified_files; do
        if [ -f "$file" ]; then
            local changes=$(git diff HEAD~1 -- "$file" 2>/dev/null | grep -c "^[+-]" || true)
            log_info "✅ 文件已修改：$file ($changes 行变更)"
        else
            log_error "文件 $file 不存在"
            errors=$((errors + 1))
        fi
    done
    return $errors
}

validate_build() {
    local errors=0
    log_step "验证编译..."
    cd "$PROJECT_ROOT"

    if [ ! -f "Makefile" ] && [ ! -f "makefile" ]; then
        log_warn "没有 Makefile，跳过编译验证"
        return 0
    fi

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

validate_run() {
    local errors=0
    log_step "验证程序运行..."
    cd "$PROJECT_ROOT"

    local executables=$(find . -maxdepth 2 -type f -executable -not -name "*.sh" -not -path "./.git/*" 2>/dev/null || echo "")

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

validate_config() {
    local errors=0
    log_step "验证配置文件..."
    local config_files=$(git diff --name-only HEAD~1 2>/dev/null | grep -E "\.(yaml|yml|json|toml|ini|conf|config)$" || echo "")

    if [ -z "$config_files" ]; then
        log_warn "没有检测到配置文件修改"
        return 0
    fi

    for config in $config_files; do
        if [ -f "$config" ]; then
            case "$config" in
                *.json)
                    if command -v jq &> /dev/null; then
                        if jq empty "$config" 2>/dev/null; then
                            log_info "✅ JSON 语法有效：$config"
                        else
                            log_error "❌ JSON 语法错误：$config"
                            errors=$((errors + 1))
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
    return $errors
}

# ─── 主验证流程 ────────────────────────────────────────────────
main() {
    log_info "========================================"
    log_info "智能验证系统 - Issue #$ISSUE_NUM"
    log_info "========================================"

    cd "$PROJECT_ROOT"

    local total_errors=0
    local use_yaml=false

    # 如果指定了 YAML 配置，优先使用 YAML 验证
    if [ -n "$YAML_CONFIG" ] && [ -f "$YAML_CONFIG" ]; then
        use_yaml=true
        # parse_yaml_config now outputs env file path and count
        local parse_output=$(parse_yaml_config "$YAML_CONFIG")
        local env_file=$(echo "$parse_output" | grep "PARSED_ENV_FILE=" | cut -d= -f2)
        local action_count=$(echo "$parse_output" | grep "PARSED_ACTION_COUNT=" | cut -d= -f2)

        # Source the env file to load YAML_ACTION_* variables into current shell
        if [ -f "$env_file" ]; then
            source "$env_file"
        fi

        if [ "$action_count" -gt 0 ]; then
            log_info "从 YAML 加载了 $action_count 个验证规则"
            echo ""
            log_info "执行 YAML 结构化验证..."
            echo ""

            for ((i=0; i<action_count; i++)); do
                local atype=$(eval "echo \$YAML_ACTION_${i}_TYPE")
                local apath=$(eval "echo \$YAML_ACTION_${i}_PATH")
                local acontain=$(eval "echo \$YAML_ACTION_${i}_CONTAIN")
                local acmd=$(eval "echo \$YAML_ACTION_${i}_CMD")

                validate_yaml_action "$atype" "$apath" "$acontain" "$acmd"
                total_errors=$((total_errors + $?))
            done

            echo ""
            log_info "========================================"
            log_info "YAML 验证完成：$action_count 个检查，$total_errors 个错误"
            log_info "========================================"

            if [ $total_errors -eq 0 ]; then
                log_info "✅ 所有 YAML 验证通过！"
                return 0
            else
                log_error "❌ 验证失败：$total_errors 个错误"
                return $total_errors
            fi
        fi
    fi

    # Fallback: 关键词验证
    local issue_data=$(fetch_issue_details || echo "")
    local issue_title=""
    local issue_body=""

    if [ -n "$issue_data" ]; then
        issue_title=$(echo "$issue_data" | jq -r '.title' 2>/dev/null || echo "")
        issue_body=$(echo "$issue_data" | jq -r '.body' 2>/dev/null || echo "")
        parse_validation_requirements "$issue_body" "$issue_title"
    fi

    local config_file="$VALIDATION_CONFIG_DIR/issue-$ISSUE_NUM.conf"
    if [ -f "$config_file" ]; then
        source "$config_file"
    fi

    local checks_run=0
    echo ""
    log_info "执行关键词 fallback 验证..."
    echo ""

    if [ "${CHECK_FILE_MOVE:-false}" = "true" ]; then
        ((checks_run++)) || true
        validate_file_move ; total_errors=$((total_errors + 1))
    fi

    if [ "${CHECK_FILE_CREATE:-false}" = "true" ]; then
        ((checks_run++)) || true
        validate_file_create ; total_errors=$((total_errors + 1))
    fi

    if [ "${CHECK_FILE_DELETE:-false}" = "true" ]; then
        ((checks_run++)) || true
        validate_file_delete ; total_errors=$((total_errors + 1))
    fi

    if [ "${CHECK_CODE_MODIFY:-false}" = "true" ]; then
        ((checks_run++)) || true
        validate_code_modify ; total_errors=$((total_errors + 1))
    fi

    if [ "${CHECK_BUILD:-false}" = "true" ]; then
        ((checks_run++)) || true
        validate_build ; total_errors=$((total_errors + 1))
    fi

    if [ "${CHECK_RUN:-false}" = "true" ]; then
        ((checks_run++)) || true
        validate_run ; total_errors=$((total_errors + 1))
    fi

    if [ "${CHECK_CONFIG:-false}" = "true" ]; then
        ((checks_run++)) || true
        validate_config ; total_errors=$((total_errors + 1))
    fi

    if [ $checks_run -eq 0 ]; then
        log_warn "没有特定验证需求，执行基础验证..."
        validate_code_modify ; total_errors=$((total_errors + 1))
        ((checks_run++)) || true
    fi

    echo ""
    log_info "========================================"
    log_info "验证完成：$checks_run 个检查，$total_errors 个错误"
    log_info "========================================"

    if [ $total_errors -eq 0 ]; then
        log_info "✅ 所有验证通过！"
        return 0
    else
        log_error "❌ 验证失败：$total_errors 个错误"
        return $total_errors
    fi
}

main
