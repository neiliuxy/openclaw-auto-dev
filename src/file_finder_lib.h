#ifndef FILE_FINDER_LIB_H
#define FILE_FINDER_LIB_H

#include <string>
#include <vector>

namespace file_finder {

// Pattern matching (glob-style)
bool match_pattern(const std::string& filename, const std::string& pattern);

// Format file size to human-readable string
std::string format_size(long long bytes);

// Recursively find files matching pattern
std::vector<std::string> find_files(
    const std::string& root_dir,
    const std::string& pattern,
    bool recursive = true
);

} // namespace file_finder

#endif // FILE_FINDER_LIB_H
