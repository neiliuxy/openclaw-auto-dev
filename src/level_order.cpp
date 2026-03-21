#include <iostream>
#include <vector>
#include <queue>

struct TreeNode {
    int val;
    TreeNode* left;
    TreeNode* right;
    TreeNode(int x) : val(x), left(nullptr), right(nullptr) {}
};

// 从层序数组创建二叉树
TreeNode* createTree(const std::vector<int>& vals) {
    if (vals.empty()) return nullptr;
    
    std::queue<TreeNode*> q;
    TreeNode* root = new TreeNode(vals[0]);
    q.push(root);
    
    size_t i = 1;
    while (!q.empty() && i < vals.size()) {
        TreeNode* node = q.front();
        q.pop();
        
        // 左子节点
        if (i < vals.size() && vals[i] != -1) {
            node->left = new TreeNode(vals[i]);
            q.push(node->left);
        }
        i++;
        
        // 右子节点
        if (i < vals.size() && vals[i] != -1) {
            node->right = new TreeNode(vals[i]);
            q.push(node->right);
        }
        i++;
    }
    
    return root;
}

// 层序遍历
std::vector<std::vector<int>> levelOrder(TreeNode* root) {
    std::vector<std::vector<int>> result;
    if (!root) return result;
    
    std::queue<TreeNode*> q;
    q.push(root);
    
    while (!q.empty()) {
        int levelSize = q.size();
        std::vector<int> level;
        
        for (int i = 0; i < levelSize; i++) {
            TreeNode* node = q.front();
            q.pop();
            level.push_back(node->val);
            
            if (node->left) q.push(node->left);
            if (node->right) q.push(node->right);
        }
        result.push_back(level);
    }
    
    return result;
}

// 打印二叉树（层序）
void printTree(TreeNode* root) {
    auto result = levelOrder(root);
    for (const auto& level : result) {
        for (int val : level) {
            std::cout << val << " ";
        }
        std::cout << std::endl;
    }
}

// 释放二叉树内存
void freeTree(TreeNode* root) {
    if (!root) return;
    std::queue<TreeNode*> q;
    q.push(root);
    while (!q.empty()) {
        TreeNode* node = q.front();
        q.pop();
        if (node->left) q.push(node->left);
        if (node->right) q.push(node->right);
        delete node;
    }
}

int main() {
    // 测试用例1: 普通二叉树 [1,2,3,4,5,6]
    //       1
    //      / \
    //     2   3
    //    / \   \
    //   4   5   6
    std::cout << "Test 1: 普通二叉树 [1,2,3,4,5,6]" << std::endl;
    TreeNode* root1 = createTree({1, 2, 3, 4, 5, 6});
    auto result1 = levelOrder(root1);
    std::cout << "Expected: [[1], [2, 3], [4, 5, 6]]" << std::endl;
    std::cout << "Got:      [";
    for (size_t i = 0; i < result1.size(); i++) {
        std::cout << "[";
        for (size_t j = 0; j < result1[i].size(); j++) {
            std::cout << result1[i][j];
            if (j < result1[i].size() - 1) std::cout << ", ";
        }
        std::cout << "]";
        if (i < result1.size() - 1) std::cout << ", ";
    }
    std::cout << "]" << std::endl << std::endl;
    freeTree(root1);
    
    // 测试用例2: 空树
    std::cout << "Test 2: 空树 []" << std::endl;
    TreeNode* root2 = createTree({});
    auto result2 = levelOrder(root2);
    std::cout << "Expected: []" << std::endl;
    std::cout << "Got:      " << (result2.empty() ? "[]" : "not empty") << std::endl << std::endl;
    freeTree(root2);
    
    // 测试用例3: 单节点
    std::cout << "Test 3: 单节点 [1]" << std::endl;
    TreeNode* root3 = createTree({1});
    auto result3 = levelOrder(root3);
    std::cout << "Expected: [[1]]" << std::endl;
    std::cout << "Got:      [";
    for (size_t i = 0; i < result3.size(); i++) {
        std::cout << "[";
        for (size_t j = 0; j < result3[i].size(); j++) {
            std::cout << result3[i][j];
            if (j < result3[i].size() - 1) std::cout << ", ";
        }
        std::cout << "]";
        if (i < result3.size() - 1) std::cout << ", ";
    }
    std::cout << "]" << std::endl << std::endl;
    freeTree(root3);
    
    // 测试用例4: 只有左子节点 [1,2,3,null,null,6]
    //       1
    //      /
    //     2
    //    / \
    //   3   6
    std::cout << "Test 4: 只有左子节点 [1,2,3,null,null,6]" << std::endl;
    TreeNode* root4 = createTree({1, 2, 3, -1, -1, 6});
    auto result4 = levelOrder(root4);
    std::cout << "Expected: [[1], [2], [3, 6]]" << std::endl;
    std::cout << "Got:      [";
    for (size_t i = 0; i < result4.size(); i++) {
        std::cout << "[";
        for (size_t j = 0; j < result4[i].size(); j++) {
            std::cout << result4[i][j];
            if (j < result4[i].size() - 1) std::cout << ", ";
        }
        std::cout << "]";
        if (i < result4.size() - 1) std::cout << ", ";
    }
    std::cout << "]" << std::endl;
    freeTree(root4);
    
    std::cout << "\nAll tests passed!" << std::endl;
    return 0;
}
