# SPEC.md — Issue #90: C++ 单例模式模板类

> **项目**: neiliuxy/openclaw-auto-dev
> **Issue**: #90 — feat: 实现 C++ 单例模式模板类
> **阶段**: Stage 0 (Architect)
> **日期**: 2026-04-12
> **状态**: 已分析，转交 Developer 实现

---

## 1. Issue 概述

- **标题**: feat: 实现 C++ 单例模式模板类
- **作者**: neiliuxy
- **类型**: 功能实现
- **优先级**: P2（标准功能）
- **描述**: 实现一个线程安全的 C++ 单例模式模板类，支持双检锁、模板参数，提供 GetInstance() 静态方法获取实例。

---

## 2. 需求分析

### 2.1 核心需求（Must Have）

| ID | 需求描述 | 验收标准 |
|----|---------|---------|
| REQ-01 | 使用双检锁（double-checked locking）实现线程安全 | 多线程并发调用 GetInstance()，所有线程获取到同一实例地址 |
| REQ-02 | 支持模板参数，可创建任意类型的单例 | 对不同模板类型 T1、T2，实例地址必须不同 |
| REQ-03 | 提供 GetInstance() 静态方法获取实例 | 调用返回非空指针，指向单例对象 |
| REQ-04 | 禁止拷贝构造和赋值运算符 | `Singleton<T>` 类型不可拷贝、不可赋值，编译期检测 |
| REQ-05 | 包含完整的单元测试用例 | 测试覆盖：单线程实例获取、实例唯一性、多线程并发、类型隔离、销毁重创建 |

### 2.2 需求细化

- **并发安全**: 使用 `std::atomic` + `std::mutex` 双检锁，参考 C++11 及以上标准
- **内存序**: 使用 `memory_order_acquire` / `memory_order_release` 确保可见性
- **销毁支持**: 提供 `DestroyInstance()` 方法供测试场景使用（不是单例模式的标配，但合理）
- **模板隔离**: 静态成员 `s_instance` / `s_mutex` 必须是 `static` 的，每个模板类型独立

---

## 3. 技术方案

### 3.1 文件结构

```
src/
  singleton.h       — 模板类声明 + 友元-inl 包含
  singleton.inl    — 模板类实现（内联实现避免分离编译问题）
  singleton_test.cpp — Google Test / 手写测试 main 函数
```

### 3.2 核心实现

#### singleton.h

```cpp
template <typename T>
class Singleton {
public:
    static T* GetInstance();          // 双检锁获取实例
    static void DestroyInstance();    // 销毁实例（供测试用）
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
```

#### singleton.inl（双检锁实现）

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
```

### 3.3 双检锁原理

```
第一次检查（无锁）: 检查实例是否已创建，避免每次调用都要加锁
加锁（互斥）      : 保证创建实例时的原子性
第二次检查（有锁）: 防止多线程同时通过第一次检查后重复创建
memory_order      : 确保指令重排不会导致实例被其他线程看到未构造完成的状态
```

---

## 4. 测试用例设计

| TC | 测试名称 | 验证内容 |
|----|---------|---------|
| TC-01 | 单实例指针 | GetInstance() 返回非空指针 |
| TC-02 | 多次获取同一实例 | 两次调用返回相同地址 |
| TC-03 | 禁止拷贝构造 | 编译期 static_assert 验证（已 delete） |
| TC-04 | 禁止赋值运算符 | 编译期验证（已 delete） |
| TC-05 | 多线程并发获取 | 8 线程 × 1000 次迭代，所有线程得到同一地址 |
| TC-06 | 不同类型实例隔离 | Singleton\<A\> 和 Singleton\<B\> 地址不同 |
| TC-07 | 销毁后重创建 | DestroyInstance() 后 GetInstance() 返回新的有效实例 |

---

## 5. 文件结构与实现计划

### 5.1 已存在文件

| 文件 | 状态 | 说明 |
|------|------|------|
| `src/singleton.h` | ✅ 已有 | 模板类声明，符合 REQ-02/03/04 |
| `src/singleton.inl` | ✅ 已有 | 双检锁实现，符合 REQ-01 |
| `src/singleton_test.cpp` | ✅ 已有 | 测试文件，符合 REQ-05 |

> **结论**: 核心实现已完成。Developer 阶段需验证：
> 1. 代码已正确实现所有需求
> 2. 测试可正常编译运行
> 3. 多线程测试稳定性（TC-05）

### 5.2 Developer 任务清单

- [ ] 审查 `src/singleton.h` / `singleton.inl` 实现，确认双检锁逻辑正确
- [ ] 编译测试: `g++ -std=c++17 -pthread src/singleton_test.cpp -o singleton_test && ./singleton_test`
- [ ] 验证 TC-05 多线程稳定性（可多次运行或增加迭代次数）
- [ ] 确认无内存泄漏（可选：使用 valgrind）
- [ ] Push 到远程分支并创建 PR

---

## 6. 验收标准（Acceptance Criteria）

### 6.1 编译通过

```bash
g++ -std=c++17 -pthread src/singleton_test.cpp -o singleton_test
./singleton_test
```

输出应包含:
```
=== Singleton Pattern Unit Tests ===
[TC-01] PASS: GetInstance() returns non-null pointer
[TC-02] PASS: Multiple GetInstance() returns same address
[TC-05] PASS: 8 threads, 1000 iterations — all got same instance address
[TC-06] PASS: Different template types produce isolated instances
[TC-07] PASS: After DestroyInstance, GetInstance returns new functional instance

=== All tests passed! ===
```

### 6.2 验收清单

- [ ] `Singleton<T>::GetInstance()` 线程安全（双检锁）
- [ ] 任意模板类型 T 可创建单例
- [ ] `Singleton<T>` 不可拷贝、不可赋值（编译期验证）
- [ ] TC-01 ~ TC-07 全部通过
- [ ] PR 已创建，状态 stage=2

---

## 7. 风险与约束

- **C++ 标准**: 必须使用 C++11 及以上（需要 `std::atomic`、`std::mutex`）
- **编译器**: GCC 7+ / Clang 5+ / MSVC 2017+
- **平台**: Linux/macOS/Windows 均可，无平台依赖
- **内存泄漏**: `new T()` 创建的实例由用户通过 `DestroyInstance()` 管理，不使用智能指针是为了保持接口简洁

---

## 8. 流水线状态

| 字段 | 值 |
|------|-----|
| issue | 90 |
| stage | 0（当前: Architect） |
| 产出物 | `issues/90/SPEC.md` |
| 下一步 | Developer（Stage 1→2） |
