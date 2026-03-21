# date_utils — C++ 日期时间工具 SPEC

## 1. 概述

| 项目 | 说明 |
|------|------|
| **名称** | date_utils |
| **类型** | C++ 工具库（`.h` + `.cpp` 分离编译形式） |
| **功能摘要** | 提供常用的日期时间操作工具：时间戳获取/转换、字符串解析、日期计算、闰年判断 |
| **目标用户** | C++ 开发者 |
| **语言标准** | C++11 及以上 |
| **外部依赖** | 仅标准库（`<chrono>`、`<ctime>`、`<string>`、`<cstdint>`、`<sstream>`、`<iomanip>`） |

---

## 2. 文件结构

```
src/
├── date_utils.h          # 接口声明
├── date_utils.cpp        # 实现
└── date_utils_test.cpp   # 单元测试（GoogleTest）
```

---

## 3. 函数接口

### 3.1 获取当前时间戳

```cpp
// 获取当前 Unix 时间戳（秒）
uint64_t get_current_timestamp_sec();

// 获取当前 Unix 时间戳（毫秒）
uint64_t get_current_timestamp_ms();
```

### 3.2 时间戳转字符串

```cpp
// 将时间戳（秒）转为指定格式字符串，默认格式 %Y-%m-%d %H:%M:%S
std::string timestamp_to_string(uint64_t ts, const std::string& format = "%Y-%m-%d %H:%M:%S");

// 将时间戳（毫秒）转为指定格式字符串，默认格式 %Y-%m-%d %H:%M:%S
std::string timestamp_ms_to_string(uint64_t ts_ms, const std::string& format = "%Y-%m-%d %H:%M:%S");
```

**默认格式示例**：`2026-03-21 21:48:00`

### 3.3 字符串解析为时间戳

```cpp
// 将字符串按格式解析为时间戳（秒），解析失败返回 0
uint64_t string_to_timestamp(const std::string& str, const std::string& format = "%Y-%m-%d %H:%M:%S");

// 将字符串按格式解析为时间戳（毫秒），解析失败返回 0
uint64_t string_to_timestamp_ms(const std::string& str, const std::string& format = "%Y-%m-%d %H:%M:%S");
```

### 3.4 日期计算（加减天数）

```cpp
// 返回 date_str 加上 days 天后的日期字符串（days 可为负数），默认格式 %Y-%m-%d
std::string add_days(const std::string& date_str, int days, const std::string& format = "%Y-%m-%d");

// 返回两个日期之间的天数差（date1 - date2），默认格式 %Y-%m-%d
int64_t days_between(const std::string& date1, const std::string& date2, const std::string& format = "%Y-%m-%d");
```

### 3.5 判断闰年

```cpp
// 判断是否闰年，返回 true 表示闰年
bool is_leap_year(int year);
```

**闰年规则（公历）**：
- 能被 4 整除 且 不能被 100 整除，或
- 能被 400 整除

---

## 4. 验收标准

- [ ] `get_current_timestamp_sec()` 实现并返回 > 0 的时间戳
- [ ] `get_current_timestamp_ms()` 实现并返回 > 0 的毫秒级时间戳
- [ ] `timestamp_to_string()` 实现，支持自定义格式，默认格式正确
- [ ] `timestamp_ms_to_string()` 实现，支持自定义格式，默认格式正确
- [ ] `string_to_timestamp()` 实现，解析失败返回 0
- [ ] `string_to_timestamp_ms()` 实现，解析失败返回 0
- [ ] `add_days()` 实现，支持正负天数
- [ ] `days_between()` 实现，返回正确天数差
- [ ] `is_leap_year()` 实现，闰年规则正确
- [ ] 编译通过无警告（`-Wall -Wextra -std=c++11`）
- [ ] 单元测试全部通过

---

## 5. 单元测试用例

| 用例 | 函数 | 描述 | 预期结果 |
|------|------|------|----------|
| T1 | `get_current_timestamp_sec` | 调用返回值 > 0 | 通过 |
| T2 | `get_current_timestamp_ms` | 毫秒值 > 秒级时间戳 × 1000 | 通过 |
| T3 | `timestamp_to_string` | 输入 0，默认格式 | 返回 "1970-01-01 08:00:00"（本地时区） |
| T4 | `timestamp_to_string` | 输入 1735689600（2024-12-31 16:00:00 UTC），格式 `%Y-%m-%d` | 返回 "2025-01-01" |
| T5 | `timestamp_ms_to_string` | 毫秒时间戳转换 | 正确对应秒级值 |
| T6 | `string_to_timestamp` | 解析 "2026-03-21 21:48:00" | 返回对应秒级时间戳 |
| T7 | `string_to_timestamp` | 解析非法字符串 | 返回 0 |
| T8 | `string_to_timestamp_ms` | 解析 "2026-03-21 21:48:00" | 返回对应毫秒时间戳 |
| T9 | `add_days` | `"2026-03-01", +1` | 返回 "2026-03-02" |
| T10 | `add_days` | `"2026-03-01", -1` | 返回 "2026-02-28" |
| T11 | `add_days` | `"2024-02-28", +1`（闰年） | 返回 "2024-02-29" |
| T12 | `add_days` | `"2024-12-31", +1`（闰年） | 返回 "2025-01-01" |
| T13 | `add_days` | `"2026-03-21", -20` | 返回 "2026-03-01" |
| T14 | `days_between` | `"2026-03-21", "2026-03-01"` | 返回 20 |
| T15 | `days_between` | `"2026-03-01", "2026-03-21"` | 返回 -20 |
| T16 | `days_between` | 相同日期 | 返回 0 |
| T17 | `is_leap_year` | 2024（能被4整除，不能被100整除） | 返回 true |
| T18 | `is_leap_year` | 2025 | 返回 false |
| T19 | `is_leap_year` | 2000（能被400整除） | 返回 true |
| T20 | `is_leap_year` | 1900（能被100整除但不能被400整除） | 返回 false |
| T21 | `is_leap_year` | 2100 | 返回 false |

---

## 6. 技术约束

1. **编译命令**：`g++ -std=c++11 -Wall -Wextra -I./src src/date_utils.cpp src/date_utils_test.cpp -o date_utils_test`
2. **线程安全**：`get_current_timestamp_*` 使用 `std::chrono::system_clock`，线程安全
3. **错误处理**：解析失败时返回 0（调用方需自行判断合法 0 值与解析失败）
4. **时区**：所有时间戳基于 Unix Epoch（UTC），字符串输出按本地时区
5. **格式兼容**：format 字符串兼容 `strftime`/`strptime` 规范

---

## 7. 构建方式

```bash
# 编译
g++ -std=c++11 -Wall -Wextra -I./src src/date_utils.cpp src/date_utils_test.cpp -o date_utils_test

# 运行测试
./date_utils_test
```

如项目已有 Makefile/CMake，则在 Makefile/CMakeLists.txt 中添加对应 target。
