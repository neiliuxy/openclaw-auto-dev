#ifndef LOGGER_H
#define LOGGER_H

#include <string>
#include <memory>

namespace logger {

enum class Level {
    DEBUG = 0,
    INFO  = 1,
    WARN  = 2,
    ERROR = 3,
    FATAL = 4
};

// Alias for spec compatibility
using LogLevel = Level;

class Logger {
public:
    // Construct with file + min level
    Logger(const std::string& filepath, Level min_level = Level::INFO);

    // Destructor
    ~Logger();

    // Disable copy
    Logger(const Logger&) = delete;
    Logger& operator=(const Logger&) = delete;

    // Log methods
    void debug(const char* fmt, ...);
    void info(const char* fmt, ...);
    void warn(const char* fmt, ...);
    void error(const char* fmt, ...);
    void fatal(const char* fmt, ...);

    // Set minimum log level
    void set_level(Level level);

    // Flush buffer
    void flush();

private:
    struct Impl;
    std::unique_ptr<Impl> p_;
};

} // namespace logger

#endif // LOGGER_H
