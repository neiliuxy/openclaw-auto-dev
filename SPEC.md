# Issue #65 需求规格说明书

## 概述
实现矩阵乘法功能，作为 skill-test 的一部分。

## 需求
- 实现 `src/matrix.cpp`，包含标准矩阵乘法功能
- 使用 `std::vector<std::vector<int>>` 作为矩阵表示

## 函数签名
```cpp
std::vector<std::vector<int>> multiply(const std::vector<std::vector<int>>& A, 
                                        const std::vector<std::vector<int>>& B);
```

## 验收标准
- [x] 代码可编译（g++ -std=c++17）
- [x] 2x2 矩阵乘法正确

## 技术细节
- 矩阵 A: m×k, 矩阵 B: k×n
- 结果矩阵 C: m×n
- C[i][j] = Σ(A[i][k] * B[k][j])
