// file_finder_test.cpp - Unit tests for file_finder_lib
// Tests the pattern matching and file search functionality from file_finder_lib

#include "file_finder_lib.h"
#include <iostream>
#include <cassert>
#include <fstream>
#include <filesystem>
#include <string>
#include <vector>
#include <cstdlib>
#include <algorithm>
#include <unistd.h>

namespace fs = std::filesystem;
using file_finder::match_pattern;
using file_finder::format_size;
using file_finder::find_files;

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

void test_find_files_basic() {
    // Create temp directory structure
    std::string test_dir = "/tmp/file_finder_test_" + std::to_string(getpid());
    fs::create_directories(test_dir + "/subdir");
    
    // Create test files
    std::ofstream(test_dir + "/file1.cpp") << "// test";
    std::ofstream(test_dir + "/file2.h") << "// test";
    std::ofstream(test_dir + "/subdir/file3.cpp") << "// test";
    
    // Test recursive search
    auto results = find_files(test_dir, "*.cpp", true);
    assert(results.size() == 2); // file1.cpp and subdir/file3.cpp
    std::cout << "✅ find_files_basic passed\n";
    
    // Test non-recursive search
    auto results_nr = find_files(test_dir, "*.cpp", false);
    assert(results_nr.size() == 1); // only file1.cpp
    std::cout << "✅ find_files_non_recursive passed\n";
    
    // Cleanup
    fs::remove_all(test_dir);
}

void test_find_files_no_match() {
    std::string test_dir = "/tmp/file_finder_test_nomatch_" + std::to_string(getpid());
    fs::create_directories(test_dir);
    std::ofstream(test_dir + "/file1.txt") << "test";
    
    auto results = find_files(test_dir, "*.cpp", true);
    assert(results.empty());
    std::cout << "✅ find_files_no_match passed\n";
    
    fs::remove_all(test_dir);
}

int main() {
    std::cout << "=== file_finder_lib Unit Tests ===\n\n";
    
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
    
    std::cout << "\n--- File Finding Tests ---\n";
    test_find_files_basic();
    test_find_files_no_match();
    
    std::cout << "\n=== All Tests Passed ===\n";
    return 0;
}
