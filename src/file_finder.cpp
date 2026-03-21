#include <iostream>
#include <fstream>
#include <filesystem>
#include <string>
#include <vector>
#include <regex>
#include <chrono>
#include <iomanip>
#include <algorithm>

namespace fs = std::filesystem;

void print_usage(const char* prog) {
    std::cout << "Usage: " << prog << " [options]\n";
    std::cout << "Options:\n";
    std::cout << "  --name <pattern>   Search by filename pattern (e.g., *.cpp, test_*.h)\n";
    std::cout << "  --type <f|d>       Search by type: f=file, d=directory (default: f)\n";
    std::cout << "  --exclude <dir>    Exclude directory (can repeat)\n";
    std::cout << "  --max-depth <n>    Maximum directory depth (default: unlimited)\n";
    std::cout << "  -h, --help         Show this help\n";
}

bool match_pattern(const std::string& filename, const std::string& pattern) {
    // Convert glob pattern to regex
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

std::string format_size(size_t bytes) {
    if (bytes < 1024) return std::to_string(bytes) + " B";
    if (bytes < 1024 * 1024) return std::to_string(bytes / 1024) + " KB";
    return std::to_string(bytes / (1024 * 1024)) + " MB";
}

int main(int argc, char* argv[]) {
    std::string name_pattern;
    char type = 'f'; // f=file, d=directory
    std::vector<std::string> exclude_dirs;
    int max_depth = -1;
    std::string search_dir = ".";

    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--name" && i + 1 < argc) {
            name_pattern = argv[++i];
        } else if (arg == "--type" && i + 1 < argc) {
            std::string t = argv[++i];
            if (t == "f" || t == "file") type = 'f';
            else if (t == "d" || t == "dir") type = 'd';
        } else if (arg == "--exclude" && i + 1 < argc) {
            exclude_dirs.push_back(argv[++i]);
        } else if (arg == "--max-depth" && i + 1 < argc) {
            max_depth = std::stoi(argv[++i]);
        } else if (arg == "-h" || arg == "--help") {
            print_usage(argv[0]);
            return 0;
        } else if (arg == "--dir" && i + 1 < argc) {
            search_dir = argv[++i];
        } else if (arg[0] != '-') {
            search_dir = arg;
        }
    }

    if (name_pattern.empty()) {
        std::cerr << "Error: --name pattern required\n";
        print_usage(argv[0]);
        return 1;
    }

    auto start = std::chrono::high_resolution_clock::now();
    int match_count = 0;

    try {
        int base_depth = 0;
        try {
            base_depth = std::distance(search_dir.begin(), search_dir.end());
            // Find common base
            fs::path p = fs::absolute(search_dir);
            base_depth = std::distance(p.begin(), p.end());
        } catch (...) {}

        for (const auto& entry : fs::recursive_directory_iterator(search_dir)) {
            // Check depth
            if (max_depth >= 0) {
                fs::path abs_path = fs::absolute(entry.path());
                int current_depth = std::distance(fs::absolute(search_dir).begin(), abs_path.begin());
                if (current_depth > max_depth + base_depth) continue;
            }

            // Check type
            bool is_file = entry.is_regular_file();
            bool is_dir = entry.is_directory();
            if (type == 'f' && !is_file) continue;
            if (type == 'd' && !is_dir) continue;

            // Check exclude
            bool excluded = false;
            std::string path_str = entry.path().string();
            for (const auto& excl : exclude_dirs) {
                if (path_str.find(excl) != std::string::npos) {
                    excluded = true;
                    break;
                }
            }
            if (excluded) continue;

            // Check name pattern
            std::string filename = entry.path().filename().string();
            if (!match_pattern(filename, name_pattern)) continue;

            // Output
            if (is_file) {
                size_t size = entry.file_size();
                std::cout << path_str << " (" << format_size(size) << ")\n";
            } else {
                std::cout << path_str << "/\n";
            }
            match_count++;
        }
    } catch (const fs::filesystem_error& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }

    auto end = std::chrono::high_resolution_clock::now();
    double duration = std::chrono::duration<double>(end - start).count();

    std::cout << "Found " << match_count << " files in " << std::fixed << std::setprecision(2) << duration << "s\n";

    return 0;
}
