#include <iostream>
#include <vector>

struct ListNode {
    int val;
    ListNode* next;
    ListNode(int x) : val(x), next(nullptr) {}
};

ListNode* create_list(std::vector<int> vals) {
    if (vals.empty()) return nullptr;
    ListNode* head = new ListNode(vals[0]);
    ListNode* cur = head;
    for (size_t i = 1; i < vals.size(); ++i) {
        cur->next = new ListNode(vals[i]);
        cur = cur->next;
    }
    return head;
}

void print_list(ListNode* head) {
    ListNode* cur = head;
    while (cur) {
        std::cout << cur->val;
        if (cur->next) std::cout << " -> ";
        cur = cur->next;
    }
    std::cout << " -> NULL" << std::endl;
}

void free_list(ListNode* head) {
    while (head) {
        ListNode* tmp = head;
        head = head->next;
        delete tmp;
    }
}

ListNode* reverse_list(ListNode* head) {
    ListNode* prev = nullptr;
    ListNode* cur = head;
    while (cur) {
        ListNode* next = cur->next;
        cur->next = prev;
        prev = cur;
        cur = next;
    }
    return prev;
}

int main() {
    // Test case 1: 普通链表
    {
        std::vector<int> vals = {1, 2, 3, 4, 5};
        ListNode* head = create_list(vals);
        std::cout << "原始: ";
        print_list(head);
        head = reverse_list(head);
        std::cout << "反转: ";
        print_list(head);
        free_list(head);
    }

    // Test case 2: 空链表
    {
        std::vector<int> vals = {};
        ListNode* head = create_list(vals);
        std::cout << "空链表: ";
        print_list(head);
        head = reverse_list(head);
        std::cout << "反转后: ";
        print_list(head);
        free_list(head);
    }

    // Test case 3: 单节点
    {
        std::vector<int> vals = {1};
        ListNode* head = create_list(vals);
        std::cout << "单节点: ";
        print_list(head);
        head = reverse_list(head);
        std::cout << "反转后: ";
        print_list(head);
        free_list(head);
    }

    // Test case 4: 双节点
    {
        std::vector<int> vals = {1, 2};
        ListNode* head = create_list(vals);
        std::cout << "双节点: ";
        print_list(head);
        head = reverse_list(head);
        std::cout << "反转后: ";
        print_list(head);
        free_list(head);
    }

    return 0;
}
