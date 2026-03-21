# Issue #30 需求规格说明书

## 1. 概述
- **Issue**: #30
- **标题**: feat: 添加 C++ 字符串处理工具 string_utils
- **处理时间**: 2026-03-21

## 2. 功能点拆解

| ID | 功能点 | 验收标准 |
|----|--------|----------|
| F01 | trim() 去除首尾空白 | trim("  hello  ") == "hello" |
| F02 | split() 按分隔符分割 | split("a,b,c", ',') 返回 ["a","b","c"] |
| F03 | join() 合并字符串数组 | join(["a","b"], "-") == "a-b" |
| F04 | to_lower() / to_upper() | 大小写转换正确 |
| F05 | starts_with() / ends_with() | 前缀后缀判断正确 |
| F06 | replace() 字符串替换 | replace("aaa","a","b") == "bbb" |
| F07 | is_numeric() 数字判断 | is_numeric("123")==true, is_numeric("12a")==false |
| F08 | 头文件设计合理 | 可被其他模块 include 使用 |
| F09 | 编译通过无警告 | g++ -std=c++17 -fsyntax-only 通过 |

## 3. 技术方案

### 3.1 文件结构
```
src/
├── string_utils.h      # 头文件（接口声明）
├── string_utils.cpp    # 实现
└── string_utils_test.cpp # 单元测试
```

### 3.2 命名空间
`string_utils` 命名空间，避免与其他模块冲突

## 4. 验收标准
- [x] F01-F07: 所有函数实现正确
- [x] F08: 头文件设计合理，可复用
- [x] F09: 编译通过无警告
