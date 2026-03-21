#ifndef STRING_UTILS_H
#define STRING_UTILS_H

#include <string>
#include <vector>

namespace string_utils {

// trim() - 去除首尾空白字符
std::string trim(const std::string& s);

// split() - 按分隔符分割字符串
std::vector<std::string> split(const std::string& s, char delimiter);

// join() - 将字符串数组合并
std::string join(const std::vector<std::string>& parts, const std::string& separator);

// to_lower() / to_upper() - 大小写转换
std::string to_lower(const std::string& s);
std::string to_upper(const std::string& s);

// starts_with() / ends_with() - 前缀后缀判断
bool starts_with(const std::string& s, const std::string& prefix);
bool ends_with(const std::string& s, const std::string& suffix);

// replace() - 字符串替换
std::string replace(const std::string& s, const std::string& from, const std::string& to);

// is_numeric() - 判断是否为数字
bool is_numeric(const std::string& s);

} // namespace string_utils

#endif // STRING_UTILS_H
