CXX = g++
CXXFLAGS = -std=c++11 -Wall -Wextra

hello: src/hello.cpp
	$(CXX) $(CXXFLAGS) -o hello src/hello.cpp

clean:
	rm -f hello hello_test

test: hello_test
	./hello_test

hello_test: tests/hello_test.cpp src/hello.cpp
	$(CXX) $(CXXFLAGS) -I/usr/include -lgtest -lgtest_main -pthread -o hello_test tests/hello_test.cpp src/hello.cpp

clean_test:
	rm -f hello_test

.PHONY: clean test clean_test

test: hello_test
	./hello_test

hello_test: tests/hello_test.cpp
	g++ -std=c++11 -I/usr/include -lgtest -lgtest_main -pthread -o hello_test tests/hello_test.cpp

clean_test:
	rm -f hello_test

.PHONY: test clean_test

code_stats: src/code_stats.cpp
	g++ -std=c++17 -fsyntax-only src/code_stats.cpp

code_stats_run: src/code_stats.cpp
	g++ -std=c++17 -o code_stats src/code_stats.cpp

clean_stats:
	rm -f code_stats
