# 测试文件示例

import unittest
from src.main import hello, add


class TestMain(unittest.TestCase):
    """主模块测试"""

    def test_hello(self):
        """测试 hello 函数"""
        result = hello()
        self.assertIsInstance(result, str)
        self.assertIn("OpenClaw", result)

    def test_add(self):
        """测试 add 函数"""
        self.assertEqual(add(1, 2), 3)
        self.assertEqual(add(-1, 1), 0)
        self.assertEqual(add(0, 0), 0)


if __name__ == "__main__":
    unittest.main()
