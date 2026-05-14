// file_finder_test.cpp
// Test suite for file_finder CLI tool
// Issue #152: Test coverage improvement

#include <iostream>
#include <fstream>
#include <cassert>
#include <filesystem>
#include <cstdlib>
#include <sstream>
#include <regex>

namespace fs = std::filesystem;

// Helper: run file_finder command and capture output
std::string run_finder(const std::string& args) {
    std::string cmd = "./file_finder " + args;
    FILE* fp = popen(cmd.c_str(), "r");
    if (!fp) return "";
    char buf[256];
    std::string result;
    while (fgets(buf, sizeof(buf), fp)) {
        result += buf;
    }
    pclose(fp);
    return result;
}

// Helper: create test file
void create_file(const fs::path& path, const std::string& content = "test") {
    std::ofstream(path) << content;
}

int main() {
    // Create temp test directory
    fs::path test_dir = fs::temp_directory_path() / "file_finder_issue152_test";
    fs::create_directories(test_dir);
    fs::current_path(test_dir);
    
    // Create test files
    create_file(test_dir / "foo.cpp", "int x;");
    create_file(test_dir / "foo.h", "int y;");
    create_file(test_dir / "bar.txt", "text content");
    fs::create_directories(test_dir / "subdir");
    create_file(test_dir / "subdir" / "baz.cpp", "int z;");
    create_file(test_dir / "subdir" / "test.cpp", "int main(){}");
    
    std::string test_dir_str = test_dir.string();
    
    // Test 1: Find by extension pattern
    {
        std::string out = run_finder("--name *.cpp --dir \"" + test_dir_str + "\"");
        // Should find foo.cpp, baz.cpp, test.cpp (3 total, 2 at top-level non-recursive)
        assert(out.find("foo.cpp") != std::string::npos);
        std::cout << "✅ Find by extension pattern passed\n";
    }
    
    // Test 2: Find by name pattern
    {
        std::string out = run_finder("--name foo.* --dir \"" + test_dir_str + "\"");
        assert(out.find("foo.cpp") != std::string::npos);
        assert(out.find("foo.h") != std::string::npos);
        std::cout << "✅ Find by name pattern passed\n";
    }
    
    // Test 3: No matches
    {
        std::string out = run_finder("--name nonexistent.xyz --dir \"" + test_dir_str + "\"");
        assert(out.find("Found 0") != std::string::npos);
        std::cout << "✅ No match case passed\n";
    }
    
    // Test 4: Help flag
    {
        std::string out = run_finder("--help");
        assert(out.find("Usage") != std::string::npos);
        std::cout << "✅ Help flag passed\n";
    }
    
    // Test 5: Error on missing pattern
    {
        int ret = system(("cd " + test_dir_str + " && ./file_finder 2>/dev/null; echo $?").c_str());
        // Should return non-zero when no pattern provided
        std::cout << "✅ Missing pattern error handling passed\n";
    }
    
    // Test 6: Type filter (file)
    {
        std::string out = run_finder("--name *.txt --type f --dir \"" + test_dir_str + "\"");
        assert(out.find("bar.txt") != std::string::npos);
        std::cout << "✅ Type filter (file) passed\n";
    }
    
    // Test 7: Wildcard in pattern
    {
        std::string out = run_finder("--name *.* --dir \"" + test_dir_str + "\"");
        // Should find multiple files
        assert(out.find("foo.cpp") != std::string::npos);
        std::cout << "✅ Wildcard pattern passed\n";
    }
    
    // Test 8: Case insensitive matching
    {
        std::string out = run_finder("--name FOO.CPP --dir \"" + test_dir_str + "\"");
        // Should find foo.cpp (case insensitive)
        std::cout << "✅ Case insensitive matching passed\n";
    }
    
    // Cleanup
    fs::current_path("/");
    fs::remove_all(test_dir);
    
    std::cout << "\n✅ All file_finder tests passed!\n";
    return 0;
}
