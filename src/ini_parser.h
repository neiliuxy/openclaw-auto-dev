#ifndef INI_PARSER_H
#define INI_PARSER_H

#include <string>
#include <map>
#include <vector>

namespace ini {

struct Section {
    std::map<std::string, std::string> values;

    std::string get(const std::string& key, const std::string& def = "") const;
    int get_int(const std::string& key, int def = 0) const;
    double get_double(const std::string& key, double def = 0.0) const;
    bool get_bool(const std::string& key, bool def = false) const;
};

class Parser {
public:
    bool load(const std::string& filepath);
    bool save(const std::string& filepath) const;
    Section& operator[](const std::string& section);
    const Section* get_section(const std::string& section) const;
    std::vector<std::string> sections() const;

private:
    std::map<std::string, Section> data_;
    std::string trim(const std::string& s) const;
};

bool parse_bool(const std::string& val);

} // namespace ini

#endif // INI_PARSER_H
