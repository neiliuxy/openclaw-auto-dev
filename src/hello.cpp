/**
 * OpenClaw Auto Dev - Enhanced Hello World
 * 
 * Features:
 * - Colorful ANSI terminal output
 * - Multiple greeting modes (simple, fancy, banner, matrix)
 * - ASCII art branding
 * - Command-line arguments support
 * - Interactive mode with user input
 */

#include <iostream>
#include <string>
#include <cstring>
#include <ctime>
#include <thread>
#include <chrono>
#include <cstdlib>

// ANSI color codes
#define RESET   "\033[0m"
#define RED     "\033[31m"
#define GREEN   "\033[32m"
#define YELLOW  "\033[33m"
#define BLUE    "\033[34m"
#define MAGENTA "\033[35m"
#define CYAN    "\033[36m"
#define WHITE   "\033[37m"
#define BOLD    "\033[1m"

// OpenClaw Auto Dev ASCII Art Banner
void printBanner() {
    std::cout << CYAN << BOLD;
    std::cout << "╔═══════════════════════════════════════════════════════════╗" << std::endl;
    std::cout << "║   ____                 _       ____  _          _ _       ║" << std::endl;
    std::cout << "║  / __ \\               | |     |  _ \\(_)        | | |      ║" << std::endl;
    std::cout << "║ | |  | |_ __ ___  __ _| | __ _| |_) |_  ___  __| | |      ║" << std::endl;
    std::cout << "║ | |  | | '__/ _ \\/ _` | |/ _` |  _ <| |/ _ \\/ _` | |      ║" << std::endl;
    std::cout << "║ | |__| | | |  __/ (_| | | (_| | |_) | |  __/ (_| |_|      ║" << std::endl;
    std::cout << "║  \\____/|_|  \\___|\\__,_|_|\\__,_|____/|_|\\___|\\__,_(_)      ║" << std::endl;
    std::cout << "║                                                           ║" << std::endl;
    std::cout << "║            Automated GitHub Issue Solver                  ║" << std::endl;
    std::cout << "╚═══════════════════════════════════════════════════════════╝" << std::endl;
    std::cout << RESET << std::endl;
}

// Simple mode - basic greeting
void modeSimple(const std::string& name) {
    std::cout << GREEN << BOLD << "✨ Hello, " << name << "! ✨" << RESET << std::endl;
    std::cout << "Welcome to OpenClaw Auto Dev!" << std::endl;
}

// Fancy mode - colorful greeting
void modeFancy(const std::string& name) {
    std::cout << std::endl;
    std::cout << MAGENTA << "╔════════════════════════════════════════╗" << RESET << std::endl;
    std::cout << MAGENTA << "║" << RESET << BOLD << "   🌟 Welcome, " << name << "! 🌟          " << MAGENTA << "║" << RESET << std::endl;
    std::cout << MAGENTA << "╚════════════════════════════════════════╝" << RESET << std::endl;
    std::cout << std::endl;
    std::cout << CYAN << "🤖 OpenClaw Auto Dev" << RESET << " - Your AI automation partner" << std::endl;
    std::cout << YELLOW << "🚀 Automating GitHub Issues since 2026" << RESET << std::endl;
    std::cout << std::endl;
}

// Banner mode - ASCII art
void modeBanner(const std::string& name) {
    printBanner();
    std::cout << YELLOW << BOLD << "👋 Hello, " << name << "!" << RESET << std::endl;
    std::cout << std::endl;
}

// Matrix mode - falling characters effect
void modeMatrix(const std::string& name) {
    std::cout << GREEN << BOLD;
    std::cout << "\n💻 Initializing Matrix mode..." << RESET << std::endl;
    
    std::string matrix = "OpenClaw Auto Dev ";
    for (int i = 0; i < 3; i++) {
        std::cout << GREEN;
        for (char c : matrix) {
            std::cout << c;
            std::cout.flush();
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
        }
        std::cout << RESET << std::endl;
    }
    
    std::cout << std::endl;
    std::cout << CYAN << "🌟 Hello, " << name << "! Welcome to the matrix!" << RESET << std::endl;
    std::cout << std::endl;
}

// Interactive mode - ask for user input
void modeInteractive() {
    std::string name;
    std::cout << CYAN << "🤖 OpenClaw Auto Dev: What's your name? " << RESET;
    std::getline(std::cin, name);
    
    if (name.empty()) {
        name = "Developer";
    }
    
    std::cout << std::endl;
    printBanner();
    std::cout << YELLOW << BOLD << "🎉 Nice to meet you, " << name << "!" << RESET << std::endl;
    std::cout << std::endl;
    std::cout << "💡 OpenClaw Auto Dev can help you:" << std::endl;
    std::cout << "   ✅ Automate GitHub Issue processing" << std::endl;
    std::cout << "   ✅ Validate code changes automatically" << std::endl;
    std::cout << "   ✅ Create and merge PRs intelligently" << std::endl;
    std::cout << "   ✅ Track and manage development workflow" << std::endl;
    std::cout << std::endl;
}

// Print help message
void printHelp(const char* programName) {
    std::cout << std::endl;
    std::cout << BOLD << "OpenClaw Auto Dev - Enhanced Hello World" << RESET << std::endl;
    std::cout << std::endl;
    std::cout << "Usage: " << programName << " [OPTIONS]" << std::endl;
    std::cout << std::endl;
    std::cout << "Options:" << std::endl;
    std::cout << "  -h, --help           Show this help message" << std::endl;
    std::cout << "  -n, --name <name>    Specify your name" << std::endl;
    std::cout << "  -m, --mode <mode>    Set greeting mode:" << std::endl;
    std::cout << "                       simple  - Basic greeting (default)" << std::endl;
    std::cout << "                       fancy   - Colorful greeting" << std::endl;
    std::cout << "                       banner  - ASCII art banner" << std::endl;
    std::cout << "                       matrix  - Matrix-style animation" << std::endl;
    std::cout << "                       interactive - Ask for user input" << std::endl;
    std::cout << "  -v, --version        Show version information" << std::endl;
    std::cout << std::endl;
    std::cout << "Examples:" << std::endl;
    std::cout << "  " << programName << "                           # Simple mode" << std::endl;
    std::cout << "  " << programName << " --name Alice              # Greet Alice" << std::endl;
    std::cout << "  " << programName << " --mode fancy --name Bob   # Fancy greeting for Bob" << std::endl;
    std::cout << "  " << programName << " --mode banner             # Show ASCII banner" << std::endl;
    std::cout << "  " << programName << " --mode interactive        # Interactive mode" << std::endl;
    std::cout << std::endl;
    std::cout << CYAN << "🚀 OpenClaw Auto Dev - Automating GitHub Issues" << RESET << std::endl;
    std::cout << std::endl;
}

// Print version
void printVersion() {
    std::cout << BOLD << "OpenClaw Auto Dev" << RESET << std::endl;
    std::cout << "Version: 1.0.0" << std::endl;
    std::cout << "Build Date: " << __DATE__ << " " << __TIME__ << std::endl;
    std::cout << std::endl;
}

// Get current time-based greeting
std::string getTimeGreeting() {
    time_t now = time(0);
    tm* localtm = localtime(&now);
    
    if (localtm->tm_hour < 12) {
        return "☀️ Good morning";
    } else if (localtm->tm_hour < 18) {
        return "🌤️ Good afternoon";
    } else {
        return "🌙 Good evening";
    }
}

int main(int argc, char* argv[]) {
    std::string name = "World";
    std::string mode = "simple";
    
    // Parse command-line arguments
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        
        if (arg == "-h" || arg == "--help") {
            printHelp(argv[0]);
            return 0;
        }
        else if (arg == "-v" || arg == "--version") {
            printVersion();
            return 0;
        }
        else if (arg == "-n" || arg == "--name") {
            if (i + 1 < argc) {
                name = argv[++i];
            } else {
                std::cerr << RED << "Error: --name requires an argument" << RESET << std::endl;
                return 1;
            }
        }
        else if (arg == "-m" || arg == "--mode") {
            if (i + 1 < argc) {
                mode = argv[++i];
            } else {
                std::cerr << RED << "Error: --mode requires an argument" << RESET << std::endl;
                return 1;
            }
        }
        else {
            std::cerr << RED << "Error: Unknown option '" << arg << "'" << RESET << std::endl;
            std::cerr << "Use --help for usage information" << std::endl;
            return 1;
        }
    }
    
    // Execute based on mode
    if (mode == "simple") {
        std::cout << getTimeGreeting() << ", " << name << "!" << std::endl;
        modeSimple(name);
    }
    else if (mode == "fancy") {
        modeFancy(name);
    }
    else if (mode == "banner") {
        modeBanner(name);
    }
    else if (mode == "matrix") {
        modeMatrix(name);
    }
    else if (mode == "interactive") {
        modeInteractive();
    }
    else {
        std::cerr << RED << "Error: Unknown mode '" << mode << "'" << RESET << std::endl;
        std::cerr << "Valid modes: simple, fancy, banner, matrix, interactive" << std::endl;
        return 1;
    }
    
    return 0;
}
