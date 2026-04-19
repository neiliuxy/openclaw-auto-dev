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

void test_empty_top_throws() {
    MinStack ms;
    bool caught = false;
    try {
        ms.top();
    } catch (const std::runtime_error& e) {
        caught = true;
    }
    assert(caught);
    std::cout << "test_empty_top_throws passed\n";
}

void test_empty_getmin_throws() {
    MinStack ms;
    bool caught = false;
    try {
        ms.getMin();
    } catch (const std::runtime_error& e) {
        caught = true;
    }
    assert(caught);
    std::cout << "test_empty_getmin_throws passed\n";
}

void test_empty_pop_no_throw() {
    MinStack ms;
    ms.pop();
    std::cout << "test_empty_pop_no_throw passed\n";
}

void test_negative_numbers() {
    MinStack ms;
    ms.push(-1);
    ms.push(-3);
    ms.pop();
    assert(ms.getMin() == -1);
    assert(ms.top() == -1);
    std::cout << "test_negative_numbers passed\n";
}

void test_mixed_zero_negative() {
    MinStack ms;
    ms.push(0);
    ms.push(-1);
    ms.push(0);
    ms.pop();
    assert(ms.getMin() == -1);
    assert(ms.top() == -1);
    std::cout << "test_mixed_zero_negative passed\n";
}

// T4: push(5), push(3), push(7), push(3), getMin -> 3, top -> 3
void test_decreasing_and_rising() {
    MinStack ms;
    ms.push(5);
    ms.push(3);
    ms.push(7);
    ms.push(3);
    assert(ms.getMin() == 3);
    assert(ms.top() == 3);
    std::cout << "test_decreasing_and_rising passed\n";
}

// T5: push(1), push(2), push(1), pop(), getMin -> 1, top -> 2
void test_duplicate_min_after_pop() {
    MinStack ms;
    ms.push(1);
    ms.push(2);
    ms.push(1);
    ms.pop();
    assert(ms.getMin() == 1);
    assert(ms.top() == 2);
    std::cout << "test_duplicate_min_after_pop passed\n";
}

int main() {
    test_basic_min();
    test_pop_resets_min();
    test_empty_pop();
    test_decreasing_sequence();
    test_duplicate_min();
    test_empty_top_throws();
    test_empty_getmin_throws();
    test_empty_pop_no_throw();
    test_negative_numbers();
    test_mixed_zero_negative();
    test_decreasing_and_rising();
    test_duplicate_min_after_pop();
    std::cout << "All tests passed!\n";
    return 0;
}
