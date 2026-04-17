#include "file_finder_lib.h"
#include <filesystem>
#include <regex>
#include <algorithm>

namespace fs = std::filesystem;

namespace file_finder {

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

std::string format_size(long long bytes) {
    if (bytes < 1024) return std::to_string(bytes) + " B";
    if (bytes < 1024 * 1024) return std::to_string(bytes / 1024) + " KB";
    return std::to_string(bytes / (1024 * 1024)) + " MB";
}

std::vector<std::string> find_files(
    const std::string& root_dir,
    const std::string& pattern,
    bool recursive) {
    std::vector<std::string> results;
    try {
        if (recursive) {
            for (const auto& entry : fs::recursive_directory_iterator(root_dir)) {
                if (entry.is_regular_file()) {
                    std::string filename = entry.path().filename().string();
                    if (match_pattern(filename, pattern)) {
                        results.push_back(entry.path().string());
                    }
                }
            }
        } else {
            for (const auto& entry : fs::directory_iterator(root_dir)) {
                if (entry.is_regular_file()) {
                    std::string filename = entry.path().filename().string();
                    if (match_pattern(filename, pattern)) {
                        results.push_back(entry.path().string());
                    }
                }
            }
        }
    } catch (const fs::filesystem_error&) {
        // Ignore permission errors and return what we have
    }
    return results;
}

} // namespace file_finder
