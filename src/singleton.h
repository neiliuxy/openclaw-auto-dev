#ifndef SINGLETON_H
#define SINGLETON_H

#include <memory>
#include <mutex>
#include <atomic>

/**
 * @brief Thread-safe singleton template class using double-checked locking.
 * @tparam T The type for which to create a singleton.
 *
 * Usage:
 *   auto* instance = Singleton<MyClass>::GetInstance();
 */
template <typename T>
class Singleton {
public:
    // 获取单例实例（线程安全，双检锁）
    static T* GetInstance();

    // 销毁单例实例（供测试用）
    static void DestroyInstance();

    // 禁止拷贝构造和赋值运算符
    Singleton(const Singleton&) = delete;
    Singleton& operator=(const Singleton&) = delete;

protected:
    Singleton() = default;
    virtual ~Singleton() = default;

private:
    static std::atomic<T*> s_instance;
    static std::mutex s_mutex;
};

#include "singleton.inl"

#endif // SINGLETON_H
