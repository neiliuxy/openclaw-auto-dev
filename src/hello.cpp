#include <iostream>
#include <fstream>
#include <string>
#include <map>

// Simple JSON parser for config file
std::map<std::string, std::string> parseConfig(const std::string& filename) {
    std::map<std::string, std::string> config;
    std::ifstream file(filename);
    
    if (!file.is_open()) {
        return config; // Return empty config if file doesn't exist
    }
    
    std::string line;
    std::string key, value;
    
    while (std::getline(file, line)) {
        size_t colonPos = line.find(':');
        if (colonPos != std::string::npos) {
            size_t start = line.find('"');
            size_t end = line.find('"', start + 1);
            if (start != std::string::npos && end != std::string::npos) {
                key = line.substr(start + 1, end - start - 1);
                
                start = line.find('"', colonPos + 1);
                end = line.find('"', start + 1);
                if (start != std::string::npos && end != std::string::npos) {
                    value = line.substr(start + 1, end - start - 1);
                    config[key] = value;
                }
            }
        }
    }
    return config;
}

int main(int argc, char* argv[]) {
    std::string name = "World";
    std::string mode = "simple";
    std::string configFile = "config.json";
    
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--name" && i + 1 < argc) {
            name = argv[++i];
        } else if (arg == "--mode" && i + 1 < argc) {
            mode = argv[++i];
        } else if (arg == "--config" && i + 1 < argc) {
            configFile = argv[++i];
        } else if (arg == "--help") {
            std::cout << "Usage: ./hello [options]\n";
            std::cout << "  --name <name>    Set greeting name\n";
            std::cout << "  --mode <mode>    Set mode: simple, fancy, banner\n";
            std::cout << "  --config <file>  Set config file path\n";
            std::cout << "  --help           Show this help\n";
            return 0;
        }
    }
    
    auto config = parseConfig(configFile);
    if (config.count("name")) name = config["name"];
    if (config.count("mode")) mode = config["mode"];
    
    if (mode == "fancy") {
        std::cout << "═══════════════════════════════\n";
        std::cout << "     Hello, " << name << "!\n";
        std::cout << "═══════════════════════════════\n";
    } else if (mode == "banner") {
        std::cout << "╔════════════════════════════╗\n";
        std::cout << "║    Hello, " << name << "!     ║\n";
        std::cout << "╚════════════════════════════╝\n";
    } else {
        std::cout << "Hello, " << name << "!" << std::endl;
    }
    
    return 0;
}
