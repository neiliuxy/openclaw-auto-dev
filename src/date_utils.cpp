#include "date_utils.h"
#include <chrono>
#include <ctime>
#include <sstream>
#include <iomanip>
#include <cstring>

namespace date_utils {

uint64_t get_current_timestamp_sec() {
    auto now = std::chrono::system_clock::now();
    return std::chrono::duration_cast<std::chrono::seconds>(now.time_since_epoch()).count();
}

uint64_t get_current_timestamp_ms() {
    auto now = std::chrono::system_clock::now();
    return std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count();
}

std::string timestamp_to_string(uint64_t ts, const std::string& format) {
    std::time_t time = static_cast<std::time_t>(ts);
    std::tm* tm_ptr = std::localtime(&time);
    if (!tm_ptr) return "";
    char buffer[128];
    if (std::strftime(buffer, sizeof(buffer), format.c_str(), tm_ptr) == 0) return "";
    return std::string(buffer);
}

std::string timestamp_ms_to_string(uint64_t ts_ms, const std::string& format) {
    return timestamp_to_string(ts_ms / 1000, format);
}

uint64_t string_to_timestamp(const std::string& str, const std::string& format) {
    std::istringstream ss(str);
    std::tm tm = {};
    ss >> std::get_time(&tm, format.c_str());
    if (ss.fail()) return 0;
    std::time_t time = std::mktime(&tm);
    if (time == -1) return 0;
    return static_cast<uint64_t>(time);
}

uint64_t string_to_timestamp_ms(const std::string& str, const std::string& format) {
    return string_to_timestamp(str, format) * 1000;
}

bool is_leap_year(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
}

std::string add_days(const std::string& date_str, int days, const std::string& format) {
    std::istringstream ss(date_str);
    std::tm tm = {};
    ss >> std::get_time(&tm, format.c_str());
    if (ss.fail()) return "";

    std::time_t time = std::mktime(&tm);
    if (time == -1) return "";

    time += days * 86400;
    std::tm* result_tm = std::localtime(&time);
    if (!result_tm) return "";

    char buffer[128];
    if (std::strftime(buffer, sizeof(buffer), format.c_str(), result_tm) == 0) return "";
    return std::string(buffer);
}

int64_t days_between(const std::string& date1, const std::string& date2, const std::string& format) {
    std::istringstream ss1(date1);
    std::tm tm1 = {};
    ss1 >> std::get_time(&tm1, format.c_str());
    if (ss1.fail()) return 0;

    std::istringstream ss2(date2);
    std::tm tm2 = {};
    ss2 >> std::get_time(&tm2, format.c_str());
    if (ss2.fail()) return 0;

    std::time_t time1 = std::mktime(&tm1);
    std::time_t time2 = std::mktime(&tm2);
    if (time1 == -1 || time2 == -1) return 0;

    return static_cast<int64_t>((time1 - time2) / 86400);
}

}
