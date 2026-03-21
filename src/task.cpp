#include <iostream>
#include <fstream>
#include <filesystem>
#include <map>
#include <string>
#include <sstream>
#include <iomanip>
#include <algorithm>

namespace fs = std::filesystem;

void print_usage(const char* prog) {
    std::cout << "Usage: " << prog << " [options]\n";
    std::cout << "Options:\n";
    std::cout << "  --dir <path>     Directory to scan (default: .)\n";
    std::cout << "  --ext <ext>      File extensions to include (e.g., .cpp,.h)\n";
    std::cout << "  --exclude <dir>  Directories to exclude (e.g., .git,build)\n";
    std::cout << "  -h, --help       Show this help\n";
}

bool should_exclude(const std::string& path, const std::vector<std::string>& exclude_dirs) {
    for (const auto& excl : exclude_dirs) {
        if (path.find(excl) != std::string::npos) {
            return true;
        }
    }
    return false;
}

std::string get_extension(const std::string& path) {
    size_t pos = path.rfind('.');
    if (pos != std::string::npos && pos != path.size() - 1) {
        return path.substr(pos);
    }
    return "";
}

int count_lines(const std::string& filepath) {
    std::ifstream file(filepath);
    if (!file.is_open()) return 0;
    int lines = 0;
    std::string line;
    while (std::getline(file, line)) {
        lines++;
    }
    return lines;
}

int main(int argc, char* argv[]) {
    std::string dir_path = ".";
    std::string extensions = ".cpp,.h,.py,.js,.ts,.md,.txt,.sh,.java,.go,.rs";
    std::vector<std::string> exclude_dirs = {".git", "build", "node_modules", ".svn", "__pycache__", "dist", "target"};
    
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--dir" && i + 1 < argc) {
            dir_path = argv[++i];
        } else if (arg == "--ext" && i + 1 < argc) {
            extensions = argv[++i];
        } else if (arg == "--exclude" && i + 1 < argc) {
            exclude_dirs.push_back(argv[++i]);
        } else if (arg == "-h" || arg == "--help") {
            print_usage(argv[0]);
            return 0;
        }
    }
    
    // Parse extensions
    std::map<std::string, int> ext_lines;
    std::map<std::string, int> ext_files;
    int total_lines = 0;
    int total_files = 0;
    
    std::vector<std::string> exts;
    std::stringstream ss(extensions);
    std::string ext;
    while (std::getline(ss, ext, ',')) {
        exts.push_back(ext);
    }
    
    try {
        for (const auto& entry : fs::recursive_directory_iterator(dir_path)) {
            if (!entry.is_regular_file()) continue;
            
            std::string path = entry.path().string();
            if (should_exclude(path, exclude_dirs)) continue;
            
            std::string file_ext = get_extension(entry.path().string());
            
            bool matches = false;
            for (const auto& e : exts) {
                if (e == file_ext) {
                    matches = true;
                    break;
                }
            }
            if (!matches && !exts.empty()) continue;
            
            int lines = count_lines(path);
            if (lines > 0) {
                ext_lines[file_ext] += lines;
                ext_files[file_ext]++;
                total_lines += lines;
                total_files++;
            }
        }
    } catch (const fs::filesystem_error& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
    
    // Output results
    std::cout << "Files: " << total_files << "\n";
    std::cout << "Lines: " << total_lines << "\n";
    
    for (const auto& [ext, lines] : ext_lines) {
        double pct = (total_lines > 0) ? (100.0 * lines / total_lines) : 0;
        std::cout << ext << ": " << lines << " (" << std::fixed << std::setprecision(0) << pct << "%)\n";
    }
    
    return 0;
}
