# Issue #62 需求规格说明书

## 概述

本需求旨在为项目添加一个 C++ 字符串反转工具，实现通用的字符串反转功能。

## 需求描述

在 `src/string_reverse.cpp` 中实现一个字符串反转工具。

## 功能要求

实现以下函数：

```cpp
// 反转字符串
std::string reverse_string(const std::string& s);
```

## 技术规范

- **语言**: C++17 (g++ -std=c++17)
- **头文件**: 无独立头文件，函数直接在 .cpp 中实现
- **命名空间**: 无

## 验收标准

| 用例 | 输入 | 预期输出 |
|------|------|----------|
| 普通字符串 | `"hello"` | `"olleh"` |
| 空字符串 | `""` | `""` |
| 单字符 | `"a"` | `"a"` |
| 回文 | `"level"` | `"level"` |
| 中文字符串 | `"你好"` | `"好你"` |

## 实现方案

使用 std::string 的反转方法：

```cpp
std::string reverse_string(const std::string& s) {
    std::string result = s;
    std::reverse(result.begin(), result.end());
    return result;
}
```

需要包含头文件：`<algorithm>` 和 `<string>`

## 测试验证

编译命令：`g++ -std=c++17 src/string_reverse.cpp -o /tmp/string_reverse`

测试用例覆盖：
1. 普通英文字符串
2. 空字符串边界
3. 单字符边界
4. 回文字符串
5. 多字节字符（UTF-8）

## 依赖

- `<algorithm>` - std::reverse
- `<string>` - std::string
