# Issue #68 - 快速排序 (Quick Sort)

## 1. 需求

实现 `src/quick_sort.cpp`，包含快速排序算法。

## 2. 函数签名

```cpp
void quick_sort(std::vector<int>& arr, int left, int right);
```

## 3. 验收标准

- [ ] 代码可编译（g++ -std=c++17）
- [ ] 排序结果正确

## 4. 实现要点

- 使用标准的快速排序分区（partition）策略
- 递归地对左右子数组排序
- 处理边界情况（left >= right 时递归终止）
