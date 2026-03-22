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
