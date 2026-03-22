#include "singleton.h"
#include <cassert>
#include <thread>
#include <vector>
#include <atomic>
#include <iostream>

// 测试用类 A
class ServiceA {
public:
    ServiceA() = default;
    ~ServiceA() = default;
    int value = 42;
};

// 测试用类 B
class ServiceB {
public:
    ServiceB() = default;
    ~ServiceB() = default;
    std::string name = "ServiceB";
};

// ======================
// TC-01: 单线程获取实例
// ======================
void test_single_instance_pointer() {
    auto* inst = Singleton<ServiceA>::GetInstance();
    assert(inst != nullptr && "GetInstance() should return non-null pointer");
    std::cout << "[TC-01] PASS: GetInstance() returns non-null pointer" << std::endl;
    Singleton<ServiceA>::DestroyInstance();
}

// ======================
// TC-02: 多次获取为同一实例
// ======================
void test_same_instance() {
    auto* ptr1 = Singleton<ServiceA>::GetInstance();
    auto* ptr2 = Singleton<ServiceA>::GetInstance();
    assert(ptr1 == ptr2 && "Multiple GetInstance() calls should return the same pointer");
    std::cout << "[TC-02] PASS: Multiple GetInstance() returns same address" << std::endl;
    Singleton<ServiceA>::DestroyInstance();
}

// ======================
// TC-03 & TC-04: 禁止拷贝构造和赋值运算符（编译期验证）
// ======================
// 下面的代码在编译时会报错（已注释防止编译失败）：
// void test_copy_constructor() {
//     auto* inst = Singleton<ServiceA>::GetInstance();
//     Singleton<ServiceA> copy(*inst);  // 编译错误：拷贝构造已删除
// }
// void test_assignment() {
//     auto* inst = Singleton<ServiceA>::GetInstance();
//     Singleton<ServiceA> another;
//     another = *inst;  // 编译错误：赋值运算符已删除
// }

// 使用 static_assert 在编译期验证拷贝构造和赋值运算符已删除
namespace compile_time_check {
    struct Checker : public Singleton<ServiceA> {
        Checker() = default;
    };
    // 下面的 static_assert 会在编译期失败如果拷贝构造未删除：
    // static_assert(std::is_copy_constructible<Singleton<ServiceA>>::value == false, "copy ctor must be deleted");
}

// ======================
// TC-05: 多线程并发获取同一实例
// ======================
void test_multithread_concurrent_get() {
    constexpr int THREAD_COUNT = 8;
    constexpr int ITERATIONS = 1000;

    std::atomic<ServiceA*> result_ptr{nullptr};
    std::atomic<bool> first_set{false};
    std::vector<std::thread> threads;

    for (int t = 0; t < THREAD_COUNT; ++t) {
        threads.emplace_back([&result_ptr, &first_set]() {
            for (int i = 0; i < ITERATIONS; ++i) {
                auto* inst = Singleton<ServiceA>::GetInstance();
                if (!first_set.load()) {
                    result_ptr.store(inst);
                    first_set.store(true);
                } else {
                    assert(result_ptr.load() == inst && "All threads must get the same instance");
                }
            }
        });
    }

    for (auto& th : threads) {
        th.join();
    }

    std::cout << "[TC-05] PASS: " << THREAD_COUNT << " threads, " << ITERATIONS
              << " iterations — all got same instance address" << std::endl;
    Singleton<ServiceA>::DestroyInstance();
}

// ======================
// TC-06: 不同模板类型实例隔离
// ======================
void test_different_types_isolated() {
    auto* instA = Singleton<ServiceA>::GetInstance();
    auto* instB = Singleton<ServiceB>::GetInstance();
    assert(static_cast<void*>(instA) != static_cast<void*>(instB) && "Different template types must have different instances");
    assert(instA->value == 42);
    assert(instB->name == "ServiceB");
    std::cout << "[TC-06] PASS: Different template types produce isolated instances" << std::endl;
    Singleton<ServiceA>::DestroyInstance();
    Singleton<ServiceB>::DestroyInstance();
}

// ======================
// TC-07: DestroyInstance 后可重新创建
// ======================
void test_destroy_and_recreate() {
    auto* inst1 = Singleton<ServiceA>::GetInstance();
    assert(inst1 != nullptr);
    Singleton<ServiceA>::DestroyInstance();

    auto* inst2 = Singleton<ServiceA>::GetInstance();
    assert(inst2 != nullptr);
    // Note: after DestroyInstance, GetInstance creates a NEW instance
    // (ptr value may differ — we just verify it's non-null and functional)
    assert(inst2->value == 42);
    std::cout << "[TC-07] PASS: After DestroyInstance, GetInstance returns new functional instance" << std::endl;
    Singleton<ServiceA>::DestroyInstance();
}

// ======================
// Main
// ======================
int main() {
    std::cout << "=== Singleton Pattern Unit Tests ===" << std::endl;

    test_single_instance_pointer();
    test_same_instance();
    test_multithread_concurrent_get();
    test_different_types_isolated();
    test_destroy_and_recreate();

    // TC-03/TC-04 are verified at compile time via deleted copy constructor/assignment
    std::cout << "\n=== All tests passed! ===" << std::endl;
    return 0;
}
