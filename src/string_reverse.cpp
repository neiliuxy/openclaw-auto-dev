#include <algorithm>
#include <string>

// 反转字符串
std::string reverse_string(const std::string& s) {
    std::string result = s;
    std::reverse(result.begin(), result.end());
    return result;
}

#include <iostream>

int main() {
    // 测试用例
    std::cout << "Test 1 (hello): " << reverse_string("hello") << " (expected: olleh)" << std::endl;
    std::cout << "Test 2 (empty): '" << reverse_string("") << "' (expected: '')" << std::endl;
    std::cout << "Test 3 (a): " << reverse_string("a") << " (expected: a)" << std::endl;
    std::cout << "Test 4 (level): " << reverse_string("level") << " (expected: level)" << std::endl;
    
    return 0;
}
