CXX = g++
CXXFLAGS = -std=c++11 -Wall -Wextra

hello: hello.cpp
	$(CXX) $(CXXFLAGS) -o hello hello.cpp

clean:
	rm -f hello

.PHONY: clean
