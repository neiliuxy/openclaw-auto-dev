#ifndef DATE_UTILS_H
#define DATE_UTILS_H

#include <cstdint>
#include <string>

namespace date_utils {

uint64_t get_current_timestamp_sec();
uint64_t get_current_timestamp_ms();

std::string timestamp_to_string(uint64_t ts, const std::string& format = "%Y-%m-%d %H:%M:%S");
std::string timestamp_ms_to_string(uint64_t ts_ms, const std::string& format = "%Y-%m-%d %H:%M:%S");

uint64_t string_to_timestamp(const std::string& str, const std::string& format = "%Y-%m-%d %H:%M:%S");
uint64_t string_to_timestamp_ms(const std::string& str, const std::string& format = "%Y-%m-%d %H:%M:%S");

std::string add_days(const std::string& date_str, int days, const std::string& format = "%Y-%m-%d");
int64_t days_between(const std::string& date1, const std::string& date2, const std::string& format = "%Y-%m-%d");

bool is_leap_year(int year);

}

#endif
