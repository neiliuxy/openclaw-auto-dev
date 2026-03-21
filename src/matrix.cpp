#include "matrix.h"

std::vector<std::vector<int>> multiply(const std::vector<std::vector<int>>& A, 
                                        const std::vector<std::vector<int>>& B) {
    if (A.empty() || B.empty()) {
        throw std::invalid_argument("Matrix cannot be empty");
    }
    
    size_t m = A.size();
    size_t k = A[0].size();
    size_t n = B[0].size();
    
    if (B.size() != k) {
        throw std::invalid_argument("Matrix dimensions incompatible for multiplication");
    }
    
    std::vector<std::vector<int>> C(m, std::vector<int>(n, 0));
    
    for (size_t i = 0; i < m; ++i) {
        for (size_t j = 0; j < n; ++j) {
            for (size_t p = 0; p < k; ++p) {
                C[i][j] += A[i][p] * B[p][j];
            }
        }
    }
    
    return C;
}
