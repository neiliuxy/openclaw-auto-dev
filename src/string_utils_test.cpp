#include "string_utils.h"
#include <iostream>
#include <cassert>
#include <cstring>

using namespace string_utils;

void test_trim() {
    assert(trim("  hello  ") == "hello");
    assert(trim("hello") == "hello");
    assert(trim("  ") == "");
    std::cout << "✅ trim passed\n";
}

void test_split() {
    auto parts = split("a,b,c", ',');
    assert(parts.size() == 3);
    assert(parts[0] == "a");
    assert(parts[2] == "c");
    std::cout << "✅ split passed\n";
}

void test_join() {
    assert(join({"a", "b", "c"}, "-") == "a-b-c");
    assert(join({"hello"}, " ") == "hello");
    assert(join({}, "-") == "");
    std::cout << "✅ join passed\n";
}

void test_to_lower() {
    assert(to_lower("HELLO") == "hello");
    assert(to_lower("HeLLo") == "hello");
    std::cout << "✅ to_lower passed\n";
}

void test_to_upper() {
    assert(to_upper("hello") == "HELLO");
    assert(to_upper("HeLLo") == "HELLO");
    std::cout << "✅ to_upper passed\n";
}

void test_starts_with() {
    assert(starts_with("hello world", "hello") == true);
    assert(starts_with("hello world", "world") == false);
    std::cout << "✅ starts_with passed\n";
}

void test_ends_with() {
    assert(ends_with("hello world", "world") == true);
    assert(ends_with("hello world", "hello") == false);
    std::cout << "✅ ends_with passed\n";
}

void test_replace() {
    assert(replace("hello world", "world", "cpp") == "hello cpp");
    assert(replace("aaa", "a", "b") == "bbb");
    std::cout << "✅ replace passed\n";
}

void test_is_numeric() {
    assert(is_numeric("123") == true);
    assert(is_numeric("-456") == true);
    assert(is_numeric("+789") == true);
    assert(is_numeric("12.34") == false);
    assert(is_numeric("12a") == false);
    assert(is_numeric("") == false);
    std::cout << "✅ is_numeric passed\n";
}

int main() {
    test_trim();
    test_split();
    test_join();
    test_to_lower();
    test_to_upper();
    test_starts_with();
    test_ends_with();
    test_replace();
    test_is_numeric();
    std::cout << "\n✅ All tests passed!\n";
    return 0;
}
