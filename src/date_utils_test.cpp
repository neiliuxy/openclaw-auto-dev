#include "date_utils.h"
#include <iostream>
#include <cassert>
#include <cstring>

using namespace date_utils;

void test_get_current_timestamp_sec() {
    uint64_t ts = get_current_timestamp_sec();
    assert(ts > 0);
    std::cout << "✅ T1 get_current_timestamp_sec passed\n";
}

void test_get_current_timestamp_ms() {
    uint64_t ts_ms = get_current_timestamp_ms();
    uint64_t ts_sec = get_current_timestamp_sec();
    assert(ts_ms > ts_sec * 1000);
    std::cout << "✅ T2 get_current_timestamp_ms passed\n";
}

void test_timestamp_to_string_T3() {
    std::string result = timestamp_to_string(0);
    std::cout << "  timestamp_to_string(0) = \"" << result << "\"\n";
    assert(result == "1970-01-01 08:00:00");
    std::cout << "✅ T3 timestamp_to_string(0) passed\n";
}

void test_timestamp_to_string_T4() {
    std::string result = timestamp_to_string(1735689600, "%Y-%m-%d");
    std::cout << "  timestamp_to_string(1735689600, %Y-%m-%d) = \"" << result << "\"\n";
    assert(result == "2025-01-01");
    std::cout << "✅ T4 timestamp_to_string(1735689600) passed\n";
}

void test_timestamp_ms_to_string_T5() {
    uint64_t ts_sec = 1735689600;
    uint64_t ts_ms = ts_sec * 1000;
    std::string result_sec = timestamp_to_string(ts_sec, "%Y-%m-%d %H:%M:%S");
    std::string result_ms = timestamp_ms_to_string(ts_ms, "%Y-%m-%d %H:%M:%S");
    assert(result_sec == result_ms);
    std::cout << "✅ T5 timestamp_ms_to_string passed\n";
}

void test_string_to_timestamp_T6() {
    uint64_t ts = string_to_timestamp("2026-03-21 21:48:00");
    std::cout << "  string_to_timestamp(\"2026-03-21 21:48:00\") = " << ts << "\n";
    assert(ts > 0);
    std::cout << "✅ T6 string_to_timestamp passed\n";
}

void test_string_to_timestamp_T7() {
    uint64_t ts = string_to_timestamp("invalid-date-string");
    assert(ts == 0);
    std::cout << "✅ T7 string_to_timestamp invalid passed\n";
}

void test_string_to_timestamp_ms_T8() {
    uint64_t ts_ms = string_to_timestamp_ms("2026-03-21 21:48:00");
    std::cout << "  string_to_timestamp_ms(\"2026-03-21 21:48:00\") = " << ts_ms << "\n";
    assert(ts_ms > 0);
    std::cout << "✅ T8 string_to_timestamp_ms passed\n";
}

void test_add_days_T9() {
    std::string result = add_days("2026-03-01", 1);
    assert(result == "2026-03-02");
    std::cout << "✅ T9 add_days +1 passed\n";
}

void test_add_days_T10() {
    std::string result = add_days("2026-03-01", -1);
    assert(result == "2026-02-28");
    std::cout << "✅ T10 add_days -1 passed\n";
}

void test_add_days_T11() {
    std::string result = add_days("2024-02-28", 1);
    assert(result == "2024-02-29");
    std::cout << "✅ T11 add_days leap year passed\n";
}

void test_add_days_T12() {
    std::string result = add_days("2024-12-31", 1);
    assert(result == "2025-01-01");
    std::cout << "✅ T12 add_days year boundary passed\n";
}

void test_add_days_T13() {
    std::string result = add_days("2026-03-21", -20);
    assert(result == "2026-03-01");
    std::cout << "✅ T13 add_days -20 passed\n";
}

void test_days_between_T14() {
    int64_t diff = days_between("2026-03-21", "2026-03-01");
    assert(diff == 20);
    std::cout << "✅ T14 days_between 20 passed\n";
}

void test_days_between_T15() {
    int64_t diff = days_between("2026-03-01", "2026-03-21");
    assert(diff == -20);
    std::cout << "✅ T15 days_between -20 passed\n";
}

void test_days_between_T16() {
    int64_t diff = days_between("2026-03-01", "2026-03-01");
    assert(diff == 0);
    std::cout << "✅ T16 days_between 0 passed\n";
}

void test_is_leap_year_T17() {
    assert(is_leap_year(2024) == true);
    std::cout << "✅ T17 is_leap_year 2024 passed\n";
}

void test_is_leap_year_T18() {
    assert(is_leap_year(2025) == false);
    std::cout << "✅ T18 is_leap_year 2025 passed\n";
}

void test_is_leap_year_T19() {
    assert(is_leap_year(2000) == true);
    std::cout << "✅ T19 is_leap_year 2000 passed\n";
}

void test_is_leap_year_T20() {
    assert(is_leap_year(1900) == false);
    std::cout << "✅ T20 is_leap_year 1900 passed\n";
}

void test_is_leap_year_T21() {
    assert(is_leap_year(2100) == false);
    std::cout << "✅ T21 is_leap_year 2100 passed\n";
}

int main() {
    std::cout << "Running date_utils tests...\n\n";
    test_get_current_timestamp_sec();
    test_get_current_timestamp_ms();
    test_timestamp_to_string_T3();
    test_timestamp_to_string_T4();
    test_timestamp_ms_to_string_T5();
    test_string_to_timestamp_T6();
    test_string_to_timestamp_T7();
    test_string_to_timestamp_ms_T8();
    test_add_days_T9();
    test_add_days_T10();
    test_add_days_T11();
    test_add_days_T12();
    test_add_days_T13();
    test_days_between_T14();
    test_days_between_T15();
    test_days_between_T16();
    test_is_leap_year_T17();
    test_is_leap_year_T18();
    test_is_leap_year_T19();
    test_is_leap_year_T20();
    test_is_leap_year_T21();
    std::cout << "\n✅ All 21 tests passed!\n";
    return 0;
}
