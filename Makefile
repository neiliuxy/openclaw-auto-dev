CXX = g++
CXXFLAGS = -std=c++11 -Wall -Wextra

hello: hello.cpp
	$(CXX) $(CXXFLAGS) -o hello hello.cpp

clean:
	rm -f hello

.PHONY: clean

code_stats: src/code_stats.cpp
	g++ -std=c++17 -fsyntax-only src/code_stats.cpp

code_stats_run: src/code_stats.cpp
	g++ -std=c++17 -o code_stats src/code_stats.cpp

clean_stats:
	rm -f code_stats
