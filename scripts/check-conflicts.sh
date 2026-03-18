#!/bin/bash
# 分支冲突检查脚本
# 用法：./scripts/check-conflicts.sh <branch_name>

set -e

BRANCH_NAME=$1

if [ -z "$BRANCH_NAME" ]; then
    echo "用法：$0 <branch_name>"
    exit 1
fi

echo "🔍 检查分支 '$BRANCH_NAME' 的冲突..."

# 获取 main 分支最新代码
git fetch origin main

# 检查冲突
if git merge-base --is-ancestor origin/main "$BRANCH_NAME"; then
    echo "✅ 分支是最新的，无冲突"
    exit 0
else
    echo "⚠️ 分支落后于 main，尝试合并检查冲突..."
    
    # 尝试合并看是否有冲突
    if git merge --no-commit --no-ff origin/main &>/dev/null; then
        echo "✅ 可以自动合并"
        git merge --abort
        exit 0
    else
        echo "❌ 存在合并冲突，需要人工介入"
        git merge --abort
        exit 1
    fi
fi
