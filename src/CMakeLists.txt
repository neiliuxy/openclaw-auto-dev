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
        ${CMAKE_CURRENT_LIST_DIR}/pipeline_notifier.cpp
        ${CMAKE_CURRENT_LIST_DIR}/pipeline_state.cpp
)

target_include_directories(algorithms INTERFACE ${CMAKE_CURRENT_LIST_DIR})

# Issue #83: pipeline notification test executable
add_executable(pipeline_83_test ${CMAKE_CURRENT_LIST_DIR}/pipeline_83_test.cpp ${CMAKE_CURRENT_LIST_DIR}/pipeline_notifier.cpp)
target_include_directories(pipeline_83_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
add_test(NAME pipeline_83_test COMMAND pipeline_83_test)
set_tests_properties(pipeline_83_test PROPERTIES WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})

# Issue #95: spawn order test executable
add_executable(spawn_order_test ${CMAKE_CURRENT_LIST_DIR}/spawn_order_test.cpp ${CMAKE_CURRENT_LIST_DIR}/spawn_order.cpp)
target_include_directories(spawn_order_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
add_test(NAME spawn_order_test COMMAND spawn_order_test)

# Issue #97: pipeline state validation test executable
add_executable(pipeline_97_test ${CMAKE_CURRENT_LIST_DIR}/pipeline_97_test.cpp ${CMAKE_CURRENT_LIST_DIR}/pipeline_state.cpp)
target_include_directories(pipeline_97_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
target_compile_definitions(pipeline_97_test PRIVATE STATE_DIR="${CMAKE_SOURCE_DIR}/.pipeline-state")
add_test(NAME pipeline_97_test COMMAND pipeline_97_test)
set_tests_properties(pipeline_97_test PROPERTIES WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})

# Issue #99: pipeline cron auto-processing validation test executable
add_executable(pipeline_99_test ${CMAKE_CURRENT_LIST_DIR}/pipeline_99_test.cpp ${CMAKE_CURRENT_LIST_DIR}/pipeline_state.cpp)
target_include_directories(pipeline_99_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
add_test(NAME pipeline_99_test COMMAND pipeline_99_test)
set_tests_properties(pipeline_99_test PROPERTIES WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})

# Issue #102: pipeline scheme B final verification test executable
add_executable(pipeline_102_test ${CMAKE_CURRENT_LIST_DIR}/pipeline_102_test.cpp ${CMAKE_CURRENT_LIST_DIR}/pipeline_state.cpp)
target_include_directories(pipeline_102_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
add_test(NAME pipeline_102_test COMMAND pipeline_102_test)
set_tests_properties(pipeline_102_test PROPERTIES WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})

# Issue #104: pipeline full auto trigger verification test executable
add_executable(pipeline_104_test ${CMAKE_CURRENT_LIST_DIR}/pipeline_104_test.cpp ${CMAKE_CURRENT_LIST_DIR}/pipeline_state.cpp)
target_include_directories(pipeline_104_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
add_test(NAME pipeline_104_test COMMAND pipeline_104_test)
set_tests_properties(pipeline_104_test PROPERTIES WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})

# Issue #112: algorithm library unit tests
add_executable(algorithm_test ${CMAKE_CURRENT_LIST_DIR}/algorithm_test.cpp
    ${CMAKE_CURRENT_LIST_DIR}/quick_sort.cpp
    ${CMAKE_CURRENT_LIST_DIR}/matrix.cpp
    ${CMAKE_CURRENT_LIST_DIR}/string_utils.cpp)
target_include_directories(algorithm_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
add_test(NAME algorithm_test COMMAND algorithm_test)

# Issue #113: pipeline_state coverage test executable
add_executable(pipeline_state_test ${CMAKE_CURRENT_LIST_DIR}/pipeline_state_test.cpp
    ${CMAKE_CURRENT_LIST_DIR}/pipeline_state.cpp)
target_include_directories(pipeline_state_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
add_test(NAME pipeline_state_test COMMAND pipeline_state_test)
set_tests_properties(pipeline_state_test PROPERTIES WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})

# Issue #152: string_utils unit tests
add_executable(string_utils_test ${CMAKE_CURRENT_LIST_DIR}/string_utils_test.cpp)
target_link_libraries(string_utils_test PRIVATE algorithms)
target_include_directories(string_utils_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
add_test(NAME string_utils_test COMMAND string_utils_test)

# Issue #152: ini_parser unit tests
add_executable(ini_parser_test ${CMAKE_CURRENT_LIST_DIR}/ini_parser_test.cpp)
target_link_libraries(ini_parser_test PRIVATE algorithms)
target_include_directories(ini_parser_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
add_test(NAME ini_parser_test COMMAND ini_parser_test)

# file_finder CLI executable
add_executable(file_finder ${CMAKE_CURRENT_LIST_DIR}/file_finder.cpp
    ${CMAKE_CURRENT_LIST_DIR}/file_finder_lib.cpp)
target_include_directories(file_finder PRIVATE ${CMAKE_CURRENT_LIST_DIR})

# Issue #152: file_finder_lib unit tests
add_executable(file_finder_test ${CMAKE_CURRENT_LIST_DIR}/file_finder_test.cpp
    ${CMAKE_CURRENT_LIST_DIR}/file_finder_lib.cpp)
target_include_directories(file_finder_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
add_test(NAME file_finder_test COMMAND file_finder_test)
