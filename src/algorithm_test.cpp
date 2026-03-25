// Issue #112: 架构改进 - 算法库单元测试
// 测试 quick_sort, matrix, string_utils 算法实现

#include "quick_sort.h"
#include "matrix.h"
#include "string_utils.h"
#include <iostream>
#include <cassert>
#include <vector>
#include <cstring>

using namespace std;

void test_quicksort_basic() {
    std::vector<int> arr = {5, 2, 9, 1, 5, 6};
    std::vector<int> expected = {1, 2, 5, 5, 6, 9};
    quick_sort(arr, 0, arr.size() - 1);
    assert(arr == expected);
    std::cout << "✅ quicksort_basic passed\n";
}

void test_quicksort_empty() {
    std::vector<int> arr;
    quick_sort(arr, 0, arr.size() - 1);
    assert(arr.empty());
    std::cout << "✅ quicksort_empty passed\n";
}

void test_quicksort_single() {
    std::vector<int> arr = {42};
    quick_sort(arr, 0, arr.size() - 1);
    assert(arr[0] == 42);
    std::cout << "✅ quicksort_single passed\n";
}

void test_quicksort_sorted() {
    std::vector<int> arr = {1, 2, 3, 4, 5};
    std::vector<int> expected = {1, 2, 3, 4, 5};
    quick_sort(arr, 0, arr.size() - 1);
    assert(arr == expected);
    std::cout << "✅ quicksort_sorted passed\n";
}

void test_quicksort_reverse() {
    std::vector<int> arr = {5, 4, 3, 2, 1};
    std::vector<int> expected = {1, 2, 3, 4, 5};
    quick_sort(arr, 0, arr.size() - 1);
    assert(arr == expected);
    std::cout << "✅ quicksort_reverse passed\n";
}

void test_quicksort_duplicates() {
    std::vector<int> arr = {3, 3, 3, 3};
    quick_sort(arr, 0, arr.size() - 1);
    assert(arr[0] == 3 && arr[3] == 3);
    std::cout << "✅ quicksort_duplicates passed\n";
}

void test_matrix_multiply_basic() {
    std::vector<std::vector<int>> A = {{1, 2}, {3, 4}};
    std::vector<std::vector<int>> B = {{5, 6}, {7, 8}};
    std::vector<std::vector<int>> C = multiply(A, B);
    // 1*5+2*7=19, 1*6+2*8=22
    // 3*5+4*7=43, 3*6+4*8=50
    assert(C[0][0] == 19); assert(C[0][1] == 22);
    assert(C[1][0] == 43); assert(C[1][1] == 50);
    std::cout << "✅ matrix_multiply_basic passed\n";
}

void test_matrix_multiply_identity() {
    std::vector<std::vector<int>> A = {{1, 2}, {3, 4}};
    std::vector<std::vector<int>> I = {{1, 0}, {0, 1}};
    std::vector<std::vector<int>> C = multiply(A, I);
    assert(C == A);
    std::cout << "✅ matrix_multiply_identity passed\n";
}

void test_string_trim() {
    using namespace string_utils;
    assert(trim("  hello  ") == "hello");
    assert(trim("hello") == "hello");
    assert(trim("") == "");
    assert(trim("   ") == "");
    std::cout << "✅ string_trim passed\n";
}

void test_string_split() {
    using namespace string_utils;
    std::vector<std::string> parts = split("a,b,c", ',');
    assert(parts.size() == 3);
    assert(parts[0] == "a" && parts[1] == "b" && parts[2] == "c");
    std::cout << "✅ string_split passed\n";
}

void test_string_to_lower() {
    using namespace string_utils;
    assert(to_lower("HELLO") == "hello");
    assert(to_lower("HeLLo") == "hello");
    std::cout << "✅ string_to_lower passed\n";
}

void test_string_to_upper() {
    using namespace string_utils;
    assert(to_upper("hello") == "HELLO");
    assert(to_upper("HeLLo") == "HELLO");
    std::cout << "✅ string_to_upper passed\n";
}

void test_string_starts_with() {
    using namespace string_utils;
    assert(starts_with("hello world", "hello"));
    assert(!starts_with("hello world", "world"));
    std::cout << "✅ string_starts_with passed\n";
}

void test_string_ends_with() {
    using namespace string_utils;
    assert(ends_with("hello world", "world"));
    assert(!ends_with("hello world", "hello"));
    std::cout << "✅ string_ends_with passed\n";
}

int main() {
    std::cout << "=== Algorithm Library Tests ===\n";
    
    // quick_sort tests
    std::cout << "\n--- quick_sort ---\n";
    test_quicksort_basic();
    test_quicksort_empty();
    test_quicksort_single();
    test_quicksort_sorted();
    test_quicksort_reverse();
    test_quicksort_duplicates();
    
    // matrix tests
    std::cout << "\n--- matrix ---\n";
    test_matrix_multiply_basic();
    test_matrix_multiply_identity();
    
    // string_utils tests
    std::cout << "\n--- string_utils ---\n";
    test_string_trim();
    test_string_split();
    test_string_to_lower();
    test_string_to_upper();
    test_string_starts_with();
    test_string_ends_with();
    
    std::cout << "\n=== All Tests Passed ===\n";
    return 0;
}
