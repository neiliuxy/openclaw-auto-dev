#include "ini_parser.h"
#include <iostream>
#include <fstream>
#include <cassert>
#include <cstdio>

using namespace ini;

void test_save_load_roundtrip() {
    const char* tmpfile = "test_roundtrip.ini";

    {
        Parser ini;
        // Section with values containing spaces, quotes, and Chinese chars
        ini["settings"].values["greeting"] = "Hello World";
        ini["settings"].values["path"] = "/usr/local/bin";
        ini["settings"].values["quote"] = "He said \"hello\"";
        ini["settings"].values["chinese"] = "你好世界";
        ini["settings"].values["mixed"] = "Hello 你好 123";

        ini["database"].values["host"] = "localhost";
        ini["database"].values["connection"] = "server=db.example.com;port=3306";

        ini.save(tmpfile);
    }

    {
        Parser ini2;
        bool ok = ini2.load(tmpfile);
        assert(ok);

        // Verify all values round-trip correctly
        assert(ini2["settings"].get("greeting") == "Hello World");
        assert(ini2["settings"].get("path") == "/usr/local/bin");
        assert(ini2["settings"].get("quote") == "He said \"hello\"");
        assert(ini2["settings"].get("chinese") == "你好世界");
        assert(ini2["settings"].get("mixed") == "Hello 你好 123");
        assert(ini2["database"].get("host") == "localhost");
        assert(ini2["database"].get("connection") == "server=db.example.com;port=3306");
    }

    std::remove(tmpfile);
    std::cout << "✅ test_save_load_roundtrip() passed\n";
}

int main() {
    // 创建测试文件
    std::ofstream test("test.ini");
    test << "[database]\n";
    test << "host=localhost\n";
    test << "port=3306\n";
    test << "timeout=30\n";
    test << "[app]\n";
    test << "debug=true\n";
    test << "name=MyApp\n";
    test << "version=1.2.3\n";
    test.close();

    Parser ini;
    bool ok = ini.load("test.ini");
    assert(ok);
    std::cout << "✅ load() passed\n";

    assert(ini["database"].get("host") == "localhost");
    std::cout << "✅ get(string) passed\n";

    assert(ini["database"].get_int("port") == 3306);
    std::cout << "✅ get_int() passed\n";

    assert(ini["database"].get_double("port") == 3306.0);
    std::cout << "✅ get_double() passed\n";

    assert(ini["app"].get_bool("debug") == true);
    std::cout << "✅ get_bool() passed\n";

    assert(ini["app"].get("name") == "MyApp");
    std::cout << "✅ string value passed\n";

    // 测试默认值
    assert(ini["database"].get("nonexistent", "default") == "default");
    assert(ini["database"].get_int("nonexistent", 999) == 999);
    assert(ini["database"].get_bool("nonexistent", true) == true);
    std::cout << "✅ default values passed\n";

    // 测试 sections()
    auto secs = ini.sections();
    assert(secs.size() == 2);
    std::cout << "✅ sections() passed\n";

    // 测试保存
    ini.save("test_out.ini");
    Parser ini2;
    ini2.load("test_out.ini");
    assert(ini2["database"].get("host") == "localhost");
    std::cout << "✅ save() and reload passed\n";

    // 清理
    std::remove("test.ini");
    std::remove("test_out.ini");

    // Run comprehensive round-trip test
    test_save_load_roundtrip();

    std::cout << "\n✅ All INI parser tests passed!\n";
    return 0;
}
