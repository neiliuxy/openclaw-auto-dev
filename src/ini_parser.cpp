#include "ini_parser.h"
#include <fstream>
#include <sstream>
#include <algorithm>
#include <cctype>

namespace ini {

std::string Section::get(const std::string& key, const std::string& def) const {
    auto it = values.find(key);
    return (it != values.end()) ? it->second : def;
}

int Section::get_int(const std::string& key, int def) const {
    auto it = values.find(key);
    if (it == values.end()) return def;
    try { return std::stoi(it->second); } catch (...) { return def; }
}

double Section::get_double(const std::string& key, double def) const {
    auto it = values.find(key);
    if (it == values.end()) return def;
    try { return std::stod(it->second); } catch (...) { return def; }
}

bool Section::get_bool(const std::string& key, bool def) const {
    auto it = values.find(key);
    if (it == values.end()) return def;
    return parse_bool(it->second);
}

bool parse_bool(const std::string& val) {
    std::string v = val;
    std::transform(v.begin(), v.end(), v.begin(), ::tolower);
    return v == "true" || v == "yes" || v == "1" || v == "on";
}

std::string Parser::trim(const std::string& s) const {
    size_t start = 0;
    while (start < s.size() && std::isspace((unsigned char)s[start])) ++start;
    size_t end = s.size();
    while (end > start && std::isspace((unsigned char)s[end - 1])) --end;
    return s.substr(start, end - start);
}

bool Parser::load(const std::string& filepath) {
    std::ifstream fin(filepath);
    if (!fin) return false;

    data_.clear();
    std::string current_section;
    std::string line;

    while (std::getline(fin, line)) {
        line = trim(line);
        if (line.empty()) continue;

        // 注释 (# 或 ;)
        if (line[0] == '#' || line[0] == ';') continue;

        // Section: [sectionname] 或 [section.subsection]
        if (line[0] == '[') {
            size_t end = line.find(']', 1);
            if (end != std::string::npos) {
                current_section = trim(line.substr(1, end - 1));
                if (data_.find(current_section) == data_.end()) {
                    data_[current_section] = Section();
                }
            }
            continue;
        }

        // Key=Value
        size_t eq = line.find('=');
        if (eq != std::string::npos && !current_section.empty()) {
            std::string key = trim(line.substr(0, eq));
            std::string val = trim(line.substr(eq + 1));
            // 去除引号
            if ((val.front() == '"' && val.back() == '"') ||
                (val.front() == '\'' && val.back() == '\'')) {
                val = val.substr(1, val.size() - 2);
            }
            data_[current_section].values[key] = val;
        }
    }
    return true;
}

bool Parser::save(const std::string& filepath) const {
    std::ofstream fout(filepath);
    if (!fout) return false;
    for (const auto& sec : data_) {
        fout << "[" << sec.first << "]\n";
        for (const auto& kv : sec.second.values) {
            fout << kv.first << " = " << kv.second << "\n";
        }
        fout << "\n";
    }
    return true;
}

Section& Parser::operator[](const std::string& section) {
    return data_[section];
}

const Section* Parser::get_section(const std::string& section) const {
    auto it = data_.find(section);
    return (it != data_.end()) ? &it->second : nullptr;
}

std::vector<std::string> Parser::sections() const {
    std::vector<std::string> result;
    for (const auto& sec : data_) result.push_back(sec.first);
    return result;
}

} // namespace ini
