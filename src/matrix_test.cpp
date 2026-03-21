#include <iostream>
#include <vector>
#include "matrix.h"

int main() {
    // Test 2x2 matrix multiplication
    std::vector<std::vector<int>> A = {{1, 2}, {3, 4}};
    std::vector<std::vector<int>> B = {{5, 6}, {7, 8}};
    
    auto C = multiply(A, B);
    
    // Expected: [[19, 22], [43, 50]]
    // 1*5+2*7=19, 1*6+2*8=22
    // 3*5+4*7=43, 3*6+4*8=50
    if (C[0][0] == 19 && C[0][1] == 22 && C[1][0] == 43 && C[1][1] == 50) {
        std::cout << "2x2 matrix multiplication: PASSED" << std::endl;
        return 0;
    } else {
        std::cout << "FAILED" << std::endl;
        return 1;
    }
}
