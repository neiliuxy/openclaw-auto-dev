#include <stack>
#include <iostream>
#include <cassert>

class MinStack {
private:
    std::stack<int> data_stack;
    std::stack<int> min_stack;

public:
    MinStack() {}

    void push(int x) {
        data_stack.push(x);
        if (min_stack.empty() || x <= min_stack.top()) {
            min_stack.push(x);
        }
    }

    void pop() {
        if (data_stack.empty()) return;
        int x = data_stack.top();
        data_stack.pop();
        if (!min_stack.empty() && x == min_stack.top()) {
            min_stack.pop();
        }
    }

    int top() {
        if (data_stack.empty()) {
            throw std::runtime_error("Stack is empty");
        }
        return data_stack.top();
    }

    int getMin() {
        if (min_stack.empty()) {
            throw std::runtime_error("Stack is empty");
        }
        return min_stack.top();
    }
};

int main() {
    // Test 1: 基础用例 push(3), push(5), getMin -> 3
    {
        MinStack ms;
        ms.push(3);
        ms.push(5);
        assert(ms.getMin() == 3);
        std::cout << "Test 1 passed: getMin after push(3), push(5) = " << ms.getMin() << std::endl;
    }

    // Test 2: 最小值弹出 push(3), push(5), pop(), getMin -> 3
    {
        MinStack ms;
        ms.push(3);
        ms.push(5);
        ms.pop();
        assert(ms.getMin() == 3);
        std::cout << "Test 2 passed: getMin after pop() = " << ms.getMin() << std::endl;
    }

    // Test 3: 重复最小值 push(2), push(2), pop(), getMin -> 2
    {
        MinStack ms;
        ms.push(2);
        ms.push(2);
        ms.pop();
        assert(ms.getMin() == 2);
        std::cout << "Test 3 passed: getMin after duplicate min pop() = " << ms.getMin() << std::endl;
    }

    // Test 4: 递减序列 push(5), push(3), push(7), push(3), getMin -> 3
    {
        MinStack ms;
        ms.push(5);
        ms.push(3);
        ms.push(7);
        ms.push(3);
        assert(ms.getMin() == 3);
        std::cout << "Test 4 passed: getMin = " << ms.getMin() << std::endl;
    }

    std::cout << "\nAll tests passed!" << std::endl;
    return 0;
}
