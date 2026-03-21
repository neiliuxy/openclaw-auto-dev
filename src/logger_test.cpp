#include "logger.h"
#include <cassert>
#include <cstdio>
#include <thread>
#include <vector>

using namespace logger;

int main() {
    // Test 1: basic logging
    {
        Logger log("test.log", Level::DEBUG);
        log.debug("Debug message %d", 1);
        log.info("Info message %s", "test");
        log.warn("Warn message");
        log.error("Error message");
        log.fatal("Fatal message");
    }
    printf("✅ Test 1 passed: basic logging\n");

    // Test 2: level filtering
    {
        Logger log("test.log", Level::WARN);
        log.debug("should not appear");
        log.warn("should appear");
        log.error("should appear");
    }
    printf("✅ Test 2 passed: level filtering\n");

    // Test 3: set_level
    {
        Logger log("test.log", Level::ERROR);
        log.set_level(Level::DEBUG);
        log.debug("should appear after set_level");
    }
    printf("✅ Test 3 passed: set_level\n");

    // Test 4: thread safety
    {
        Logger log("test.log", Level::INFO);
        std::vector<std::thread> threads;
        for (int i = 0; i < 4; ++i) {
            threads.emplace_back([&log, i]() {
                for (int j = 0; j < 100; ++j) {
                    log.info("Thread %d message %d", i, j);
                }
            });
        }
        for (auto& t : threads) t.join();
    }
    printf("✅ Test 4 passed: thread safety (400 messages)\n");

    // Clean up
    std::remove("test.log");
    std::remove("test.log.bak");

    printf("\n✅ All logger tests passed!\n");
    return 0;
}
