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

# Issue #95: spawn order test executable
add_executable(spawn_order_test ${CMAKE_CURRENT_LIST_DIR}/spawn_order_test.cpp ${CMAKE_CURRENT_LIST_DIR}/spawn_order.cpp)
target_include_directories(spawn_order_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
add_test(NAME spawn_order_test COMMAND spawn_order_test)

# Issue #97: pipeline state validation test executable
add_executable(pipeline_97_test ${CMAKE_CURRENT_LIST_DIR}/pipeline_97_test.cpp ${CMAKE_CURRENT_LIST_DIR}/pipeline_state.cpp)
target_include_directories(pipeline_97_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
add_test(NAME pipeline_97_test COMMAND pipeline_97_test)
set_tests_properties(pipeline_97_test PROPERTIES WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})

# Issue #102: pipeline final verification test executable
add_executable(pipeline_102_test ${CMAKE_CURRENT_LIST_DIR}/pipeline_102_test.cpp ${CMAKE_CURRENT_LIST_DIR}/pipeline_state.cpp)
target_include_directories(pipeline_102_test PRIVATE ${CMAKE_CURRENT_LIST_DIR})
add_test(NAME pipeline_102_test COMMAND pipeline_102_test)
set_tests_properties(pipeline_102_test PROPERTIES WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
