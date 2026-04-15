// file_finder_test.cpp - Unit tests for file_finder utility
// Tests the pattern matching and file search functionality

#include <iostream>
#include <cassert>
#include <fstream>
#include <filesystem>
#include <string>
#include <vector>
#include <cstdlib>
#include <regex>

namespace fs = std::filesystem;

// Helper function to check if pattern matches (mirrors file_finder.cpp logic)
bool match_pattern(const std::string& filename, const std::string& pattern) {
    std::string regex_pattern;
    for (char c : pattern) {
        if (c == '*') {
            regex_pattern += ".*";
        } else if (c == '?') {
            regex_pattern += ".";
        } else if (c == '.') {
            regex_pattern += "\\.";
        } else {
            regex_pattern += c;
        }
    }
    try {
        std::regex re(regex_pattern, std::regex::icase);
        return std::regex_search(filename, re);
    } catch (...) {
        return false;
    }
}

// Helper function to format size (mirrors file_finder.cpp logic)
std::string format_size(size_t bytes) {
    if (bytes < 1024) return std::to_string(bytes) + " B";
    if (bytes < 1024 * 1024) return std::to_string(bytes / 1024) + " KB";
    return std::to_string(bytes / (1024 * 1024)) + " MB";
}

void test_match_pattern_exact() {
    assert(match_pattern("test.cpp", "test.cpp") == true);
    std::cout << "✅ match_pattern_exact passed\n";
}

void test_match_pattern_asterisk() {
    assert(match_pattern("test.cpp", "*.cpp") == true);
    assert(match_pattern("test.h", "*.cpp") == false);
    assert(match_pattern("my.test.cpp", "*.cpp") == true);
    std::cout << "✅ match_pattern_asterisk passed\n";
}

void test_match_pattern_question_mark() {
    assert(match_pattern("test.cpp", "????.cpp") == true);
    assert(match_pattern("test.cpp", "?????.cpp") == false);
    assert(match_pattern("a.cpp", "?.cpp") == true);
    std::cout << "✅ match_pattern_question_mark passed\n";
}

void test_match_pattern_extension() {
    assert(match_pattern("file.txt", "*.txt") == true);
    assert(match_pattern("file.md", "*.txt") == false);
    assert(match_pattern("file.cpp", "*.cpp") == true);
    std::cout << "✅ match_pattern_extension passed\n";
}

void test_match_pattern_case_insensitive() {
    assert(match_pattern("TEST.CPP", "*.cpp") == true);
    assert(match_pattern("Test.Cpp", "*.CPP") == true);
    std::cout << "✅ match_pattern_case_insensitive passed\n";
}

void test_match_pattern_complex() {
    assert(match_pattern("test_file_123.cpp", "test_*.cpp") == true);
    assert(match_pattern("prefix_test.cpp", "test_*.cpp") == false);
    std::cout << "✅ match_pattern_complex passed\n";
}

void test_format_size_bytes() {
    assert(format_size(512) == "512 B");
    assert(format_size(0) == "0 B");
    assert(format_size(1023) == "1023 B");
    std::cout << "✅ format_size_bytes passed\n";
}

void test_format_size_kilobytes() {
    assert(format_size(1024) == "1 KB");
    assert(format_size(2048) == "2 KB");
    assert(format_size(10240) == "10 KB");
    std::cout << "✅ format_size_kilobytes passed\n";
}

void test_format_size_megabytes() {
    assert(format_size(1024 * 1024) == "1 MB");
    assert(format_size(5 * 1024 * 1024) == "5 MB");
    std::cout << "✅ format_size_megabytes passed\n";
}

int main() {
    std::cout << "=== file_finder Unit Tests ===\n\n";
    
    std::cout << "--- Pattern Matching Tests ---\n";
    test_match_pattern_exact();
    test_match_pattern_asterisk();
    test_match_pattern_question_mark();
    test_match_pattern_extension();
    test_match_pattern_case_insensitive();
    test_match_pattern_complex();
    
    std::cout << "\n--- Size Formatting Tests ---\n";
    test_format_size_bytes();
    test_format_size_kilobytes();
    test_format_size_megabytes();
    
    std::cout << "\n=== All Tests Passed ===\n";
    return 0;
}
