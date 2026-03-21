#include "logger.h"
#include <ctime>
#include <cstdio>
#include <cstdarg>
#include <cstring>
#include <mutex>
#include <sstream>
#include <iomanip>
#include <iostream>
#include <fstream>

static const char* LEVEL_STR[] = { "DEBUG", "INFO", "WARN", "ERROR", "FATAL" };
static constexpr size_t MAX_MSG_SIZE = 4096;
static constexpr size_t ROTATE_SIZE  = 10 * 1024 * 1024; // 10 MB

struct logger::Logger::Impl {
    std::string filepath_;
    Level min_level_;
    std::mutex mu_;
    FILE* file_ = nullptr;
    size_t file_size_ = 0;

    Impl(const std::string& fp, Level min_level)
        : filepath_(fp), min_level_(min_level) {
        file_ = fopen(fp.c_str(), "a");
    }

    ~Impl() {
        if (file_) fclose(file_);
    }

    std::string format_time() {
        char buf[32];
        time_t t = time(nullptr);
        strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", localtime(&t));
        return std::string(buf);
    }

    void rotate() {
        if (!file_) return;
        fclose(file_);
        file_ = nullptr;
        std::string backup = filepath_ + ".bak";
        std::remove(backup.c_str());
        std::rename(filepath_.c_str(), backup.c_str());
        file_ = fopen(filepath_.c_str(), "a");
        file_size_ = 0;
    }

    void write_log(Level level, const char* fmt, va_list args) {
        if (level < min_level_) return;

        char msg[MAX_MSG_SIZE];
        vsnprintf(msg, sizeof(msg), fmt, args);

        std::lock_guard<std::mutex> lock(mu_);
        std::ostringstream oss;
        oss << "[" << format_time() << "] "
            << "[" << LEVEL_STR[static_cast<int>(level)] << "] "
            << msg << "\n";
        std::string line = oss.str();

        // Console output
        std::cout << line;
        if (level >= Level::ERROR) std::cerr << line;

        // File output
        if (file_) {
            fputs(line.c_str(), file_);
            fflush(file_);
            file_size_ += line.size();
            if (file_size_ >= ROTATE_SIZE) {
                rotate();
            }
        }
    }
};

logger::Logger::Logger(const std::string& fp, Level min_level)
    : p_(new Impl(fp, min_level)) {}

logger::Logger::~Logger() = default;

void logger::Logger::set_level(Level level) {
    p_->min_level_ = level;
}

void logger::Logger::flush() {
    std::lock_guard<std::mutex> lock(p_->mu_);
    if (p_->file_) fflush(p_->file_);
}

void logger::Logger::debug(const char* fmt, ...) {
    va_list args; va_start(args, fmt);
    p_->write_log(Level::DEBUG, fmt, args);
    va_end(args);
}
void logger::Logger::info(const char* fmt, ...) {
    va_list args; va_start(args, fmt);
    p_->write_log(Level::INFO, fmt, args);
    va_end(args);
}
void logger::Logger::warn(const char* fmt, ...) {
    va_list args; va_start(args, fmt);
    p_->write_log(Level::WARN, fmt, args);
    va_end(args);
}
void logger::Logger::error(const char* fmt, ...) {
    va_list args; va_start(args, fmt);
    p_->write_log(Level::ERROR, fmt, args);
    va_end(args);
}
void logger::Logger::fatal(const char* fmt, ...) {
    va_list args; va_start(args, fmt);
    p_->write_log(Level::FATAL, fmt, args);
    va_end(args);
}
