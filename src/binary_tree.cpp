#include <iostream>
#include <vector>

struct TreeNode {
    int val;
    TreeNode* left;
    TreeNode* right;
    TreeNode(int x) : val(x), left(nullptr), right(nullptr) {}
};

TreeNode* create_tree(std::vector<int> vals) {
    if (vals.empty()) return nullptr;
    std::vector<TreeNode*> nodes(vals.size());
    for (size_t i = 0; i < vals.size(); ++i) {
        nodes[i] = new TreeNode(vals[i]);
    }
    // For a simple array representation:
    // left child = 2*i + 1, right child = 2*i + 2
    for (size_t i = 0; i < vals.size(); ++i) {
        size_t left_idx = 2 * i + 1;
        size_t right_idx = 2 * i + 2;
        if (left_idx < vals.size()) nodes[i]->left = nodes[left_idx];
        if (right_idx < vals.size()) nodes[i]->right = nodes[right_idx];
    }
    return nodes[0];
}

void print_tree_preorder(TreeNode* root) {
    if (!root) {
        std::cout << "NULL" << std::endl;
        return;
    }
    std::vector<int> result;
    std::vector<TreeNode*> stack;
    stack.push_back(root);
    while (!stack.empty()) {
        TreeNode* node = stack.back();
        stack.pop_back();
        result.push_back(node->val);
        if (node->right) stack.push_back(node->right);
        if (node->left) stack.push_back(node->left);
    }
    for (size_t i = 0; i < result.size(); ++i) {
        if (i > 0) std::cout << " -> ";
        std::cout << result[i];
    }
    std::cout << std::endl;
}

void free_tree(TreeNode* root) {
    if (!root) return;
    std::vector<TreeNode*> stack;
    stack.push_back(root);
    while (!stack.empty()) {
        TreeNode* node = stack.back();
        stack.pop_back();
        if (node->left) stack.push_back(node->left);
        if (node->right) stack.push_back(node->right);
        delete node;
    }
}

// Preorder traversal: Root -> Left -> Right (recursive)
std::vector<int> preorder_traversal(TreeNode* root) {
    std::vector<int> result;
    if (!root) return result;
    result.push_back(root->val);
    std::vector<int> left = preorder_traversal(root->left);
    result.insert(result.end(), left.begin(), left.end());
    std::vector<int> right = preorder_traversal(root->right);
    result.insert(result.end(), right.begin(), right.end());
    return result;
}

int main() {
    // Test case 1: 普通二叉树
    //       1
    //      / \
    //     2   3
    //    / \
    //   4   5
    {
        std::vector<int> vals = {1, 2, 3, 4, 5};
        TreeNode* root = create_tree(vals);
        std::cout << "二叉树先序: ";
        std::vector<int> result = preorder_traversal(root);
        for (size_t i = 0; i < result.size(); ++i) {
            if (i > 0) std::cout << " -> ";
            std::cout << result[i];
        }
        std::cout << std::endl;
        free_tree(root);
    }

    // Test case 2: 空树
    {
        std::vector<int> vals = {};
        TreeNode* root = create_tree(vals);
        std::cout << "空树先序: ";
        std::vector<int> result = preorder_traversal(root);
        for (size_t i = 0; i < result.size(); ++i) {
            if (i > 0) std::cout << " -> ";
            std::cout << result[i];
        }
        std::cout << std::endl;
        free_tree(root);
    }

    // Test case 3: 单节点
    {
        std::vector<int> vals = {1};
        TreeNode* root = create_tree(vals);
        std::cout << "单节点先序: ";
        std::vector<int> result = preorder_traversal(root);
        for (size_t i = 0; i < result.size(); ++i) {
            if (i > 0) std::cout << " -> ";
            std::cout << result[i];
        }
        std::cout << std::endl;
        free_tree(root);
    }

    // Test case 4: 只有左子树的树
    //     1
    //    /
    //   2
    //  /
    // 3
    {
        std::vector<int> vals = {1, 2, -1, 3};
        // Reconstruct with explicit -1 as null marker approach
        // Simpler: just test a skewed tree
        TreeNode* root = new TreeNode(1);
        root->left = new TreeNode(2);
        root->left->left = new TreeNode(3);
        std::cout << "左斜树先序: ";
        std::vector<int> result = preorder_traversal(root);
        for (size_t i = 0; i < result.size(); ++i) {
            if (i > 0) std::cout << " -> ";
            std::cout << result[i];
        }
        std::cout << std::endl;
        free_tree(root);
    }

    // Test case 5: 完全二叉树
    //       1
    //      / \
    //     2   3
    //    / \ / \
    //   4  5 6  7
    {
        std::vector<int> vals = {1, 2, 3, 4, 5, 6, 7};
        TreeNode* root = create_tree(vals);
        std::cout << "完全二叉树先序: ";
        std::vector<int> result = preorder_traversal(root);
        for (size_t i = 0; i < result.size(); ++i) {
            if (i > 0) std::cout << " -> ";
            std::cout << result[i];
        }
        std::cout << std::endl;
        free_tree(root);
    }

    return 0;
}
