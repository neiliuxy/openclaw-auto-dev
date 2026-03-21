# Tests
find_package(GTest QUIET)
if(GTest_FOUND)
    add_executable(test_quick_sort test_quick_sort.cpp)
    target_link_libraries(test_quick_sort algorithms GTest::GTest GTest::Main pthread)
    add_test(NAME algorithms.test_quick_sort COMMAND test_quick_sort)
endif()

# Simple compile test for matrix
add_executable(test_matrix ../src/matrix.cpp ../src/matrix.h)
target_link_libraries(test_matrix algorithms)
