cmake_minimum_required(VERSION 3.16)
project(engine_api_reentry_tests LANGUAGES CXX)

enable_testing()
set(ENGINE_API_LIBRARY "" CACHE FILEPATH "Path to a built engine_api runtime library")
if(NOT EXISTS "${ENGINE_API_LIBRARY}")
    message(FATAL_ERROR "Set ENGINE_API_LIBRARY to the engine_api runtime library (with KiriKiri enabled)")
endif()
add_executable(engine_api_reentry_test reentry_test.cpp)
target_compile_features(engine_api_reentry_test PRIVATE cxx_std_17)
target_include_directories(engine_api_reentry_test PRIVATE ../include)
target_link_libraries(engine_api_reentry_test PRIVATE "${ENGINE_API_LIBRARY}")
add_test(NAME engine_api_reentry
    COMMAND engine_api_reentry_test "${CMAKE_CURRENT_BINARY_DIR}/fixtures")
set_tests_properties(engine_api_reentry PROPERTIES TIMEOUT 150)

add_executable(artemis_input_mapping_test input_mapping_test.cpp)
target_compile_features(artemis_input_mapping_test PRIVATE cxx_std_17)
target_include_directories(artemis_input_mapping_test PRIVATE ../src)
add_test(NAME artemis_input_mapping COMMAND artemis_input_mapping_test)

add_executable(artemis_save_dir_test
    artemis_save_dir_test.cpp
    ../src/artemis_save_dir.cpp)
target_compile_features(artemis_save_dir_test PRIVATE cxx_std_17)
target_include_directories(artemis_save_dir_test PRIVATE ../src)
add_test(NAME artemis_save_dir COMMAND artemis_save_dir_test)
