CXX = g++
CXXFLAGS = -std=c++11 -Wall -Wextra

hello: src/hello.cpp
	$(CXX) $(CXXFLAGS) -o hello src/hello.cpp

clean:
	rm -f hello

.PHONY: clean
