#define MIN_STACK_TEST
#include "min_stack.cpp"
#include <iostream>
#include <cassert>
#include <stdexcept>

void test_basic_min() {
    MinStack ms;
    ms.push(3);
    ms.push(5);
    assert(ms.getMin() == 3);
    assert(ms.top() == 5);
    std::cout << "test_basic_min passed\n";
}

void test_pop_resets_min() {
    MinStack ms;
    ms.push(3);
    ms.push(5);
    ms.pop();
    assert(ms.getMin() == 3);
    assert(ms.top() == 3);
    std::cout << "test_pop_resets_min passed\n";
}

void test_duplicate_min() {
    MinStack ms;
    ms.push(2);
    ms.push(2);
    ms.pop();
    assert(ms.getMin() == 2);
    std::cout << "test_duplicate_min passed\n";
}

void test_decreasing_sequence() {
    MinStack ms;
    ms.push(5);
    ms.push(3);
    ms.push(7);
    ms.push(3);
    assert(ms.getMin() == 3);
    assert(ms.top() == 3);
    ms.pop();
    assert(ms.getMin() == 3);
    assert(ms.top() == 7);
    ms.pop();
    assert(ms.getMin() == 3);
    assert(ms.top() == 3);
    ms.pop();
    assert(ms.getMin() == 5);
    std::cout << "test_decreasing_sequence passed\n";
}

void test_empty_stack_getMin() {
    MinStack ms;
    bool threw = false;
    try {
        ms.getMin();
    } catch (const std::runtime_error&) {
        threw = true;
    }
    assert(threw);
    std::cout << "test_empty_stack_getMin passed\n";
}

void test_empty_stack_top() {
    MinStack ms;
    bool threw = false;
    try {
        ms.top();
    } catch (const std::runtime_error&) {
        threw = true;
    }
    assert(threw);
    std::cout << "test_empty_stack_top passed\n";
}

void test_empty_stack_pop() {
    MinStack ms;
    ms.pop(); // should not throw
    std::cout << "test_empty_stack_pop passed\n";
}

int main() {
    test_basic_min();
    test_pop_resets_min();
    test_duplicate_min();
    test_decreasing_sequence();
    test_empty_stack_getMin();
    test_empty_stack_top();
    test_empty_stack_pop();
    
    std::cout << "\nAll tests passed!\n";
    return 0;
}
