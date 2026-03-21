# SPEC.md - Issue #75: 二叉树层序遍历

## 1. 概述

- **Issue**: #75 test: 二叉树层序遍历
- **实现文件**: `src/level_order.cpp`
- **功能**: 实现二叉树的层序遍历（广度优先搜索，BFS）

## 2. 技术规格

### 2.1 二叉树节点定义

```cpp
struct TreeNode {
    int val;
    TreeNode* left;
    TreeNode* right;
    TreeNode(int x) : val(x), left(nullptr), right(nullptr) {}
};
```

### 2.2 核心函数

| 函数名 | 描述 | 参数 | 返回值 |
|--------|------|------|--------|
| `levelOrder` | 层序遍历二叉树 | `TreeNode* root` | `std::vector<std::vector<int>>` 每层一个vector |
| `createTree` | 从层序数组创建二叉树 | `std::vector<int> vals` | 树的根节点 |
| `printTree` | 打印二叉树（层序） | `TreeNode* root` | 无 |
| `freeTree` | 释放二叉树内存 | `TreeNode* root` | 无 |

### 2.3 算法

使用队列（queue）进行广度优先搜索，按层遍历二叉树。

### 2.4 遍历流程

```
       1
      / \
     2   3
    / \   \
   4   5   6

层序: [[1], [2,3], [4,5,6]]
```

## 3. 测试用例

| 用例 | 输入 | 预期输出 |
|------|------|----------|
| 普通二叉树 | [1,2,3,4,5,6] | [[1],[2,3],[4,5,6]] |
| 空树 | [] | [] |
| 单节点 | [1] | [[1]] |
| 只有左子节点 | [1,2,3,null,null,6] | [[1],[2],[6]] |

## 4. 验收标准

- [x] 二叉树节点结构正确定义
- [x] `levelOrder` 函数正确进行层序遍历
- [x] 包含辅助函数：`createTree`, `printTree`, `freeTree`
- [x] 支持空树、单节点、多节点场景
- [x] main 函数包含测试用例验证

## 5. 依赖

- C++11 标准库
- `<vector>`, `<iostream>`, `<queue>`
