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
    std::cout << "test_pop_resets_min passed\n";
}

void test_empty_pop() {
    MinStack ms;
    ms.pop();
    ms.push(1);
    assert(ms.getMin() == 1);
    assert(ms.top() == 1);
    std::cout << "test_empty_pop passed\n";
}

void test_decreasing_sequence() {
    MinStack ms;
    ms.push(3);
    ms.push(2);
    ms.push(1);
    assert(ms.getMin() == 1);
    ms.pop();
    assert(ms.getMin() == 2);
    ms.pop();
    assert(ms.getMin() == 3);
    std::cout << "test_decreasing_sequence passed\n";
}

void test_duplicate_min() {
    MinStack ms;
    ms.push(3);
    ms.push(2);
    ms.push(2);
    ms.pop();
    assert(ms.getMin() == 2);
    ms.pop();
    assert(ms.getMin() == 3);
    std::cout << "test_duplicate_min passed\n";
}

int main() {
    test_basic_min();
    test_pop_resets_min();
    test_empty_pop();
    test_decreasing_sequence();
    test_duplicate_min();
    std::cout << "All tests passed!\n";
    return 0;
}
