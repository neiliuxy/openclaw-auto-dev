# SPEC.md - Issue #71: 链表反转

## 1. 概述

- **Issue**: #71 test: 链表反转
- **实现文件**: `src/list_reverse.cpp`
- **功能**: 实现单链表的反转功能

## 2. 技术规格

### 2.1 链表节点定义

```cpp
struct ListNode {
    int val;
    ListNode* next;
    ListNode(int x) : val(x), next(nullptr) {}
};
```

### 2.2 核心函数

| 函数名 | 描述 | 参数 | 返回值 |
|--------|------|------|--------|
| `reverse_list` | 反转单链表 | `ListNode* head` | 反转后的链表头节点 `ListNode*` |
| `create_list` | 从数组创建链表 | `std::vector<int> vals` | 链表头节点 |
| `print_list` | 打印链表 | `ListNode* head` | 无 |
| `free_list` | 释放链表内存 | `ListNode* head` | 无 |

### 2.3 算法

使用迭代法（双指针）反转链表，时间复杂度 O(n)，空间复杂度 O(1)。

### 2.4 反转流程

```
原始: 1 -> 2 -> 3 -> 4 -> 5 -> NULL
反转: 5 -> 4 -> 3 -> 2 -> 1 -> NULL
```

## 3. 测试用例

| 用例 | 输入 | 预期输出 |
|------|------|----------|
| 普通链表 | [1,2,3,4,5] | [5,4,3,2,1] |
| 空链表 | [] | NULL |
| 单节点 | [1] | [1] |
| 双节点 | [1,2] | [2,1] |

## 4. 验收标准

- [x] 链表节点结构正确定义
- [x] `reverse_list` 函数正确反转链表
- [x] 包含辅助函数：`create_list`, `print_list`, `free_list`
- [x] 支持空链表、单节点、双节点、多节点场景
- [x] main 函数包含测试用例验证

## 5. 依赖

- C++11 标准库
- `<vector>`, `<iostream>`
