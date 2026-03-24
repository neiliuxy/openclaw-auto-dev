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
        ${CMAKE_CURRENT_LIST_DIR}/pipeline_notifier.cpp
        ${CMAKE_CURRENT_LIST_DIR}/pipeline_state.cpp
)

target_include_directories(algorithms INTERFACE ${CMAKE_CURRENT_LIST_DIR})

# Issue #83: pipeline notification test executable
add_executable(pipeline_83_test ${CMAKE_CURRENT_LIST_DIR}/pipeline_83_test.cpp ${CMAKE_CURRENT_LIST_DIR}/pipeline_notifier.cpp)
target_include_directories(pipeline_83_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})

# Issue #99: pipeline cron validation test executable
add_executable(pipeline_99_test ${CMAKE_CURRENT_LIST_DIR}/pipeline_99_test.cpp ${CMAKE_CURRENT_LIST_DIR}/pipeline_state.cpp)
target_include_directories(pipeline_99_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
add_test(NAME pipeline_99_test COMMAND pipeline_99_test)
set_tests_properties(pipeline_99_test PROPERTIES WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
