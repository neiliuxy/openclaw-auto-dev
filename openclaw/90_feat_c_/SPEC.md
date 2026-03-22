# Issue #90 需求规格说明书 — C++ 单例模式模板类

## 1. 概述

- **Issue**: #90
- **标题**: feat: 实现 C++ 单例模式模板类
- **处理时间**: 2026-03-22
- **类型**: C++ 模板类 / 设计模式实现
- **优先级**: P1

## 2. 需求分析

### 2.1 背景

单例模式（Singleton Pattern）是最常用的设计模式之一，确保一个类只有一个实例，并提供一个全局访问点。在多线程环境下实现单例需要特别考虑线程安全性，双检锁（Double-Checked Locking）是业界推荐的高效方案。

### 2.2 功能需求

| 需求ID | 需求描述 | 验收标准 |
|--------|----------|----------|
| REQ-01 | 使用双检锁（double-checked locking）实现线程安全 | 多线程并发调用 GetInstance() 不产生多个实例 |
| REQ-02 | 支持模板参数，可创建任意类型的单例 | 通过 `Singleton<MyClass>::GetInstance()` 使用 |
| REQ-03 | 提供 GetInstance() 静态方法获取实例 | 首次调用时创建实例，后续返回同一实例 |
| REQ-04 | 禁止拷贝构造和赋值运算符 | 编译期报错，防止复制单例对象 |
| REQ-05 | 包含完整的单元测试用例 | 测试覆盖上述所有验收标准 |

### 2.3 非功能需求

- **性能**: GetInstance() 在锁定前完成实例存在性检查，避免不必要的锁竞争
- **可移植性**: 使用标准 C++11 及以上（依赖 `std::mutex`、`std::atomic` 等）
- **可维护性**: 代码结构清晰，注释完整

## 3. 技术方案

### 3.1 双检锁原理

双检锁（Double-Checked Locking）解决了以下问题：
- 第一次检查避免实例已创建时的锁定开销
- 第二次检查（加锁后）确保只有一个线程创建实例
- 使用 `std::atomic` 或 `volatile` 防止指令重排

**示意流程：**
```
if (instance == nullptr) {        // 第一次检查（不加锁，性能优化）
    lock_guard<mutex> lock(mtx);  // 加锁
    if (instance == nullptr) {    // 第二次检查（加锁后，确认未创建）
        instance = new Singleton(); // 创建实例
    }
}
return instance;
```

### 3.2 模板实现方案

使用模板参数 T 接收任意类型，CRTP 模式结合友元声明实现禁止拷贝：

```cpp
template <typename T>
class Singleton {
private:
    static std::atomic<T*> instance;
    static std::mutex mtx;

protected:
    Singleton() = default;
    virtual ~Singleton() = default;

public:
    // 禁止拷贝构造和赋值运算符
    Singleton(const Singleton&) = delete;
    Singleton& operator=(const Singleton&) = delete;

    static T* GetInstance();
};
```

### 3.3 线程安全实现要点

- `std::atomic<T*>` 保证指针操作的原子性
- `std::mutex` 保证创建实例的互斥
- 内存序（memory order）使用默认 `memory_order_seq_cst`

## 4. 代码结构设计

```
src/
├── singleton.h          # 单例模板类头文件
├── singleton.cpp        # 单例模板类实现（如需分离）
└── singleton_test.cpp   # 单元测试文件

openclaw/90_feat_c_/
├── SPEC.md              # 本规格说明书
└── TEST_REPORT.md       # 测试报告
```

### 4.1 `singleton.h` 接口设计

```cpp
#ifndef SINGLETON_H
#define SINGLETON_H

#include <memory>
#include <mutex>
#include <atomic>

template <typename T>
class Singleton {
public:
    // 获取单例实例（线程安全，双检锁）
    static T* GetInstance();

    // 销毁单例实例（供测试用）
    static void DestroyInstance();

    // 禁止拷贝
    Singleton(const Singleton&) = delete;
    Singleton& operator=(const Singleton&) = delete;

protected:
    Singleton() = default;
    virtual ~Singleton() = default;

private:
    static std::atomic<T*> s_instance;
    static std::mutex s_mutex;
};

#include "singleton.inl" // 模板实现
#endif // SINGLETON_H
```

### 4.2 `singleton.inl` 实现

```cpp
// 静态成员初始化
template <typename T>
std::atomic<T*> Singleton<T>::s_instance{nullptr};

template <typename T>
std::mutex Singleton<T>::s_mutex;

template <typename T>
T* Singleton<T>::GetInstance() {
    T* tmp = s_instance.load(std::memory_order_acquire);
    if (tmp == nullptr) {
        std::lock_guard<std::mutex> lock(s_mutex);
        tmp = s_instance.load(std::memory_order_relaxed);
        if (tmp == nullptr) {
            tmp = new T();
            s_instance.store(tmp, std::memory_order_release);
        }
    }
    return tmp;
}

template <typename T>
void Singleton<T>::DestroyInstance() {
    std::lock_guard<std::mutex> lock(s_mutex);
    T* tmp = s_instance.load(std::memory_order_relaxed);
    if (tmp != nullptr) {
        delete tmp;
        s_instance.store(nullptr, std::memory_order_release);
    }
}
```

### 4.3 `singleton_test.cpp` 测试用例

| 测试ID | 测试内容 | 验证点 |
|--------|----------|--------|
| TC-01 | 单线程获取实例 | GetInstance() 返回非空指针 |
| TC-02 | 多次获取为同一实例 | 两个指针相等（`ptr1 == ptr2`）|
| TC-03 | 禁止拷贝构造 | 编译期报错 |
| TC-04 | 禁止赋值运算符 | 编译期报错 |
| TC-05 | 多线程并发获取 | 多个线程获取的实例地址相同 |
| TC-06 | 不同模板类型实例隔离 | `Singleton<A>::GetInstance() != Singleton<B>::GetInstance()` |
| TC-07 | DestroyInstance 后可重新创建 | 销毁后再次 GetInstance 返回新实例 |

## 5. 验收标准

| 验收ID | 验收内容 | 对应需求 | 验证方法 |
|--------|----------|----------|----------|
| AC-01 | 双检锁线程安全实现 | REQ-01 | 多线程测试 TC-05 验证 |
| AC-02 | 模板参数支持任意类型 | REQ-02 | TC-06 验证类型隔离 |
| AC-03 | GetInstance() 静态方法正确返回实例 | REQ-03 | TC-01, TC-02 验证 |
| AC-04 | 拷贝构造和赋值运算符已删除 | REQ-04 | TC-03, TC-04 编译期验证 |
| AC-05 | 单元测试覆盖所有验收标准 | REQ-05 | 测试报告确认 7 个用例全部通过 |

## 6. 依赖与构建

- **C++ 标准**: C++11 或更高
- **编译命令**: `g++ -std=c++11 -pthread -o singleton_test singleton_test.cpp`
- **测试框架**: GoogleTest（可选）或手写 assert
- **构建系统**: CMake（复用项目已有 CMakeLists.txt）

## 7. 风险与注意事项

1. **Meyers' Singleton**: 可考虑使用局部静态变量实现（C++11 保证线程安全），但题目要求双检锁，需按要求实现
2. **内存泄漏**: DestroyInstance 需配合 new/delete 使用，测试后清理
3. **模板分离编译**: 模板实现放在 .inl 文件，include 到 .h 中，避免链接错误
