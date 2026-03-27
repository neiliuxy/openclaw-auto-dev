# MinStack test
add_executable(min_stack_test ${CMAKE_CURRENT_LIST_DIR}/min_stack_test.cpp)
target_include_directories(min_stack_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
target_compile_definitions(min_stack_test PRIVATE MIN_STACK_TEST)
add_test(NAME min_stack_test COMMAND min_stack_test)

# Source files library
add_library(algorithms INTERFACE)

target_sources(algorithms
    INTERFACE
        ${CMAKE_CURRENT_LIST_DIR}/quick_sort.cpp
        ${CMAKE_CURRENT_LIST_DIR}/matrix.cpp
        ${CMAKE_CURRENT_LIST_DIR}/date_utils.cpp
        ${CMAKE_CURRENT_LIST_DIR}/string_utils.cpp
        ${CMAKE_CURRENT_LIST_DIR}/ini_parser.cpp
        ${CMAKE_CURRENT_LIST_DIR}/logger.cpp
        ${CMAKE_CURRENT_LIST_DIR}/file_finder.cpp
)

target_include_directories(algorithms INTERFACE ${CMAKE_CURRENT_LIST_DIR})
